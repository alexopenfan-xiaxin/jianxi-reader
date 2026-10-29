import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/metadata_file_store.dart';
import 'library_schema.dart';

/// Reads the 2.x metadata spread (SharedPreferences + three JSON files) into a
/// schema v1 snapshot.
///
/// This is deliberately self-contained: it reads the bytes as they are on disk
/// instead of calling the services that are about to be replaced, so a
/// half-migrated build cannot feed its own new format back into the importer.
///
/// The preference key formats mirror `DocumentFileService`; the migration test
/// writes them through that service and asserts nothing is lost, which is what
/// keeps this file honest.
class LegacyMetadataImport {
  LegacyMetadataImport._();

  // Mirrors DocumentFileService's private key builders.
  static const String referencedPathsKey = 'referenced.paths';
  static const String referencedSourceUriPrefix = 'referenced.sourceUri.';
  static const String recentOpenedPrefix = 'document.recentOpened.';
  static const String documentPinnedPrefix = 'document.pinned.';
  static const String allTagsKey = 'document.tags';
  static const String pinnedTagsKey = 'document.tags.pinned';
  static const String documentTagsPrefix = 'document.tags.';

  static const String idMapFileName = 'id_map.json';
  static const String bookmarksFileName = 'bookmarks.json';

  /// Returns null when there is nothing to import (a fresh install).
  static Future<LibrarySnapshot?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final idMap = await _readIdMap();
    final marks = await _readBookmarks();

    final paths = <String>{...idMap.keys};
    for (final key in preferences.getKeys()) {
      if (key.startsWith(documentTagsPrefix)) {
        paths.add(key.substring(documentTagsPrefix.length));
      } else if (key.startsWith(documentPinnedPrefix)) {
        paths.add(key.substring(documentPinnedPrefix.length));
      } else if (key.startsWith(recentOpenedPrefix)) {
        paths.add(key.substring(recentOpenedPrefix.length));
      }
    }
    final referenced =
        preferences.getStringList(referencedPathsKey) ?? const [];
    paths.addAll(referenced);

    final legacyTags = preferences.getStringList(allTagsKey) ?? const [];
    final pinnedTags = preferences.getStringList(pinnedTagsKey) ?? const [];
    if (paths.isEmpty && marks.isEmpty && legacyTags.isEmpty) {
      return null;
    }

    final documents = <DocumentRecord>[];
    for (final path in paths) {
      final id = idMap[path];
      if (id == null || id.isEmpty) {
        // Without an id there is nothing to hang marks off; the scan pass
        // creates one through DocumentIdentityService when it first sees it.
        continue;
      }
      documents.add(
        DocumentRecord(
          id: id,
          path: path,
          sourceUri: preferences.getString('$referencedSourceUriPrefix$path'),
          pinned: preferences.getBool('$documentPinnedPrefix$path') ?? false,
          tags:
              preferences.getStringList('$documentTagsPrefix$path') ?? const [],
          recentOpenedAtMillis: preferences.getInt('$recentOpenedPrefix$path'),
        ),
      );
    }

    final snapshot = LibrarySnapshot(
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      documents: documents,
      tags: legacyTags,
      pinnedTags: pinnedTags,
      marks: marks,
    );
    snapshot.registerTags(documents.expand((document) => document.tags));
    debugPrint(
      '[LegacyMetadataImport] ${snapshot.documents.length} documents, '
      '${snapshot.marks.length} marks, ${snapshot.tags.length} tags',
    );
    return snapshot;
  }

  /// Reads the 2.x `readingProgress.<path>` values, keyed by document id.
  static Future<Map<String, double>> readProgress(
    LibrarySnapshot snapshot,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    const prefix = 'readingProgress.';
    final byId = <String, double>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final value = preferences.getDouble(key);
      if (value == null) continue;
      final record = snapshot.recordForPath(key.substring(prefix.length));
      if (record == null) continue;
      byId[record.id] = value.clamp(0.0, 1.0);
    }
    return byId;
  }

  static Future<Map<String, String>> _readIdMap() async {
    final read = await MetadataFileStore.readJson(idMapFileName);
    final data = read.data;
    if (data is! Map) return const {};
    final map = <String, String>{};
    data.forEach((key, value) {
      final path = key?.toString();
      final id = value?.toString();
      if (path == null || path.isEmpty || id == null || id.isEmpty) return;
      map[path] = id;
    });
    return map;
  }

  static Future<List<ReadingMark>> _readBookmarks() async {
    final read = await MetadataFileStore.readJson(bookmarksFileName);
    final data = read.data;
    if (data is! List) return const [];
    final marks = <ReadingMark>[];
    for (final entry in data) {
      if (entry is! Map) continue;
      final json = Map<String, dynamic>.from(entry);
      try {
        marks.add(
          ReadingMark(
            id: json['id'] as String,
            documentId: json['documentId'] as String,
            kind: ReadingMarkKind.bookmark,
            ratio: (json['progressRatio'] as num).toDouble(),
            title: (json['title'] as String?) ?? '',
            note: json['note'] as String?,
            createdAtMillis:
                (json['createdAtMillis'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (error) {
        debugPrint('[LegacyMetadataImport] dropped bookmark: $error');
      }
    }
    return marks;
  }
}
