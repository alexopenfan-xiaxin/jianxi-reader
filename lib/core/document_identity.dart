import 'dart:convert';
import 'dart:math';

import '../data/metadata/library_schema.dart';
import '../data/metadata/metadata_store.dart';

/// Manages stable document identifiers that survive renames and mirror moves.
///
/// The id lives on the document record in `metadata/library.json`; `path` is an
/// attribute, so a rename no longer has to keep a second path→id table in sync.
/// Ids are still derived the same way as in 2.x:
/// * referenced documents from `sourceUri` (stable across mirror changes);
/// * local documents from a generated, time-ordered value.
class DocumentIdentityService {
  DocumentIdentityService._();

  static final _random = Random.secure();

  /// Get or create a stable document ID for the given path.
  static Future<String> getOrCreateId({
    required String path,
    String? sourceUri,
  }) async {
    final snapshot = await MetadataStore.load();
    final existing = snapshot.recordForPath(path);
    if (existing != null) return existing.id;

    return MetadataStore.transaction((snapshot) async {
      // Another caller may have created it while we were waiting in the queue.
      final current = snapshot.recordForPath(path);
      if (current != null) return current.id;

      final derived = sourceUri != null && sourceUri.isNotEmpty
          ? sourceIdFor(sourceUri)
          : null;
      // Reuse the source-derived id only when no other record owns it, so two
      // imports of the same URI cannot fork one document's marks.
      final id = derived != null && snapshot.recordForId(derived) == null
          ? derived
          : 'doc_${DateTime.now().microsecondsSinceEpoch}_'
                '${_random.nextInt(1 << 32).toRadixString(16)}';
      snapshot.ensureRecord(path, id: id, sourceUri: sourceUri);
      return id;
    });
  }

  static String sourceIdFor(String sourceUri) {
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final byte in utf8.encode(sourceUri)) {
      hash ^= BigInt.from(byte);
      hash = (hash * prime) & mask;
    }
    return 'ref_${hash.toRadixString(16).padLeft(16, '0')}';
  }

  /// Get the existing ID for a path, or null if not registered.
  static Future<String?> getIdForPath(String path) async {
    final snapshot = await MetadataStore.load();
    return snapshot.recordForPath(path)?.id;
  }

  /// Update the path mapping when a document is renamed or moved.
  static Future<void> movePath(String oldPath, String newPath) {
    return MetadataStore.transaction((snapshot) async {
      final record = snapshot.recordForPath(oldPath);
      if (record == null) return;
      snapshot.upsertRecord(record.copyWith(path: newPath));
    });
  }

  /// Remove a path from the identity map.
  static Future<void> removePath(String path) {
    return MetadataStore.transaction((snapshot) async {
      if (snapshot.recordForPath(path) == null) return;
      snapshot.removeRecordForPath(path);
    });
  }

  /// Re-attach an id to a path (used when a removal is rolled back).
  static Future<void> restorePath(String path, String id) {
    return MetadataStore.transaction((snapshot) async {
      final existing = snapshot.recordForPath(path);
      if (existing?.id == id) return;
      snapshot.upsertRecord(DocumentRecord(id: id, path: path));
    });
  }

  /// Clear the in-memory cache (for testing).
  static void clearCache() {
    MetadataStore.clearCache();
  }
}
