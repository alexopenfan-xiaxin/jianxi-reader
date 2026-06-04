import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/file_rules.dart';

class DocumentEntry {
  const DocumentEntry({
    required this.path,
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.modifiedAt,
    this.recentOpenedAt,
    this.isReferenced = false,
  });

  final String path;
  final String name;
  final DocumentType type;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime? recentOpenedAt;
  final bool isReferenced;

  static Future<DocumentEntry> fromFile(
    File file, {
    DateTime? recentOpenedAt,
    bool isReferenced = false,
  }) async {
    final type = DocumentFileRules.typeForPath(file.path);
    if (type == null) {
      throw FileSystemException('不支持的文档类型', file.path);
    }

    final stat = await file.stat();
    return DocumentEntry(
      path: file.path,
      name: p.basename(file.path),
      type: type,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      recentOpenedAt: recentOpenedAt,
      isReferenced: isReferenced,
    );
  }

  String get sizeLabel {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
