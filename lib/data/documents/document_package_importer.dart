import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/file_rules.dart';

/// What one folder import produced.
class DocumentPackageResult {
  const DocumentPackageResult({
    required this.documents,
    required this.packageDirectory,
    this.copiedFiles = 0,
    this.copiedBytes = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  /// Readable documents inside the package, in copy order.
  final List<File> documents;
  final String packageDirectory;
  final int copiedFiles;
  final int copiedBytes;

  /// Files left out because of size or because they are not regular files.
  final int skipped;
  final int failed;
}

/// Copies a folder into the library as a *package*.
///
/// 2.x flattened every file into its own mirror directory and copied only
/// `.md`/`.html`, so a note's `images/x.png` or `style.css` referenced from a
/// sibling folder vanished. 3.0 copies the tree as it is: the package keeps the
/// relative paths, so Markdown's relative links and HTML's local CSS keep
/// working, and the package can be moved as a unit.
///
/// The source folder is never modified.
class DocumentPackageImporter {
  DocumentPackageImporter._();

  static const String packagesDirectoryName = 'packages';

  /// Copy budget for one import; a runaway folder must not fill the device.
  static const int maxTotalBytes = 512 * 1024 * 1024;

  static Future<DocumentPackageResult> importFolder(
    Directory source, {
    required Directory libraryRoot,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('文件夹不存在', source.path);
    }

    final packagesRoot = Directory(
      p.join(libraryRoot.path, packagesDirectoryName),
    );
    await packagesRoot.create(recursive: true);

    final packageName = _uniquePackageName(packagesRoot, source);
    final target = Directory(p.join(packagesRoot.path, packageName));
    await target.create(recursive: true);

    final documents = <File>[];
    var copiedFiles = 0;
    var copiedBytes = 0;
    var skipped = 0;
    var failed = 0;

    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p.relative(entity.path, from: source.path);
      final name = p.basename(entity.path);
      if (_isHiddenOrNoise(name)) {
        continue;
      }
      if (entity is! File) {
        continue;
      }

      try {
        final stat = await entity.stat();
        if (stat.size > DocumentFileRules.maxReadableBytes) {
          skipped++;
          continue;
        }
        if (copiedBytes + stat.size > maxTotalBytes) {
          skipped++;
          continue;
        }
        final destination = File(p.join(target.path, relative));
        await destination.parent.create(recursive: true);
        await entity.copy(destination.path);
        copiedFiles++;
        copiedBytes += stat.size;
        if (DocumentFileRules.isSupportedPath(destination.path)) {
          documents.add(destination);
        }
      } catch (error) {
        failed++;
        debugPrint('[DocumentPackageImporter] copy failed for $relative: '
            '$error');
      }
    }

    debugPrint(
      '[DocumentPackageImporter] $packageName: ${documents.length} documents, '
      '$copiedFiles files, $copiedBytes bytes, $skipped skipped',
    );
    return DocumentPackageResult(
      documents: documents,
      packageDirectory: target.path,
      copiedFiles: copiedFiles,
      copiedBytes: copiedBytes,
      skipped: skipped,
      failed: failed,
    );
  }

  /// Removes the package folder that holds [documentPath] (if any).
  static Future<void> deletePackageOf(
    String documentPath, {
    required Directory libraryRoot,
  }) async {
    final packagesRoot = p.join(libraryRoot.path, packagesDirectoryName);
    if (!p.isWithin(packagesRoot, documentPath)) {
      return;
    }
    final relative = p.relative(documentPath, from: packagesRoot);
    final packageName = relative.split(p.separator).first;
    if (packageName.isEmpty) return;
    final package = Directory(p.join(packagesRoot, packageName));
    if (await package.exists()) {
      await package.delete(recursive: true);
    }
  }

  /// True when [path] lives inside the package area.
  static bool isInsidePackage(String path, Directory libraryRoot) {
    return p.isWithin(
      p.join(libraryRoot.path, packagesDirectoryName),
      path,
    );
  }

  /// The package folder that owns [path], or null when it is a loose document.
  ///
  /// Derived from the path itself so callers do not need the library directory
  /// (and so it still works in tests without a platform plugin).
  static String? packageRootOf(String path) {
    final parts = p.split(path);
    final index = parts.indexOf(packagesDirectoryName);
    if (index <= 0 || index + 1 >= parts.length) {
      return null;
    }
    return p.joinAll(parts.sublist(0, index + 2));
  }

  static bool _isHiddenOrNoise(String name) {
    return name.startsWith('.') || name == 'Thumbs.db' || name == 'desktop.ini';
  }

  static String _uniquePackageName(Directory packagesRoot, Directory source) {
    final base = p.basename(source.path).trim();
    final stem = base.isEmpty ? 'package' : base;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var candidate = '$stem-$stamp';
    var counter = 1;
    while (Directory(p.join(packagesRoot.path, candidate)).existsSync()) {
      candidate = '$stem-$stamp-$counter';
      counter++;
    }
    return candidate;
  }
}
