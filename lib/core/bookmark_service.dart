import '../data/metadata/library_schema.dart';
import '../data/metadata/metadata_store.dart';

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

/// Stores reading bookmarks as [ReadingMark]s in `metadata/library.json`.
///
/// 2.x kept them in a standalone `bookmarks.json` keyed by document id, which
/// meant a document delete, an undo and a migration all had to touch a second
/// file in lockstep. Marks now live on the same record set as tags, so one
/// transaction covers both.
class BookmarkService {
  BookmarkService._();

  static Future<List<ReadingBookmark>> loadAll() async {
    final snapshot = await MetadataStore.load();
    return _bookmarksOf(snapshot);
  }

  static Future<List<ReadingBookmark>> forDocument(String documentId) async {
    final snapshot = await MetadataStore.load();
    return _bookmarksOf(
      snapshot,
    ).where((bookmark) => bookmark.documentId == documentId).toList();
  }

  static Future<ReadingBookmark> add({
    required String documentId,
    required double progressRatio,
    required String title,
    String? note,
  }) {
    final bookmark = ReadingBookmark(
      id: 'bm_${DateTime.now().microsecondsSinceEpoch}',
      documentId: documentId,
      progressRatio: progressRatio.clamp(0.0, 1.0),
      title: title,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      note: note,
    );
    return MetadataStore.transaction((snapshot) async {
      snapshot.marks.add(_toMark(bookmark));
      return bookmark;
    });
  }

  static Future<void> remove(String bookmarkId) {
    return MetadataStore.transaction((snapshot) async {
      snapshot.marks.removeWhere(
        (mark) =>
            mark.kind == ReadingMarkKind.bookmark && mark.id == bookmarkId,
      );
    });
  }

  static Future<void> update({
    required String bookmarkId,
    String? title,
    String? note,
  }) {
    return MetadataStore.transaction((snapshot) async {
      final index = snapshot.marks.indexWhere(
        (mark) =>
            mark.kind == ReadingMarkKind.bookmark && mark.id == bookmarkId,
      );
      if (index == -1) return;
      final old = snapshot.marks[index];
      snapshot.marks[index] = ReadingMark(
        id: old.id,
        documentId: old.documentId,
        kind: ReadingMarkKind.bookmark,
        ratio: old.ratio,
        title: title ?? old.title,
        note: note ?? old.note,
        createdAtMillis: old.createdAtMillis,
      );
    });
  }

  static Future<void> removeForDocument(String documentId) {
    return MetadataStore.transaction((snapshot) async {
      snapshot.marks.removeWhere(
        (mark) =>
            mark.documentId == documentId &&
            mark.kind == ReadingMarkKind.bookmark,
      );
    });
  }

  /// Puts removed bookmarks back after an undo.
  static Future<void> restoreAll(List<ReadingBookmark> restored) {
    if (restored.isEmpty) return Future<void>.value();
    return MetadataStore.transaction((snapshot) async {
      final known = {
        for (final mark in snapshot.marks)
          if (mark.kind == ReadingMarkKind.bookmark) mark.id,
      };
      for (final bookmark in restored) {
        if (known.contains(bookmark.id)) continue;
        snapshot.marks.add(_toMark(bookmark));
      }
    });
  }

  static void clearCache() {
    MetadataStore.clearCache();
  }

  static List<ReadingBookmark> _bookmarksOf(LibrarySnapshot snapshot) {
    final bookmarks = <ReadingBookmark>[];
    for (final mark in snapshot.marks) {
      if (mark.kind != ReadingMarkKind.bookmark) continue;
      bookmarks.add(
        ReadingBookmark(
          id: mark.id,
          documentId: mark.documentId,
          progressRatio: mark.ratio,
          title: mark.title,
          createdAtMillis: mark.createdAtMillis,
          note: mark.note,
        ),
      );
    }
    return bookmarks;
  }

  static ReadingMark _toMark(ReadingBookmark bookmark) {
    return ReadingMark(
      id: bookmark.id,
      documentId: bookmark.documentId,
      kind: ReadingMarkKind.bookmark,
      ratio: bookmark.progressRatio,
      title: bookmark.title,
      note: bookmark.note,
      createdAtMillis: bookmark.createdAtMillis,
    );
  }
}
