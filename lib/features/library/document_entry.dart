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
    this.sourceUri,
    this.tags = const [],
    this.pinned = false,
    this.isMissing = false,
  });

  final String path;
  final String name;
  final DocumentType type;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime? recentOpenedAt;
  final bool isReferenced;
  final String? sourceUri;
  final List<String> tags;
  final bool pinned;

  /// True when the record survived but the file behind it is gone (foreign
  /// rename, revoked SAF grant). The library keeps the entry so tags, bookmarks
  /// and the reading position are not silently dropped.
  final bool isMissing;

  DocumentEntry copyWith({
    String? path,
    String? name,
    DocumentType? type,
    int? sizeBytes,
    DateTime? modifiedAt,
    DateTime? recentOpenedAt,
    bool? isReferenced,
    String? sourceUri,
    List<String>? tags,
    bool? pinned,
    bool? isMissing,
  }) {
    return DocumentEntry(
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      recentOpenedAt: recentOpenedAt ?? this.recentOpenedAt,
      isReferenced: isReferenced ?? this.isReferenced,
      sourceUri: sourceUri ?? this.sourceUri,
      tags: List.unmodifiable(tags ?? this.tags),
      pinned: pinned ?? this.pinned,
      isMissing: isMissing ?? this.isMissing,
    );
  }

  /// A placeholder for a document whose file is gone.
  factory DocumentEntry.missing({
    required String path,
    required DocumentType type,
    DateTime? recentOpenedAt,
    bool isReferenced = true,
    String? sourceUri,
    List<String> tags = const [],
    bool pinned = false,
  }) {
    return DocumentEntry(
      path: path,
      name: p.basename(path),
      type: type,
      sizeBytes: 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
      recentOpenedAt: recentOpenedAt,
      isReferenced: isReferenced,
      sourceUri: sourceUri,
      tags: List.unmodifiable(tags),
      pinned: pinned,
      isMissing: true,
    );
  }

  static Future<DocumentEntry> fromFile(
    File file, {
    DateTime? recentOpenedAt,
    bool isReferenced = false,
    String? sourceUri,
    List<String> tags = const [],
    bool pinned = false,
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
      sourceUri: sourceUri,
      tags: List.unmodifiable(tags),
      pinned: pinned,
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
