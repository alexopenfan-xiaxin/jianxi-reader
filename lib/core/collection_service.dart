import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A user-created collection (book list) grouping multiple documents.
class DocumentCollection {
  const DocumentCollection({
    required this.id,
    required this.name,
    required this.documentIds,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.description,
  });

  final String id;
  final String name;
  final List<String> documentIds;
  final int createdAtMillis;
  final int updatedAtMillis;
  final String? description;

  DocumentCollection copyWith({
    String? name,
    List<String>? documentIds,
    int? updatedAtMillis,
    String? description,
  }) {
    return DocumentCollection(
      id: id,
      name: name ?? this.name,
      documentIds: documentIds ?? this.documentIds,
      createdAtMillis: createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'documentIds': documentIds,
        'createdAtMillis': createdAtMillis,
        'updatedAtMillis': updatedAtMillis,
        if (description != null) 'description': description,
      };

  factory DocumentCollection.fromJson(Map<String, dynamic> json) {
    return DocumentCollection(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      documentIds: List<String>.from(json['documentIds'] as List? ?? []),
      createdAtMillis: json['createdAtMillis'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAtMillis: json['updatedAtMillis'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      description: json['description'] as String?,
    );
  }
}

/// Stores document collections in JSON.
/// File: `metadata/collections.json`
class CollectionService {
  CollectionService._();

  static const _fileName = 'collections.json';
  static List<DocumentCollection>? _cache;
  static Future<List<DocumentCollection>>? _loadFuture;

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    if (!metadataDir.existsSync()) {
      await metadataDir.create(recursive: true);
    }
    return File('${metadataDir.path}/$_fileName');
  }

  static Future<List<DocumentCollection>> loadAll() async {
    return _loadFuture ??= () async {
      final file = await _file;
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final list = jsonDecode(raw) as List;
          _cache = list
              .map((e) => DocumentCollection.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('[CollectionService] load failed: $e');
          _cache = [];
        }
      } else {
        _cache = [];
      }
      return _cache!;
    }();
  }

  static Future<DocumentCollection> create({
    required String name,
    String? description,
  }) async {
    final all = await loadAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    final collection = DocumentCollection(
      id: 'col_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      documentIds: [],
      createdAtMillis: now,
      updatedAtMillis: now,
      description: description,
    );
    all.add(collection);
    await _save(all);
    return collection;
  }

  static Future<void> delete(String collectionId) async {
    final all = await loadAll();
    all.removeWhere((c) => c.id == collectionId);
    await _save(all);
  }

  static Future<void> rename(String collectionId, String newName) async {
    final all = await loadAll();
    final index = all.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      all[index] = all[index].copyWith(
        name: newName,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _save(all);
    }
  }

  static Future<void> addDocument(String collectionId, String documentId) async {
    final all = await loadAll();
    final index = all.indexWhere((c) => c.id == collectionId);
    if (index != -1 && !all[index].documentIds.contains(documentId)) {
      all[index] = all[index].copyWith(
        documentIds: [...all[index].documentIds, documentId],
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _save(all);
    }
  }

  static Future<void> removeDocument(
      String collectionId, String documentId) async {
    final all = await loadAll();
    final index = all.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      all[index] = all[index].copyWith(
        documentIds:
            all[index].documentIds.where((id) => id != documentId).toList(),
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _save(all);
    }
  }

  static Future<void> removeDocumentFromAll(String documentId) async {
    final all = await loadAll();
    var changed = false;
    for (var i = 0; i < all.length; i++) {
      if (all[i].documentIds.contains(documentId)) {
        all[i] = all[i].copyWith(
          documentIds:
              all[i].documentIds.where((id) => id != documentId).toList(),
          updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
        );
        changed = true;
      }
    }
    if (changed) await _save(all);
  }

  static Future<void> _save(List<DocumentCollection> collections) async {
    try {
      final file = await _file;
      final json = collections.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('[CollectionService] save failed: $e');
    }
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
