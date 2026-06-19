import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Per-document metadata stored in JSON.
class DocumentMetadata {
  const DocumentMetadata({
    required this.documentId,
    this.tags = const [],
    this.pinned = false,
    this.recentOpenedAtMillis,
    this.progressRatio,
  });

  final String documentId;
  final List<String> tags;
  final bool pinned;
  final int? recentOpenedAtMillis;
  final double? progressRatio;

  DocumentMetadata copyWith({
    List<String>? tags,
    bool? pinned,
    int? recentOpenedAtMillis,
    double? progressRatio,
  }) {
    return DocumentMetadata(
      documentId: documentId,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      recentOpenedAtMillis: recentOpenedAtMillis ?? this.recentOpenedAtMillis,
      progressRatio: progressRatio ?? this.progressRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'tags': tags,
        'pinned': pinned,
        if (recentOpenedAtMillis != null)
          'recentOpenedAtMillis': recentOpenedAtMillis,
        if (progressRatio != null) 'progressRatio': progressRatio,
      };

  factory DocumentMetadata.fromJson(String documentId, Map<String, dynamic> json) {
    return DocumentMetadata(
      documentId: documentId,
      tags: List<String>.from(json['tags'] as List? ?? []),
      pinned: json['pinned'] as bool? ?? false,
      recentOpenedAtMillis: json['recentOpenedAtMillis'] as int?,
      progressRatio: (json['progressRatio'] as num?)?.toDouble(),
    );
  }
}

/// Snapshot of the entire library metadata.
class LibraryMetadataSnapshot {
  const LibraryMetadataSnapshot({
    required this.documents,
    required this.allTags,
    required this.pinnedTags,
  });

  final Map<String, DocumentMetadata> documents;
  final List<String> allTags;
  final List<String> pinnedTags;
}

/// JSON-based metadata store replacing path-based SharedPreferences.
///
/// Storage layout:
/// ```
/// applicationDocuments/metadata/
///   library.json    — document metadata + global tags
/// ```
class LibraryMetadataStore {
  LibraryMetadataStore._();

  static const _fileName = 'library.json';
  static LibraryMetadataSnapshot? _cache;
  static Future<LibraryMetadataSnapshot>? _loadFuture;

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    if (!metadataDir.existsSync()) {
      await metadataDir.create(recursive: true);
    }
    return File('${metadataDir.path}/$_fileName');
  }

  static Future<LibraryMetadataSnapshot> load() async {
    return _loadFuture ??= () async {
      final file = await _file;
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final docsJson = json['documents'] as Map<String, dynamic>? ?? {};
          final documents = <String, DocumentMetadata>{};
          for (final entry in docsJson.entries) {
            documents[entry.key] = DocumentMetadata.fromJson(
              entry.key,
              entry.value as Map<String, dynamic>,
            );
          }
          _cache = LibraryMetadataSnapshot(
            documents: documents,
            allTags: List<String>.from(json['allTags'] as List? ?? []),
            pinnedTags: List<String>.from(json['pinnedTags'] as List? ?? []),
          );
        } catch (e) {
          debugPrint('[LibraryMetadataStore] load failed: $e');
          _cache = LibraryMetadataSnapshot(
            documents: {},
            allTags: [],
            pinnedTags: [],
          );
        }
      } else {
        _cache = LibraryMetadataSnapshot(
          documents: {},
          allTags: [],
          pinnedTags: [],
        );
      }
      return _cache!;
    }();
  }

  static Future<void> _save() async {
    if (_cache == null) return;
    try {
      final file = await _file;
      final json = {
        'documents': _cache!.documents.map((k, v) => MapEntry(k, v.toJson())),
        'allTags': _cache!.allTags,
        'pinnedTags': _cache!.pinnedTags,
      };
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('[LibraryMetadataStore] save failed: $e');
    }
  }

  static Future<DocumentMetadata> getMetadata(String documentId) async {
    final snapshot = await load();
    return snapshot.documents[documentId] ??
        DocumentMetadata(documentId: documentId);
  }

  static Future<void> saveDocumentMetadata(DocumentMetadata metadata) async {
    final snapshot = await load();
    snapshot.documents[metadata.documentId] = metadata;
    // Sync tags into allTags.
    for (final tag in metadata.tags) {
      if (!snapshot.allTags.contains(tag)) {
        snapshot.allTags.add(tag);
        snapshot.allTags.sort();
      }
    }
    await _save();
  }

  static Future<void> deleteDocument(String documentId) async {
    final snapshot = await load();
    snapshot.documents.remove(documentId);
    await _save();
  }

  static Future<void> createTag(String name) async {
    final snapshot = await load();
    if (!snapshot.allTags.contains(name)) {
      snapshot.allTags.add(name);
      snapshot.allTags.sort();
      await _save();
    }
  }

  static Future<void> deleteTag(String name) async {
    final snapshot = await load();
    snapshot.allTags.remove(name);
    snapshot.pinnedTags.remove(name);
    // Remove from all documents.
    for (final doc in snapshot.documents.values) {
      if (doc.tags.contains(name)) {
        snapshot.documents[doc.documentId] = doc.copyWith(
          tags: doc.tags.where((t) => t != name).toList(),
        );
      }
    }
    await _save();
  }

  static Future<void> setTagPinned(String name, bool pinned) async {
    final snapshot = await load();
    if (pinned && !snapshot.pinnedTags.contains(name)) {
      snapshot.pinnedTags.add(name);
      snapshot.pinnedTags.sort();
    } else if (!pinned) {
      snapshot.pinnedTags.remove(name);
    }
    await _save();
  }

  static Future<void> clearCache() async {
    _cache = null;
    _loadFuture = null;
  }
}
