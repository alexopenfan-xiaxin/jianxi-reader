import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../features/library/document_entry.dart';
import 'bookmark_service.dart';
import 'reading_history_service.dart';

/// Everything needed to put a removed document back.
///
/// Removal parks the file in a `.trash/<microseconds>/` folder next to it and
/// keeps the metadata that was about to be deleted here, so an accidental
/// "移出" is reversible for a short window instead of being final.
class DocumentRemoval {
  const DocumentRemoval({
    required this.document,
    required this.removedAtMillis,
    this.documentId,
    this.trashedPath,
    this.recentOpenedAtMillis,
    this.pinned,
    this.tags = const [],
    this.progress,
    this.referencedPaths,
    this.sourceUri,
    this.bookmarks = const [],
    this.history = const [],
  });

  final DocumentEntry document;
  final int removedAtMillis;

  /// Stable document id, when the library had registered one.
  final String? documentId;

  /// Where the file was parked, or null when the app never owned the bytes
  /// (an external source file is never moved or deleted).
  final String? trashedPath;

  final int? recentOpenedAtMillis;
  final bool? pinned;
  final List<String> tags;
  final double? progress;

  /// The referenced-path list as it was before the removal.
  final List<String>? referencedPaths;
  final String? sourceUri;

  final List<ReadingBookmark> bookmarks;
  final List<ReadingHistoryEvent> history;
}

/// Parks removed files and sweeps old ones away.
class DocumentTrash {
  DocumentTrash._();

  static const String directoryName = '.trash';

  /// Moves [file] into a fresh trash folder beside it and returns the new path.
  ///
  /// The folder lives next to the document so the move stays on one volume
  /// (a rename, not a copy) and needs no platform directories.
  static Future<File> stage(File file) async {
    final folder = Directory(
      p.join(
        file.parent.path,
        directoryName,
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await folder.create(recursive: true);
    return file.rename(p.join(folder.path, p.basename(file.path)));
  }

  /// Deletes parked copies older than [maxAge] and returns how many went away.
  ///
  /// Runs at startup; a failure is logged and forgotten — an unreadable trash
  /// folder must never block the library.
  static Future<int> purge(
    Directory libraryDirectory, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    if (!await libraryDirectory.exists()) {
      return 0;
    }
    final cutoff = DateTime.now().subtract(maxAge);
    final doomed = <Directory>[];
    try {
      await for (final entity in libraryDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! Directory) continue;
        if (p.basename(entity.path) != directoryName) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            doomed.add(entity);
          }
        } catch (error) {
          debugPrint('[DocumentTrash] cannot stat ${entity.path}: $error');
        }
      }
    } catch (error) {
      debugPrint('[DocumentTrash] scan failed: $error');
      return 0;
    }

    var removed = 0;
    for (final directory in doomed) {
      try {
        await directory.delete(recursive: true);
        removed++;
      } catch (error) {
        debugPrint('[DocumentTrash] cannot delete ${directory.path}: $error');
      }
    }
    if (removed > 0) {
      debugPrint('[DocumentTrash] purged $removed expired trash folder(s)');
    }
    return removed;
  }
}
