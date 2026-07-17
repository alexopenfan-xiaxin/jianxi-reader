import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists reading scroll-progress ratio per document path.
class ReadingProgressService {
  const ReadingProgressService._();

  static const _prefix = 'readingProgress.';

  /// Save the scroll progress ratio (0.0 – 1.0) for the given document.
  static Future<void> saveProgress(String path, double ratio) async {
    final clamped = ratio.clamp(0.0, 1.0).toDouble();
    // Skip saving when near the very top — treat as "no progress".
    if (clamped < 0.01) {
      await removeProgress(path);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setDouble(_key(path), clamped)) {
      throw const FileSystemException('无法保存阅读进度');
    }
  }

  /// Load the previously saved progress ratio, or `null` if none exists.
  static Future<double?> loadProgress(String path) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_key(path));
  }

  /// Remove stored progress for a document.
  static Future<void> removeProgress(String path) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(_key(path))) {
      throw const FileSystemException('无法清除阅读进度');
    }
  }

  /// Move stored progress when a document path changes.
  static Future<void> moveProgress(String oldPath, String newPath) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getDouble(_key(oldPath));
    if (value != null) {
      if (!await preferences.setDouble(_key(newPath), value)) {
        throw const FileSystemException('无法迁移阅读进度');
      }
    }
    if (!await preferences.remove(_key(oldPath))) {
      throw const FileSystemException('无法迁移阅读进度');
    }
  }

  static String _key(String path) => '$_prefix$path';
}
