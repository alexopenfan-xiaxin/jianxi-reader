import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages stable document identifiers that survive renames and mirror migrations.
///
/// ID generation strategy:
/// - Referenced documents: derived from `sourceUri` (stable across mirror changes).
/// - Local documents: auto-generated UUID-like string, stored in a path→ID map.
class DocumentIdentityService {
  DocumentIdentityService._();

  static const _idMapFileName = 'id_map.json';
  static Map<String, String>? _idMap;
  static Future<Map<String, String>>? _idMapFuture;

  static Future<Map<String, String>> _loadIdMap() async {
    return _idMapFuture ??= () async {
      final file = await _idMapFile;
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          _idMap = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (e) {
          debugPrint('[DocumentIdentity] load id map failed: $e');
          _idMap = {};
        }
      } else {
        _idMap = {};
      }
      return _idMap!;
    }();
  }

  static Future<File> get _idMapFile async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    if (!metadataDir.existsSync()) {
      await metadataDir.create(recursive: true);
    }
    return File('${metadataDir.path}/$_idMapFileName');
  }

  /// Get or create a stable document ID for the given path.
  ///
  /// For referenced documents, [sourceUri] should be provided to derive
  /// a URI-based ID that survives mirror path changes.
  static Future<String> getOrCreateId({
    required String path,
    String? sourceUri,
  }) async {
    final map = await _loadIdMap();

    // Check if we already have an ID for this path.
    final existing = map[path];
    if (existing != null) return existing;

    // For referenced docs, derive ID from sourceUri.
    String id;
    if (sourceUri != null && sourceUri.isNotEmpty) {
      id = 'ref_${sourceUri.hashCode.abs().toRadixString(36)}';
    } else {
      // Check if any existing entry has the same sourceUri-derived ID.
      final rng = Random();
      id = 'doc_${DateTime.now().microsecondsSinceEpoch}_${rng.nextInt(999999)}';
    }

    map[path] = id;
    await _saveIdMap(map);
    return id;
  }

  /// Get the existing ID for a path, or null if not registered.
  static Future<String?> getIdForPath(String path) async {
    final map = await _loadIdMap();
    return map[path];
  }

  /// Update the path mapping when a document is renamed or moved.
  static Future<void> movePath(String oldPath, String newPath) async {
    final map = await _loadIdMap();
    final id = map.remove(oldPath);
    if (id != null) {
      map[newPath] = id;
      await _saveIdMap(map);
    }
  }

  /// Remove a path from the identity map.
  static Future<void> removePath(String path) async {
    final map = await _loadIdMap();
    if (map.remove(path) != null) {
      await _saveIdMap(map);
    }
  }

  static Future<void> _saveIdMap(Map<String, String> map) async {
    try {
      final file = await _idMapFile;
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      debugPrint('[DocumentIdentity] save id map failed: $e');
    }
  }

  /// Clear the in-memory cache (for testing).
  static void clearCache() {
    _idMap = null;
    _idMapFuture = null;
  }
}
