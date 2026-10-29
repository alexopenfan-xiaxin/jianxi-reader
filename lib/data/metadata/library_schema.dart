// The on-disk shape of `metadata/library.json` (schema v1).
//
// Why a single file with a schema number: the 2.x layout scattered one key per
// attribute into `SharedPreferences` and kept ids/bookmarks in three separate
// JSON files, so nothing could be migrated, snapshotted or validated as a unit.
// Everything user-visible about a document now hangs off one record with a
// stable `id`; `path` is just an attribute that may change.

/// Schema version written by this build. Bump only with a matching migration.
const int librarySchemaVersion = 1;

/// Kinds of reading traces. `history` is reserved for the timeline that lands
/// in Phase 2; bookmarks and notes already live here.
enum ReadingMarkKind {
  bookmark('bookmark'),
  note('note'),
  history('history');

  const ReadingMarkKind(this.jsonValue);

  final String jsonValue;

  static ReadingMarkKind? fromJsonValue(Object? value) {
    for (final kind in ReadingMarkKind.values) {
      if (kind.jsonValue == value) return kind;
    }
    return null;
  }
}

/// A document's user-visible metadata, keyed by [id] rather than by path.
class DocumentRecord {
  DocumentRecord({
    required this.id,
    required this.path,
    this.sourceUri,
    this.pinned = false,
    List<String> tags = const [],
    this.recentOpenedAtMillis,
  }) : tags = List<String>.unmodifiable(_cleanTags(tags));

  final String id;
  final String path;
  final String? sourceUri;
  final bool pinned;
  final List<String> tags;
  final int? recentOpenedAtMillis;

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    if (sourceUri != null) 'sourceUri': sourceUri,
    'pinned': pinned,
    'tags': tags,
    'recentOpenedAt': recentOpenedAtMillis,
  };

  /// Throws [FormatException] when [id] or [path] is missing — the store drops
  /// that single record instead of failing the whole library.
  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final path = json['path'];
    if (id is! String || id.isEmpty || path is! String || path.isEmpty) {
      throw FormatException('document record needs id and path', json);
    }
    return DocumentRecord(
      id: id,
      path: path,
      sourceUri: json['sourceUri'] as String?,
      pinned: json['pinned'] == true,
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      recentOpenedAtMillis: (json['recentOpenedAt'] as num?)?.toInt(),
    );
  }

  DocumentRecord copyWith({
    String? path,
    String? sourceUri,
    bool? pinned,
    List<String>? tags,
    int? recentOpenedAtMillis,
    bool clearRecentOpenedAt = false,
  }) {
    return DocumentRecord(
      id: id,
      path: path ?? this.path,
      sourceUri: sourceUri ?? this.sourceUri,
      pinned: pinned ?? this.pinned,
      tags: tags ?? this.tags,
      recentOpenedAtMillis: clearRecentOpenedAt
          ? null
          : (recentOpenedAtMillis ?? this.recentOpenedAtMillis),
    );
  }

  static List<String> _cleanTags(List<String> tags) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      cleaned.add(trimmed);
    }
    return cleaned;
  }
}

/// A bookmark or note anchored to a document.
class ReadingMark {
  ReadingMark({
    required this.id,
    required this.documentId,
    required this.kind,
    required this.ratio,
    this.title = '',
    this.note,
    required this.createdAtMillis,
  });

  final String id;
  final String documentId;
  final ReadingMarkKind kind;
  final double ratio;
  final String title;
  final String? note;
  final int createdAtMillis;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'kind': kind.jsonValue,
    'ratio': ratio,
    if (title.isNotEmpty) 'title': title,
    if (note != null) 'note': note,
    'createdAt': createdAtMillis,
  };

  factory ReadingMark.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final documentId = json['documentId'];
    final kind = ReadingMarkKind.fromJsonValue(json['kind'] ?? 'bookmark');
    final ratio = json['ratio'];
    if (id is! String || id.isEmpty) {
      throw FormatException('mark needs id', json);
    }
    if (documentId is! String || documentId.isEmpty) {
      throw FormatException('mark needs documentId', json);
    }
    if (kind == null) {
      throw FormatException('mark has an unknown kind', json);
    }
    if (ratio is! num) {
      throw FormatException('mark needs a numeric ratio', json);
    }
    return ReadingMark(
      id: id,
      documentId: documentId,
      kind: kind,
      ratio: ratio.toDouble().clamp(0.0, 1.0),
      title: (json['title'] as String?) ?? '',
      note: json['note'] as String?,
      createdAtMillis:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// The whole metadata set for one library.
class LibrarySnapshot {
  LibrarySnapshot({
    this.schema = librarySchemaVersion,
    required this.updatedAtMillis,
    List<DocumentRecord> documents = const [],
    List<String> tags = const [],
    List<String> pinnedTags = const [],
    List<ReadingMark> marks = const [],
  }) : documents = List<DocumentRecord>.of(documents),
       tags = _cleanTagList(tags),
       pinnedTags = _cleanTagList(pinnedTags),
       marks = List<ReadingMark>.of(marks);

  factory LibrarySnapshot.empty() {
    return LibrarySnapshot(
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  int schema;
  int updatedAtMillis;
  final List<DocumentRecord> documents;
  final List<String> tags;
  final List<String> pinnedTags;
  final List<ReadingMark> marks;

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'updatedAt': updatedAtMillis,
    'documents': documents.map((document) => document.toJson()).toList(),
    'tags': tags,
    'pinnedTags': pinnedTags,
    'marks': marks.map((mark) => mark.toJson()).toList(),
  };

  DocumentRecord? recordForPath(String path) {
    for (final record in documents) {
      if (record.path == path) return record;
    }
    return null;
  }

  DocumentRecord? recordForId(String id) {
    for (final record in documents) {
      if (record.id == id) return record;
    }
    return null;
  }

  /// Finds the record for [path], creating one when the library never saw it.
  DocumentRecord ensureRecord(
    String path, {
    required String id,
    String? sourceUri,
  }) {
    final existing = recordForPath(path);
    if (existing != null) {
      if (sourceUri == null || existing.sourceUri == sourceUri) {
        return existing;
      }
      final updated = existing.copyWith(sourceUri: sourceUri);
      documents[documents.indexOf(existing)] = updated;
      return updated;
    }
    final documentId = recordForId(id)?.id ?? id;
    final record = DocumentRecord(
      id: documentId,
      path: path,
      sourceUri: sourceUri,
    );
    documents.add(record);
    return record;
  }

  /// Inserts [record], replacing whatever had the same id or path.
  void upsertRecord(DocumentRecord record) {
    final index = documents.indexWhere(
      (existing) => existing.id == record.id || existing.path == record.path,
    );
    if (index == -1) {
      documents.add(record);
    } else {
      documents[index] = record;
    }
  }

  DocumentRecord? removeRecordForPath(String path) {
    final index = documents.indexWhere((record) => record.path == path);
    if (index == -1) return null;
    return documents.removeAt(index);
  }

  List<ReadingMark> marksForDocument(String documentId) {
    return marks.where((mark) => mark.documentId == documentId).toList();
  }

  /// Adds [tags] to the known tag list.
  void registerTags(Iterable<String> newTags) {
    for (final tag in _cleanTagList(newTags)) {
      if (!tags.contains(tag)) tags.add(tag);
    }
    tags.sort();
  }

  /// Drops tags that no document uses any more, keeping pinned ones.
  int pruneUnusedTags() {
    final used = <String>{};
    for (final record in documents) {
      used.addAll(record.tags);
    }
    final before = tags.length;
    tags
      ..removeWhere((tag) => !used.contains(tag) && !pinnedTags.contains(tag))
      ..sort();
    return before - tags.length;
  }

  LibrarySnapshot copy() {
    return LibrarySnapshot(
      schema: schema,
      updatedAtMillis: updatedAtMillis,
      documents: [
        for (final record in documents)
          DocumentRecord(
            id: record.id,
            path: record.path,
            sourceUri: record.sourceUri,
            pinned: record.pinned,
            tags: record.tags,
            recentOpenedAtMillis: record.recentOpenedAtMillis,
          ),
      ],
      tags: tags,
      pinnedTags: pinnedTags,
      marks: [
        for (final mark in marks)
          ReadingMark(
            id: mark.id,
            documentId: mark.documentId,
            kind: mark.kind,
            ratio: mark.ratio,
            title: mark.title,
            note: mark.note,
            createdAtMillis: mark.createdAtMillis,
          ),
      ],
    );
  }

  static List<String> _cleanTagList(Iterable<String> input) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final tag in input) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      cleaned.add(trimmed);
    }
    return cleaned;
  }
}

/// A parsed snapshot plus what had to be thrown away while parsing it.
class LibraryParseResult {
  const LibraryParseResult({
    required this.snapshot,
    this.droppedEntries = 0,
    this.quarantinePath,
  });

  final LibrarySnapshot snapshot;

  /// Records/marks that could not be parsed and were left out.
  final int droppedEntries;

  /// Copy of the unreadable original, when the file could not be parsed at all.
  final String? quarantinePath;

  /// True when nothing usable came back and the caller should rebuild.
  bool get isEmpty => snapshot.documents.isEmpty && snapshot.marks.isEmpty;
}
