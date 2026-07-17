import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists reading scroll-progress ratio per document path.
class ReadingProgressService {
  const ReadingProgressService._();

  static const _prefix = 'readingProgress.';
  static Future<void> _pendingMutation = Future<void>.value();

  /// Save the scroll progress ratio (0.0 – 1.0) for the given document.
  static Future<void> saveProgress(String path, double ratio) {
    return _serializeMutation(() async {
      final clamped = ratio.clamp(0.0, 1.0).toDouble();
      final preferences = await SharedPreferences.getInstance();
      // Skip saving when near the very top — treat as "no progress".
      final succeeded = clamped < 0.01
          ? await preferences.remove(_key(path))
          : await preferences.setDouble(_key(path), clamped);
      if (!succeeded) {
        throw const FileSystemException('无法保存阅读进度');
      }
    });
  }

  /// Load the previously saved progress ratio, or `null` if none exists.
  static Future<double?> loadProgress(String path) async {
    await _pendingMutation;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_key(path));
  }

  /// Remove stored progress for a document.
  static Future<void> removeProgress(String path) {
    return _serializeMutation(() async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.remove(_key(path))) {
        throw const FileSystemException('无法清除阅读进度');
      }
    });
  }

  /// Move stored progress when a document path changes.
  static Future<void> moveProgress(String oldPath, String newPath) {
    return _serializeMutation(() async {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getDouble(_key(oldPath));
      if (value != null && !await preferences.setDouble(_key(newPath), value)) {
        throw const FileSystemException('无法迁移阅读进度');
      }
      if (!await preferences.remove(_key(oldPath))) {
        throw const FileSystemException('无法迁移阅读进度');
      }
    });
  }

  static String _key(String path) => '$_prefix$path';

  static Future<void> _serializeMutation(Future<void> Function() mutation) {
    final result = _pendingMutation.then((_) => mutation());
    _pendingMutation = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}
