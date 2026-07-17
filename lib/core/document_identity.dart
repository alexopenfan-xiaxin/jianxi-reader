import 'dart:convert';
import 'dart:math';

import 'metadata_file_store.dart';

/// Manages stable document identifiers that survive renames and mirror migrations.
///
/// ID generation strategy:
/// - Referenced documents: derived from `sourceUri` (stable across mirror changes).
/// - Local documents: auto-generated UUID-like string, stored in a path→ID map.
class DocumentIdentityService {
  DocumentIdentityService._();

  static const _idMapFileName = 'id_map.json';
  static final _random = Random.secure();
  static Map<String, String>? _idMap;
  static Future<Map<String, String>>? _idMapFuture;

  static Future<Map<String, String>> _loadIdMap() async {
    return _idMapFuture ??= () async {
      final file = await MetadataFileStore.file(_idMapFileName);
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _idMap = decoded.map((k, v) => MapEntry(k, v.toString()));
      } else {
        _idMap = {};
      }
      return _idMap!;
    }();
  }

  /// Get or create a stable document ID for the given path.
  ///
  /// For referenced documents, [sourceUri] should be provided to derive
  /// a URI-based ID that survives mirror path changes.
  static Future<String> getOrCreateId({
    required String path,
    String? sourceUri,
  }) {
    return MetadataFileStore.serialize(_idMapFileName, () async {
      final map = await _loadIdMap();
      final existing = map[path];
      if (existing != null) return existing;

      final id = sourceUri != null && sourceUri.isNotEmpty
          ? sourceIdFor(sourceUri)
          : 'doc_${DateTime.now().microsecondsSinceEpoch}_'
              '${_random.nextInt(1 << 32).toRadixString(16)}';
      final next = Map<String, String>.from(map)..[path] = id;
      await MetadataFileStore.writeJson(_idMapFileName, next);
      _replaceMap(map, next);
      return id;
    });
  }

  static String sourceIdFor(String sourceUri) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(sourceUri)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'ref_${hash.toRadixString(16).padLeft(16, '0')}';
  }

  /// Get the existing ID for a path, or null if not registered.
  static Future<String?> getIdForPath(String path) async {
    final map = await _loadIdMap();
    return map[path];
  }

  /// Update the path mapping when a document is renamed or moved.
  static Future<void> movePath(String oldPath, String newPath) {
    return MetadataFileStore.serialize(_idMapFileName, () async {
      final map = await _loadIdMap();
      final id = map[oldPath];
      if (id == null) return;
      final next = Map<String, String>.from(map)
        ..remove(oldPath)
        ..[newPath] = id;
      await MetadataFileStore.writeJson(_idMapFileName, next);
      _replaceMap(map, next);
    });
  }

  /// Remove a path from the identity map.
  static Future<void> removePath(String path) {
    return MetadataFileStore.serialize(_idMapFileName, () async {
      final map = await _loadIdMap();
      if (!map.containsKey(path)) return;
      final next = Map<String, String>.from(map)..remove(path);
      await MetadataFileStore.writeJson(_idMapFileName, next);
      _replaceMap(map, next);
    });
  }

  static Future<void> restorePath(String path, String id) {
    return MetadataFileStore.serialize(_idMapFileName, () async {
      final map = await _loadIdMap();
      if (map[path] == id) return;
      final next = Map<String, String>.from(map)..[path] = id;
      await MetadataFileStore.writeJson(_idMapFileName, next);
      _replaceMap(map, next);
    });
  }

  static void _replaceMap(
    Map<String, String> current,
    Map<String, String> next,
  ) {
    current
      ..clear()
      ..addAll(next);
  }

  /// Clear the in-memory cache (for testing).
  static void clearCache() {
    _idMap = null;
    _idMapFuture = null;
  }
}
