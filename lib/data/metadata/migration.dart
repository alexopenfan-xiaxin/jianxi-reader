import 'package:flutter/foundation.dart';

import 'library_schema.dart';
import 'metadata_store.dart';

/// Brings `metadata/` from the 2.x layout up to schema v1.
///
/// Runs once at startup and is safe to repeat:
/// * a library file that already parses is left alone;
/// * before rebuilding or upgrading, the metadata directory is copied into
///   `metadata/backups/` so a failed upgrade can still be inspected;
/// * if the rebuild throws, the legacy files are untouched and the app keeps
///   running on them (`MetadataStore.load` falls back to an empty snapshot).
class MetadataMigration {
  MetadataMigration._();

  /// Returns a short human-readable status, useful in logs and tests.
  static Future<String> runIfNeeded() async {
    try {
      final read = await MetadataStore.readFromDisk();
      final parsed = read.snapshot;
      final healthy =
          parsed != null &&
          parsed.schema >= librarySchemaVersion &&
          read.quarantinePath == null;

      if (!healthy) {
        final label = 'v${parsed?.schema ?? 0}';
        final backup = await MetadataStore.snapshotToBackups(label);
        if (backup != null) {
          debugPrint('[MetadataMigration] backup before rebuild: $backup');
        }
      }

      final snapshot = await MetadataStore.load();
      final orphans = await _orphanCount(snapshot);
      if (orphans > 0) {
        final dropped = await MetadataStore.collectGarbage();
        debugPrint('[MetadataMigration] collected $dropped orphan mark(s)');
        return healthy ? 'gc:$dropped' : 'rebuilt+gc:$dropped';
      }
      return healthy ? 'current' : 'rebuilt';
    } catch (error, stackTrace) {
      // Never block startup on metadata: the legacy files still work.
      debugPrint('[MetadataMigration] failed: $error');
      debugPrint(stackTrace.toString());
      return 'failed';
    }
  }

  static Future<int> _orphanCount(LibrarySnapshot snapshot) async {
    final known = {for (final record in snapshot.documents) record.id};
    return snapshot.marks
        .where((mark) => !known.contains(mark.documentId))
        .length;
  }
}
