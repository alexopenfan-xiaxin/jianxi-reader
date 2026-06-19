import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_identity.dart';
import 'library_metadata_store.dart';

/// One-time migration from path-based SharedPreferences metadata
/// to the new JSON-based LibraryMetadataStore with stable document IDs.
class MetadataMigration {
  MetadataMigration._();

  static const _migrationKey = 'metadata.migrated_to_v2';

  /// Run migration if not already done.
  /// Returns true if migration was performed.
  static Future<bool> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return false;

    try {
      await _migrateTags(prefs);
      await _migrateDocumentMetadata(prefs);
      await prefs.setBool(_migrationKey, true);
      debugPrint('[MetadataMigration] migration completed successfully');
      return true;
    } catch (e) {
      debugPrint('[MetadataMigration] migration failed: $e');
      // Don't mark as migrated so it can retry next launch.
      return false;
    }
  }

  static Future<void> _migrateTags(SharedPreferences prefs) async {
    final allTags = prefs.getStringList('document.tags') ?? [];
    final pinnedTags = prefs.getStringList('document.tags.pinned') ?? [];

    final snapshot = await LibraryMetadataStore.load();
    // Merge tags.
    for (final tag in allTags) {
      if (!snapshot.allTags.contains(tag)) {
        snapshot.allTags.add(tag);
      }
    }
    snapshot.allTags.sort();
    for (final tag in pinnedTags) {
      if (!snapshot.pinnedTags.contains(tag)) {
        snapshot.pinnedTags.add(tag);
      }
    }
    snapshot.pinnedTags.sort();
    // Save directly.
    await _saveSnapshot(snapshot);
  }

  static Future<void> _migrateDocumentMetadata(SharedPreferences prefs) async {
    final referencedPaths =
        prefs.getStringList('referenced.paths') ?? [];
    final snapshot = await LibraryMetadataStore.load();

    // Collect all known paths from SharedPreferences keys.
    final allPaths = <String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('document.recentOpened.')) {
        allPaths.add(key.substring('document.recentOpened.'.length));
      } else if (key.startsWith('document.pinned.')) {
        allPaths.add(key.substring('document.pinned.'.length));
      } else if (key.startsWith('document.tags.')) {
        allPaths.add(key.substring('document.tags.'.length));
      } else if (key.startsWith('readingProgress.')) {
        allPaths.add(key.substring('readingProgress.'.length));
      }
    }
    allPaths.addAll(referencedPaths);

    for (final path in allPaths) {
      // Get or create stable ID.
      final sourceUri = prefs.getString('referenced.sourceUri.$path');
      final documentId = await DocumentIdentityService.getOrCreateId(
        path: path,
        sourceUri: sourceUri,
      );

      // Skip if already migrated.
      if (snapshot.documents.containsKey(documentId)) continue;

      final tags = prefs.getStringList('document.tags.$path') ?? [];
      final pinned = prefs.getBool('document.pinned.$path') ?? false;
      final recentMillis = prefs.getInt('document.recentOpened.$path');
      final progress = prefs.getDouble('readingProgress.$path');

      snapshot.documents[documentId] = DocumentMetadata(
        documentId: documentId,
        tags: List<String>.from(tags),
        pinned: pinned,
        recentOpenedAtMillis: recentMillis,
        progressRatio: progress,
      );
    }

    await _saveSnapshot(snapshot);
  }

  static Future<void> _saveSnapshot(LibraryMetadataSnapshot snapshot) async {
    // Access the internal save by using the public API.
    // The snapshot is already in the cache after load().
    // We need to trigger a save.
    // Since _save is private, we use a workaround: save each document.
    // But that's inefficient. Instead, let's just call the private save
    // through a public method. Actually, the cache is already updated in-memory,
    // so we just need to persist it.
    //
    // The simplest approach: use LibraryMetadataStore's internal save.
    // Since we can't access it directly, we'll re-save all tags and each document.
    // This is a one-time migration so performance is acceptable.

    // Save tags.
    for (final tag in snapshot.allTags) {
      await LibraryMetadataStore.createTag(tag);
    }
    for (final tag in snapshot.pinnedTags) {
      await LibraryMetadataStore.setTagPinned(tag, true);
    }
    // Save document metadata.
    for (final doc in snapshot.documents.values) {
      await LibraryMetadataStore.saveDocumentMetadata(doc);
    }
  }
}
