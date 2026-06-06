import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/library/document_entry.dart';
import 'file_rules.dart';

abstract class DocumentLibraryService {
  Future<List<DocumentEntry>> scanLibrary();

  Future<DocumentEntry?> pickAndImportDocument();

  Future<DocumentEntry> refreshDocument(DocumentEntry document);

  Future<DocumentEntry> renameDocument(DocumentEntry document, String baseName);

  Future<void> removeDocument(DocumentEntry document);

  Future<void> markDocumentOpened(DocumentEntry document);
}

class DocumentFileService implements DocumentLibraryService {
  const DocumentFileService();

  static const libraryFolderName = 'documents';
  static const _documentAccessChannel =
      MethodChannel('com.jianxi.reader/document_access');
  static const _recentOpenedPrefix = 'document.recentOpened.';
  static const _referencedPathsKey = 'referenced.paths';
  static const _referencedSourceUriPrefix = 'referenced.sourceUri.';

  @override
  Future<List<DocumentEntry>> scanLibrary() async {
    final entries = <DocumentEntry>[];
    final preferences = await SharedPreferences.getInstance();

    final directory = await ensureLibraryDirectory();
    final files = directory
        .listSync(followLinks: false)
        .where(DocumentFileRules.isSupportedFile)
        .cast<File>()
        .toList();

    for (final file in files) {
      entries.add(
        await DocumentEntry.fromFile(
          file,
          recentOpenedAt: _recentOpenedAt(preferences, file.path),
        ),
      );
    }

    // 2. Add referenced (original path) files
    final referencedPaths =
        preferences.getStringList(_referencedPathsKey) ?? [];
    for (final path in referencedPaths) {
      final refreshedPath =
          await _refreshReferencedMirror(preferences, path) ?? path;
      final file = File(refreshedPath);
      if (!file.existsSync()) continue;
      if (!DocumentFileRules.isSupportedPath(refreshedPath)) continue;
      entries.add(
        await DocumentEntry.fromFile(
          file,
          recentOpenedAt: _recentOpenedAt(preferences, refreshedPath),
          isReferenced: true,
        ),
      );
    }

    return entries;
  }

  @override
  Future<DocumentEntry?> pickAndImportDocument() async {
    if (Platform.isAndroid) {
      try {
        final androidDocument = await _pickAndroidReferencedDocument();
        return androidDocument;
      } on MissingPluginException {
        debugPrint(
          '[DocumentFileService] Android document picker channel unavailable',
        );
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'html'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null) {
      return null;
    }

    final sourcePath = result.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw const FileSystemException('系统文件选择器没有返回可读取的路径');
    }

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw FileSystemException('文件不存在', sourcePath);
    }
    if (!DocumentFileRules.isSupportedPath(sourcePath)) {
      throw FileSystemException('仅支持 Markdown 和 HTML 文档', sourcePath);
    }

    final preferences = await SharedPreferences.getInstance();
    final paths = preferences.getStringList(_referencedPathsKey) ?? [];
    if (!paths.contains(sourcePath)) {
      paths.add(sourcePath);
      await preferences.setStringList(_referencedPathsKey, paths);
    }

    return DocumentEntry.fromFile(source, isReferenced: true);
  }

  @override
  Future<DocumentEntry> refreshDocument(DocumentEntry document) async {
    final preferences = await SharedPreferences.getInstance();
    final refreshedPath = document.isReferenced
        ? await _refreshReferencedMirror(preferences, document.path)
        : document.path;
    final path = refreshedPath ?? document.path;
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('文档不存在或已被移出', path);
    }
    return DocumentEntry.fromFile(
      file,
      recentOpenedAt: _recentOpenedAt(preferences, path),
      isReferenced: document.isReferenced,
    );
  }

  Future<Directory> ensureLibraryDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final libraryDirectory = Directory(
      p.join(appDirectory.path, libraryFolderName),
    );

    if (!libraryDirectory.existsSync()) {
      await libraryDirectory.create(recursive: true);
    }

    return libraryDirectory;
  }

  @override
  Future<DocumentEntry> renameDocument(
    DocumentEntry document,
    String baseName,
  ) async {
    final cleanBaseName = DocumentFileRules.validateBaseName(baseName);
    final source = File(document.path);
    if (!source.existsSync()) {
      throw FileSystemException('文档不存在或已被移出', document.path);
    }

    final extension = p.extension(document.path);
    final destinationPath = p.join(
      source.parent.path,
      '$cleanBaseName$extension',
    );
    if (p.equals(source.path, destinationPath)) {
      return document;
    }
    if (File(destinationPath).existsSync()) {
      throw FileSystemException('同名文档已存在', destinationPath);
    }

    final renamedFile = await source.rename(destinationPath);
    final preferences = await SharedPreferences.getInstance();
    await _moveDocumentMetadata(preferences, document.path, renamedFile.path);
    if (document.isReferenced) {
      await _updateReferencedPath(preferences, document.path, renamedFile.path);
      await _moveReferencedSourceUri(
        preferences,
        document.path,
        renamedFile.path,
      );
    }
    return DocumentEntry.fromFile(
      renamedFile,
      recentOpenedAt: _recentOpenedAt(preferences, renamedFile.path),
      isReferenced: document.isReferenced,
    );
  }

  Future<void> _updateReferencedPath(
    SharedPreferences preferences,
    String oldPath,
    String newPath,
  ) async {
    final paths = preferences.getStringList(_referencedPathsKey) ?? [];
    final index = paths.indexOf(oldPath);
    if (index != -1) {
      paths[index] = newPath;
      await preferences.setStringList(_referencedPathsKey, paths);
    }
  }

  @override
  Future<void> removeDocument(DocumentEntry document) async {
    final preferences = await SharedPreferences.getInstance();

    if (document.isReferenced) {
      final paths = preferences.getStringList(_referencedPathsKey) ?? [];
      paths.remove(document.path);
      await preferences.setStringList(_referencedPathsKey, paths);
      final sourceUri = preferences.getString(
        _referencedSourceUriKey(document.path),
      );
      await preferences.remove(_referencedSourceUriKey(document.path));
      if (sourceUri != null) {
        final mirror = File(document.path);
        if (mirror.existsSync()) {
          await mirror.delete();
        }
      }
    } else {
      final file = File(document.path);
      if (file.existsSync()) {
        await file.delete();
      }
    }

    await _clearDocumentMetadata(preferences, document.path);
  }

  @override
  Future<void> markDocumentOpened(DocumentEntry document) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _recentOpenedKey(document.path),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static DateTime? _recentOpenedAt(SharedPreferences preferences, String path) {
    final milliseconds = preferences.getInt(_recentOpenedKey(path));
    if (milliseconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  static String _recentOpenedKey(String path) {
    return '$_recentOpenedPrefix$path';
  }

  static String _referencedSourceUriKey(String path) {
    return '$_referencedSourceUriPrefix$path';
  }

  static Future<void> _clearDocumentMetadata(
    SharedPreferences preferences,
    String path,
  ) {
    return preferences.remove(_recentOpenedKey(path));
  }

  static Future<void> _moveDocumentMetadata(
    SharedPreferences preferences,
    String oldPath,
    String newPath,
  ) async {
    final recentOpened = preferences.getInt(_recentOpenedKey(oldPath));
    await _clearDocumentMetadata(preferences, oldPath);
    if (recentOpened != null) {
      await preferences.setInt(_recentOpenedKey(newPath), recentOpened);
    }
  }

  static Future<void> _moveReferencedSourceUri(
    SharedPreferences preferences,
    String oldPath,
    String newPath,
  ) async {
    final sourceUri = preferences.getString(_referencedSourceUriKey(oldPath));
    await preferences.remove(_referencedSourceUriKey(oldPath));
    if (sourceUri != null) {
      await preferences.setString(_referencedSourceUriKey(newPath), sourceUri);
    }
  }

  Future<DocumentEntry?> _pickAndroidReferencedDocument() async {
    final picked = await _documentAccessChannel.invokeMapMethod<String, Object?>(
      'pickDocument',
    );
    if (picked == null) {
      return null;
    }

    final path = picked['path'] as String?;
    final sourceUri = picked['uri'] as String?;
    if (path == null || path.isEmpty || sourceUri == null || sourceUri.isEmpty) {
      throw const FileSystemException('系统文件选择器没有返回可读取的路径');
    }
    if (!DocumentFileRules.isSupportedPath(path)) {
      final pickedFile = File(path);
      if (pickedFile.existsSync()) {
        await pickedFile.delete();
      }
      throw FileSystemException('仅支持 Markdown 和 HTML 文档', path);
    }

    final preferences = await SharedPreferences.getInstance();
    final paths = preferences.getStringList(_referencedPathsKey) ?? [];
    if (!paths.contains(path)) {
      paths.add(path);
      await preferences.setStringList(_referencedPathsKey, paths);
    }
    await preferences.setString(_referencedSourceUriKey(path), sourceUri);

    return DocumentEntry.fromFile(File(path), isReferenced: true);
  }

  Future<String?> _refreshReferencedMirror(
    SharedPreferences preferences,
    String path,
  ) async {
    final sourceUri = preferences.getString(_referencedSourceUriKey(path));
    if (sourceUri == null || sourceUri.isEmpty) {
      return path;
    }
    try {
      final refreshed = await _documentAccessChannel
          .invokeMapMethod<String, Object?>(
        'refreshDocument',
        {'uri': sourceUri, 'path': path},
      );
      return refreshed?['path'] as String? ?? path;
    } on MissingPluginException {
      return path;
    } catch (error) {
      debugPrint(
        '[DocumentFileService] refresh referenced document failed: $error',
      );
      return File(path).existsSync() ? path : null;
    }
  }
}
