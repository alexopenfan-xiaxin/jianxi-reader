import 'package:shared_preferences/shared_preferences.dart';

/// Persists reading scroll-progress ratio per document path.
/// Only enabled for documents whose file size is ≤ [maxFileSizeBytes].
class ReadingProgressService {
  const ReadingProgressService._();

  static const _prefix = 'readingProgress.';

  /// Maximum file size (2 MB) for which progress tracking is enabled.
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Save the scroll progress ratio (0.0 – 1.0) for the given document.
  static Future<void> saveProgress(String path, double ratio) async {
    final clamped = ratio.clamp(0.0, 1.0);
    // Skip saving when near the very top — treat as "no progress".
    if (clamped < 0.01) {
      await _removeProgress(path);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_key(path), clamped);
  }

  /// Load the previously saved progress ratio, or `null` if none exists.
  static Future<double?> loadProgress(String path) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_key(path));
  }

  /// Remove stored progress for a document.
  static Future<void> _removeProgress(String path) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(path));
  }

  static String _key(String path) => '$_prefix$path';
}
