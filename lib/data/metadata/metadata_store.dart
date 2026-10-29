import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/metadata_file_store.dart';
import 'legacy_import.dart';
import 'library_schema.dart';

/// The single writer for `metadata/library.json`.
///
/// Everything that changes tags, pinning, recency, marks or the tag list goes
/// through [transaction]: one queued read-modify-write per mutation, on the
/// same serialisation queue `MetadataFileStore` already uses, so concurrent
/// imports and removals can no longer interleave and clobber each other.
class MetadataStore {
  MetadataStore._();

  static const String fileName = 'library.json';
  static const String backupsDirectoryName = 'backups';

  static LibrarySnapshot? _cache;
  static Future<LibrarySnapshot>? _loadFuture;

  /// Loads the snapshot once per process.
  ///
  /// Order of preference: the schema v1 file, then a rebuild from the 2.x
  /// sources (prefs + `id_map.json` + `bookmarks.json`). A file that no longer
  /// parses is quarantined by `MetadataFileStore` before anything can
  /// overwrite it..
  static Future<LibrarySnapshot> load() {
    return _loadFuture ??= () async {
      final read = await readFromDisk();
      final parsed = read.snapshot;
      // A file that parses is authoritative even when it is empty: rebuilding
      // from the 2.x sources would resurrect documents the user removed.
      if (parsed != null) {
        _cache = parsed;
        return parsed;
      }

      final rebuilt = await LegacyMetadataImport.read();
      if (rebuilt == null) {
        final fallback = parsed ?? LibrarySnapshot.empty();
        _cache = fallback;
        return fallback;
      }
      await MetadataFileStore.writeJson(fileName, rebuilt.toJson());
      debugPrint(
        '[MetadataStore] rebuilt library.json from legacy sources '
        '(${rebuilt.documents.length} documents, ${rebuilt.tags.length} tags, '
        '${rebuilt.marks.length} marks)',
      );
      _cache = rebuilt;
      return rebuilt;
    }();
  }

  /// Reads library.json without consulting or filling the cache.
  static Future<MetadataStoreRead> readFromDisk() async {
    final read = await MetadataFileStore.readJson(fileName);
    final data = read.data;
    if (data is! Map) {
      return MetadataStoreRead(
        snapshot: null,
        quarantinePath: read.quarantinePath,
        fileExists: data != null || read.quarantinePath != null,
      );
    }
    final result = parseSnapshot(Map<String, dynamic>.from(data));
    return MetadataStoreRead(
      snapshot: result.snapshot,
      droppedEntries: result.droppedEntries,
      quarantinePath: read.quarantinePath,
      fileExists: true,
    );
  }

  /// Parses a snapshot, dropping only the records that no longer fit.
  static LibraryParseResult parseSnapshot(Map<String, dynamic> json) {
    var dropped = 0;
    final documents = <DocumentRecord>[];
    for (final entry in (json['documents'] as List?) ?? const []) {
      if (entry is! Map) {
        dropped++;
        continue;
      }
      try {
        final record = DocumentRecord.fromJson(
          Map<String, dynamic>.from(entry),
        );
        documents.add(record);
      } catch (error) {
        dropped++;
        debugPrint('[MetadataStore] dropped document record: $error');
      }
    }

    final marks = <ReadingMark>[];
    for (final entry in (json['marks'] as List?) ?? const []) {
      if (entry is! Map) {
        dropped++;
        continue;
      }
      try {
        marks.add(ReadingMark.fromJson(Map<String, dynamic>.from(entry)));
      } catch (error) {
        dropped++;
        debugPrint('[MetadataStore] dropped mark: $error');
      }
    }

    final snapshot = LibrarySnapshot(
      schema: (json['schema'] as num?)?.toInt() ?? librarySchemaVersion,
      updatedAtMillis:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      documents: documents,
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      pinnedTags:
          (json['pinnedTags'] as List?)?.whereType<String>().toList() ??
          const [],
      marks: marks,
    );
    if (dropped > 0) {
      debugPrint('[MetadataStore] dropped $dropped damaged entr(ies)');
    }
    return LibraryParseResult(snapshot: snapshot, droppedEntries: dropped);
  }

  /// Runs [action] against the current snapshot and persists the result.
  ///
  /// The action must mutate the snapshot it is given; throwing aborts the write
  /// and leaves the file untouched.
  static Future<T> transaction<T>(
    Future<T> Function(LibrarySnapshot snapshot) action,
  ) {
    return MetadataFileStore.serialize(fileName, () async {
      final snapshot = await _freshForWrite();
      final result = await action(snapshot);
      snapshot.schema = librarySchemaVersion;
      snapshot.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await MetadataFileStore.writeJson(fileName, snapshot.toJson());
      _cache = snapshot;
      _loadFuture = Future<LibrarySnapshot>.value(snapshot);
      return result;
    });
  }

  /// Replaces the whole file. Used by the migration and by tests.
  static Future<void> replace(LibrarySnapshot snapshot) {
    return MetadataFileStore.serialize(fileName, () async {
      snapshot.schema = librarySchemaVersion;
      snapshot.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
      await MetadataFileStore.writeJson(fileName, snapshot.toJson());
      _cache = snapshot;
      _loadFuture = Future<LibrarySnapshot>.value(snapshot);
    });
  }

  /// Drops marks that point at documents this library no longer has.
  static Future<int> collectGarbage() {
    return transaction((snapshot) async {
      final known = {for (final record in snapshot.documents) record.id};
      final before = snapshot.marks.length;
      snapshot.marks.removeWhere((mark) => !known.contains(mark.documentId));
      return before - snapshot.marks.length;
    });
  }

  /// Copies the metadata directory into `backups/<label>-<timestamp>/`.
  ///
  /// Returns the backup path, or null when there was nothing to copy. Runs
  /// before a migration so a failed upgrade can be inspected (or restored).
  static Future<String?> snapshotToBackups(String label) async {
    final directory = await MetadataFileStore.directory();
    if (!await directory.exists()) {
      return null;
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final target = Directory(
      p.join(directory.path, backupsDirectoryName, '$label-$stamp'),
    );
    await target.create(recursive: true);
    var copied = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.contains('.corrupt-')) continue;
      await entity.copy(p.join(target.path, name));
      copied++;
    }
    if (copied == 0) {
      await target.delete(recursive: true);
      return null;
    }
    debugPrint('[MetadataStore] snapshot written to ${target.path} ($copied)');
    return target.path;
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }

  static LibrarySnapshot? get cachedSnapshot => _cache;

  static Future<LibrarySnapshot> _freshForWrite() async {
    final cached = _cache;
    if (cached != null) return cached;
    await load();
    return _cache ?? LibrarySnapshot.empty();
  }
}

/// Outcome of reading `library.json` from disk.
class MetadataStoreRead {
  const MetadataStoreRead({
    required this.snapshot,
    this.droppedEntries = 0,
    this.quarantinePath,
    this.fileExists = false,
  });

  final LibrarySnapshot? snapshot;
  final int droppedEntries;
  final String? quarantinePath;
  final bool fileExists;
}
