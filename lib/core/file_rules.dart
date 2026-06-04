import 'dart:io';

import 'package:path/path.dart' as p;

enum DocumentType {
  markdown('Markdown', 'MD'),
  html('HTML', 'HTML');

  const DocumentType(this.label, this.badge);

  final String label;
  final String badge;
}

class DocumentFileRules {
  static const supportedExtensions = <String>{
    '.md',
    '.markdown',
    '.html',
    '.htm',
  };

  static final RegExp _invalidBaseNameCharacters = RegExp(r'[\\/:*?"<>|]');

  static DocumentType? typeForPath(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    if (extension == '.md' || extension == '.markdown') {
      return DocumentType.markdown;
    }
    if (extension == '.html' || extension == '.htm') {
      return DocumentType.html;
    }
    return null;
  }

  static bool isSupportedPath(String filePath) {
    return typeForPath(filePath) != null;
  }

  static bool isSupportedFile(FileSystemEntity entity) {
    return entity is File && isSupportedPath(entity.path);
  }

  static String validateBaseName(String baseName) {
    final cleanName = baseName.trim();
    if (cleanName.isEmpty) {
      throw const FileSystemException('文件名不能为空');
    }
    if (cleanName == '.' || cleanName == '..') {
      throw const FileSystemException('文件名不能使用保留名称');
    }
    if (_invalidBaseNameCharacters.hasMatch(cleanName)) {
      throw const FileSystemException('文件名不能包含 \\ / : * ? " < > |');
    }
    return cleanName;
  }

  static String uniqueDestinationPath({
    required Directory directory,
    required String fileName,
    bool Function(String path)? exists,
  }) {
    final cleanName = fileName.trim().isEmpty ? 'document.md' : fileName.trim();
    final extension = p.extension(cleanName);
    final baseName = p.basenameWithoutExtension(cleanName);
    final existsFn = exists ?? (path) => File(path).existsSync();
    var candidate = p.join(directory.path, cleanName);
    var index = 1;

    while (existsFn(candidate)) {
      candidate = p.join(directory.path, '$baseName ($index)$extension');
      index += 1;
    }

    return candidate;
  }
}
