import '../data/metadata/metadata_store.dart';
import 'document_identity.dart';

/// Persists reading scroll progress per document id.
///
/// The id comes from the document record, so a rename no longer needs a
/// path-keyed migration: the position simply follows the document.
class ReadingProgressService {
  const ReadingProgressService._();

  /// Save the scroll progress ratio (0.0 – 1.0) for the given document.
  ///
  /// Saving never deletes. Treating "near the very top" as "no progress" meant
  /// that opening a document and leaving immediately erased the saved spot,
  /// because the reader reported pixel 0. Callers that mean to clear state use
  /// [clearProgress] instead.
  static Future<void> saveProgress(String path, double ratio) async {
    final documentId = await DocumentIdentityService.getOrCreateId(path: path);
    await MetadataStore.saveProgressRatio(documentId, ratio);
  }

  /// Load the previously saved progress ratio, or `null` if none exists.
  static Future<double?> loadProgress(String path) async {
    final documentId = await DocumentIdentityService.getIdForPath(path);
    if (documentId == null) return null;
    final progress = await MetadataStore.loadProgress();
    return progress[documentId];
  }

  /// Remove stored progress for a document.
  static Future<void> clearProgress(String path) async {
    final documentId = await DocumentIdentityService.getIdForPath(path);
    if (documentId == null) return;
    await MetadataStore.clearProgressRatio(documentId);
  }

  /// Kept for callers that still think in paths: the id carries the position,
  /// so moving the document is what actually moves its progress.
  static Future<void> moveProgress(String oldPath, String newPath) {
    return DocumentIdentityService.movePath(oldPath, newPath);
  }
}
