import 'dart:convert';

import 'metadata_file_store.dart';

/// A reading bookmark anchored to a document and progress ratio.
class ReadingBookmark {
  const ReadingBookmark({
    required this.id,
    required this.documentId,
    required this.progressRatio,
    required this.title,
    required this.createdAtMillis,
    this.note,
  });

  final String id;
  final String documentId;
  final double progressRatio;
  final String title;
  final int createdAtMillis;
  final String? note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'progressRatio': progressRatio,
    'title': title,
    'createdAtMillis': createdAtMillis,
    if (note != null) 'note': note,
  };

  factory ReadingBookmark.fromJson(Map<String, dynamic> json) {
    return ReadingBookmark(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      progressRatio: (json['progressRatio'] as num).toDouble(),
      title: json['title'] as String? ?? '',
      createdAtMillis:
          json['createdAtMillis'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      note: json['note'] as String?,
    );
  }
}

/// Stores reading bookmarks in JSON.
/// File: `metadata/bookmarks.json`
class BookmarkService {
  BookmarkService._();

  static const _fileName = 'bookmarks.json';
  static List<ReadingBookmark>? _cache;
  static Future<List<ReadingBookmark>>? _loadFuture;

  static Future<List<ReadingBookmark>> loadAll() async {
    return _loadFuture ??= () async {
      final file = await MetadataFileStore.file(_fileName);
      if (await file.exists()) {
        final raw = await file.readAsString();
        final list = jsonDecode(raw) as List;
        _cache = list
            .map((e) => ReadingBookmark.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _cache = [];
      }
      return _cache!;
    }();
  }

  static Future<List<ReadingBookmark>> forDocument(String documentId) async {
    final all = await loadAll();
    return all.where((b) => b.documentId == documentId).toList();
  }

  static Future<ReadingBookmark> add({
    required String documentId,
    required double progressRatio,
    required String title,
    String? note,
  }) {
    return MetadataFileStore.serialize(_fileName, () async {
      final all = await loadAll();
      final bookmark = ReadingBookmark(
        id: 'bm_${DateTime.now().microsecondsSinceEpoch}',
        documentId: documentId,
        progressRatio: progressRatio.clamp(0.0, 1.0),
        title: title,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        note: note,
      );
      await _replaceAll(all, [...all, bookmark]);
      return bookmark;
    });
  }

  static Future<void> remove(String bookmarkId) {
    return MetadataFileStore.serialize(_fileName, () async {
      final all = await loadAll();
      await _replaceAll(
        all,
        all.where((bookmark) => bookmark.id != bookmarkId).toList(),
      );
    });
  }

  static Future<void> update({
    required String bookmarkId,
    String? title,
    String? note,
  }) {
    return MetadataFileStore.serialize(_fileName, () async {
      final all = await loadAll();
      final index = all.indexWhere((b) => b.id == bookmarkId);
      if (index == -1) return;
      final old = all[index];
      final updated = ReadingBookmark(
        id: old.id,
        documentId: old.documentId,
        progressRatio: old.progressRatio,
        title: title ?? old.title,
        createdAtMillis: old.createdAtMillis,
        note: note ?? old.note,
      );
      final next = List<ReadingBookmark>.from(all)..[index] = updated;
      await _replaceAll(all, next);
    });
  }

  static Future<void> removeForDocument(String documentId) {
    return MetadataFileStore.serialize(_fileName, () async {
      final all = await loadAll();
      await _replaceAll(
        all,
        all.where((bookmark) => bookmark.documentId != documentId).toList(),
      );
    });
  }

  static Future<void> _replaceAll(
    List<ReadingBookmark> current,
    List<ReadingBookmark> next,
  ) async {
    final json = next.map((bookmark) => bookmark.toJson()).toList();
    await MetadataFileStore.writeJson(_fileName, json);
    current
      ..clear()
      ..addAll(next);
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
