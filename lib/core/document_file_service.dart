import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/library/document_entry.dart';
import 'document_identity.dart';
import 'file_rules.dart';
import 'reading_progress_service.dart';

abstract class DocumentLibraryService {
  Future<List<DocumentEntry>> scanLibrary();

  Future<List<DocumentEntry>> scanLibraryCached();

  void invalidateLibraryCache();

  Future<List<DocumentEntry>> pickAndImportDocuments();

  Future<DocumentFolderImportResult> pickAndImportFolderDocuments();

  Future<DocumentEntry> importExternalUri(Uri uri);

  Future<DocumentEntry> refreshDocument(DocumentEntry document);

  Future<DocumentEntry> renameDocument(DocumentEntry document, String baseName);

  Future<void> removeDocument(DocumentEntry document);

  Future<DocumentEntry> setDocumentPinned(DocumentEntry document, bool pinned);

  Future<DateTime> markDocumentOpened(DocumentEntry document);

  Future<List<String>> loadTags();

  Future<List<String>> loadPinnedTags();

  Future<void> createTag(String name);

  Future<void> deleteTag(String name);

  Future<void> setTagPinned(String name, bool pinned);

  Future<DocumentTagUpdate> updateDocumentTags(
    DocumentEntry document,
    List<String> tags,
  );
}

class DocumentTagUpdate {
  const DocumentTagUpdate({
    required this.documentTags,
    required this.allTags,
  });

  final List<String> documentTags;
  final List<String> allTags;
}

class DocumentFolderImportResult {
  const DocumentFolderImportResult({
    required this.documents,
    required this.skipped,
    required this.failed,
  });

  final List<DocumentEntry> documents;
  final int skipped;
  final int failed;
}

class DocumentFileService implements DocumentLibraryService {
  DocumentFileService();

  static const libraryFolderName = 'documents';
  static const _documentAccessChannel =
      MethodChannel('com.jianxi.reader/document_access');
  static const _recentOpenedPrefix = 'document.recentOpened.';
  static const _documentPinnedPrefix = 'document.pinned.';
  static const _referencedPathsKey = 'referenced.paths';
  static const _referencedSourceUriPrefix = 'referenced.sourceUri.';
  static const _tagsKey = 'document.tags';
  static const _pinnedTagsKey = 'document.tags.pinned';
  static const _documentTagsPrefix = 'document.tags.';
  static const _cacheMaxAge = Duration(minutes: 5);
  static final _prefixedMirrorNamePattern = RegExp(r'^\d{10,}_(.+)$');
  Future<SharedPreferences>? _preferencesFuture;

  List<DocumentEntry>? _cachedEntries;
  DateTime? _cacheTimestamp;
  final Map<String, DateTime> _lastRefreshTimes = {};

  Future<SharedPreferences> _preferences() {
    return _preferencesFuture ??= SharedPreferences.getInstance();
  }

  @override
  Future<List<DocumentEntry>> scanLibrary() async {
    final entries = <DocumentEntry>[];
    final preferences = await _preferences();

    final directory = await ensureLibraryDirectory();
    final files = await directory
        .list(followLinks: false)
        .where(DocumentFileRules.isSupportedFile)
        .cast<File>()
        .toList();

    for (final file in files) {
      entries.add(
        await DocumentEntry.fromFile(
          file,
          recentOpenedAt: _recentOpenedAt(preferences, file.path),
          tags: _documentTags(preferences, file.path),
          pinned: _documentPinned(preferences, file.path),
        ),
      );
    }

    // 2. Add referenced (original path) files
    final referencedPaths =
        preferences.getStringList(_referencedPathsKey) ?? [];
    var pathsChanged = false;
    for (final originalPath in referencedPaths) {
      final migratedPath = await _migratePrefixedReferencedMirror(
        preferences,
        originalPath,
      );
      final path = migratedPath ?? originalPath;
      if (path != originalPath) {
        final index = referencedPaths.indexOf(originalPath);
        if (index != -1) {
          referencedPaths[index] = path;
          pathsChanged = true;
        }
      }
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
          tags: _documentTags(preferences, refreshedPath),
          pinned: _documentPinned(preferences, refreshedPath),
        ),
      );
    }
    if (pathsChanged) {
      await _persistPreference(
        preferences.setStringList(_referencedPathsKey, referencedPaths),
      );
    }
    final activeReferencedPaths = entries
        .where((entry) => entry.isReferenced)
        .map((entry) => entry.path)
        .toSet();
    _lastRefreshTimes.removeWhere(
      (path, _) => !activeReferencedPaths.contains(path),
    );

    _cachedEntries = entries;
    _cacheTimestamp = DateTime.now();
    return entries;
  }

  @override
  Future<List<DocumentEntry>> scanLibraryCached() async {
    if (_cachedEntries != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheMaxAge) {
      return _cachedEntries!;
    }
    return scanLibrary();
  }

  @override
  void invalidateLibraryCache() {
    _cachedEntries = null;
    _cacheTimestamp = null;
  }

  @override
  Future<List<DocumentEntry>> pickAndImportDocuments() async {
    if (Platform.isAndroid) {
      try {
        final androidDocuments = await _pickAndroidReferencedDocuments();
        return androidDocuments;
      } on MissingPluginException {
        debugPrint(
          '[DocumentFileService] Android document picker channel unavailable',
        );
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'html'],
      allowMultiple: true,
      withData: false,
    );

    if (result == null) {
      return const [];
    }

    final imported = <DocumentEntry>[];
    final preferences = await _preferences();
    final paths = preferences.getStringList(_referencedPathsKey) ?? [];
    for (final pickedFile in result.files) {
      final sourcePath = pickedFile.path;
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

      if (!paths.contains(sourcePath)) {
        paths.add(sourcePath);
      }
      imported.add(
        await DocumentEntry.fromFile(
          source,
          isReferenced: true,
          tags: _documentTags(preferences, sourcePath),
          pinned: _documentPinned(preferences, sourcePath),
        ),
      );
    }
    await _persistPreference(
      preferences.setStringList(_referencedPathsKey, paths),
    );

    return imported;
  }

  @override
  Future<DocumentFolderImportResult> pickAndImportFolderDocuments() async {
    if (Platform.isAndroid) {
      try {
        return _pickAndroidReferencedFolderDocuments();
      } on MissingPluginException {
        debugPrint(
          '[DocumentFileService] Android folder picker channel unavailable',
        );
      }
    }

    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null || folderPath.isEmpty) {
      return const DocumentFolderImportResult(
        documents: [],
        skipped: 0,
        failed: 0,
      );
    }

    final preferences = await _preferences();
    final documents = <DocumentEntry>[];
    var skipped = 0;
    var failed = 0;
    await for (final entity in Directory(folderPath).list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !DocumentFileRules.isSupportedPath(entity.path)) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (stat.size > DocumentFileRules.maxReadableBytes) {
          skipped++;
          continue;
        }
        await _rememberReferencedDocument(
          preferences: preferences,
          path: entity.path,
          sourceUri: entity.uri.toString(),
        );
        documents.add(
          await DocumentEntry.fromFile(
            entity,
            isReferenced: true,
            tags: _documentTags(preferences, entity.path),
            pinned: _documentPinned(preferences, entity.path),
          ),
        );
      } catch (error) {
        failed++;
        debugPrint('[DocumentFileService] import folder file failed: $error');
      }
    }
    return DocumentFolderImportResult(
      documents: documents,
      skipped: skipped,
      failed: failed,
    );
  }

  @override
  Future<DocumentEntry> importExternalUri(Uri uri) async {
    if (Platform.isAndroid) {
      try {
        final imported = await _importAndroidExternalUri(uri);
        return imported;
      } on MissingPluginException {
        debugPrint(
          '[DocumentFileService] Android external uri channel unavailable',
        );
      }
    }

    if (uri.scheme.isNotEmpty && uri.scheme != 'file') {
      throw FileSystemException('无法读取系统传入的文档地址', uri.toString());
    }

    final sourcePath = uri.scheme == 'file' ? uri.toFilePath() : uri.path;
    if (sourcePath.isEmpty) {
      throw FileSystemException('系统没有传入可读取的文件路径', uri.toString());
    }
    if (!DocumentFileRules.isSupportedPath(sourcePath)) {
      throw FileSystemException('仅支持 Markdown 和 HTML 文档', sourcePath);
    }

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw FileSystemException('文档不存在或已被移除', sourcePath);
    }

    final preferences = await _preferences();
    await _rememberReferencedDocument(
      preferences: preferences,
      path: sourcePath,
      sourceUri: uri.toString(),
    );
    return DocumentEntry.fromFile(
      source,
      isReferenced: true,
      tags: _documentTags(preferences, sourcePath),
      pinned: _documentPinned(preferences, sourcePath),
    );
  }

  @override
  Future<DocumentEntry> refreshDocument(DocumentEntry document) async {
    final preferences = await _preferences();
    final refreshedPath = document.isReferenced
        ? await _refreshReferencedMirror(preferences, document.path)
        : document.path;
    final path = refreshedPath ?? document.path;
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('文档不存在或已被移出', path);
    }
    final refreshed = await DocumentEntry.fromFile(
      file,
      recentOpenedAt: _recentOpenedAt(preferences, path),
      isReferenced: document.isReferenced,
      tags: _documentTags(preferences, path),
      pinned: _documentPinned(preferences, path),
    );
    invalidateLibraryCache();
    return refreshed;
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

    final preferences = await _preferences();
    final renamedFile = await source.rename(destinationPath);
    try {
      await _moveDocumentMetadata(preferences, document.path, renamedFile.path);
      if (document.isReferenced) {
        await _updateReferencedPath(
          preferences,
          document.path,
          renamedFile.path,
        );
        await _moveReferencedSourceUri(
          preferences,
          document.path,
          renamedFile.path,
        );
      }
    } catch (error, stackTrace) {
      try {
        await renamedFile.rename(source.path);
        if (document.isReferenced) {
          await _updateReferencedPath(
            preferences,
            renamedFile.path,
            source.path,
          );
          await _moveReferencedSourceUri(
            preferences,
            renamedFile.path,
            source.path,
          );
        }
        await _moveDocumentMetadata(preferences, renamedFile.path, source.path);
      } catch (rollbackError) {
        throw FileSystemException(
          '重命名失败，且自动回滚未完成：$rollbackError',
          document.path,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    invalidateLibraryCache();
    _lastRefreshTimes.remove(document.path);
    if (document.isReferenced) {
      _lastRefreshTimes[renamedFile.path] = DateTime.now();
    }
    return DocumentEntry.fromFile(
      renamedFile,
      recentOpenedAt: _recentOpenedAt(preferences, renamedFile.path),
      isReferenced: document.isReferenced,
      tags: _documentTags(preferences, renamedFile.path),
      pinned: _documentPinned(preferences, renamedFile.path),
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
      await _persistPreference(
        preferences.setStringList(_referencedPathsKey, paths),
      );
    }
  }

  @override
  Future<void> removeDocument(DocumentEntry document) async {
    final preferences = await _preferences();
    final referencedPaths = document.isReferenced
        ? preferences.getStringList(_referencedPathsKey) ?? []
        : null;
    final sourceUri = document.isReferenced
        ? preferences.getString(_referencedSourceUriKey(document.path))
        : null;
    final recentOpened = preferences.getInt(_recentOpenedKey(document.path));
    final pinned = preferences.getBool(_documentPinnedKey(document.path));
    final tags = preferences.getStringList(_documentTagsKey(document.path));
    final progress = await ReadingProgressService.loadProgress(document.path);
    final documentId = await DocumentIdentityService.getIdForPath(
      document.path,
    );
    final file = File(document.path);
    File? stagedFile;
    if ((!document.isReferenced || sourceUri != null) && file.existsSync()) {
      final stagedName =
          '${p.basenameWithoutExtension(file.path)}.deleting-'
          '${DateTime.now().microsecondsSinceEpoch}${p.extension(file.path)}';
      stagedFile = await file.rename(
        p.join(file.parent.path, stagedName),
      );
    }

    try {
      if (document.isReferenced) {
        final paths = List<String>.from(referencedPaths!);
        paths.remove(document.path);
        await _persistPreference(
          preferences.setStringList(_referencedPathsKey, paths),
        );
        await _persistPreference(
          preferences.remove(_referencedSourceUriKey(document.path)),
        );
      }
      await _clearDocumentMetadata(preferences, document.path);
      await DocumentIdentityService.removePath(document.path);
      if (stagedFile != null && stagedFile.existsSync()) {
        await stagedFile.delete();
      }
    } catch (error, stackTrace) {
      try {
        if (stagedFile != null &&
            stagedFile.existsSync() &&
            !file.existsSync()) {
          await stagedFile.rename(file.path);
        }
        if (referencedPaths != null) {
          await _persistPreference(
            preferences.setStringList(
              _referencedPathsKey,
              referencedPaths,
            ),
          );
          if (sourceUri != null) {
            await _persistPreference(
              preferences.setString(
                _referencedSourceUriKey(document.path),
                sourceUri,
              ),
            );
          }
        }
        await _restoreDocumentMetadata(
          preferences,
          document.path,
          recentOpened: recentOpened,
          pinned: pinned,
          tags: tags,
          progress: progress,
        );
        if (documentId != null) {
          await DocumentIdentityService.restorePath(document.path, documentId);
        }
      } catch (rollbackError) {
        throw FileSystemException(
          '移出失败，且自动回滚未完成：$rollbackError',
          document.path,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    invalidateLibraryCache();
    _lastRefreshTimes.remove(document.path);
  }

  @override
  Future<DocumentEntry> setDocumentPinned(
    DocumentEntry document,
    bool pinned,
  ) async {
    final preferences = await _preferences();
    if (pinned) {
      await _persistPreference(
        preferences.setBool(_documentPinnedKey(document.path), true),
      );
    } else {
      await _persistPreference(
        preferences.remove(_documentPinnedKey(document.path)),
      );
    }
    invalidateLibraryCache();
    return document.copyWith(pinned: pinned);
  }

  @override
  Future<DateTime> markDocumentOpened(DocumentEntry document) async {
    final preferences = await _preferences();
    final openedAt = DateTime.now();
    await _persistPreference(
      preferences.setInt(
        _recentOpenedKey(document.path),
        openedAt.millisecondsSinceEpoch,
      ),
    );
    invalidateLibraryCache();
    return openedAt;
  }

  @override
  Future<List<String>> loadTags() async {
    final preferences = await _preferences();
    return _allTags(preferences);
  }

  @override
  Future<List<String>> loadPinnedTags() async {
    final preferences = await _preferences();
    return _cleanTags(preferences.getStringList(_pinnedTagsKey) ?? []);
  }

  @override
  Future<void> createTag(String name) async {
    final tag = _validateTagName(name);
    final preferences = await _preferences();
    final tags = _allTags(preferences);
    if (!tags.contains(tag)) {
      tags.add(tag);
      tags.sort();
      await _persistPreference(preferences.setStringList(_tagsKey, tags));
    }
    invalidateLibraryCache();
  }

  @override
  Future<void> deleteTag(String name) async {
    final tag = _validateTagName(name);
    final preferences = await _preferences();
    final tags = _allTags(preferences)..remove(tag);
    await _persistPreference(preferences.setStringList(_tagsKey, tags));
    final pinnedTags = _cleanTags(
      preferences.getStringList(_pinnedTagsKey) ?? [],
    )..remove(tag);
    await _persistPreference(
      preferences.setStringList(_pinnedTagsKey, pinnedTags),
    );

    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_documentTagsPrefix)) {
        continue;
      }
      final documentTags = preferences.getStringList(key) ?? [];
      if (documentTags.remove(tag)) {
        await _persistPreference(
          preferences.setStringList(key, documentTags),
        );
      }
    }
    invalidateLibraryCache();
  }

  @override
  Future<void> setTagPinned(String name, bool pinned) async {
    final tag = _validateTagName(name);
    final preferences = await _preferences();
    final pinnedTags = _cleanTags(
      preferences.getStringList(_pinnedTagsKey) ?? [],
    );
    if (pinned && !pinnedTags.contains(tag)) {
      pinnedTags.add(tag);
    } else if (!pinned) {
      pinnedTags.remove(tag);
    }
    pinnedTags.sort();
    await _persistPreference(
      preferences.setStringList(_pinnedTagsKey, pinnedTags),
    );
    invalidateLibraryCache();
  }

  @override
  Future<DocumentTagUpdate> updateDocumentTags(
    DocumentEntry document,
    List<String> tags,
  ) async {
    final preferences = await _preferences();
    final cleanTags = _cleanTags(tags);
    final allTags = _allTags(preferences);
    for (final tag in cleanTags) {
      if (!allTags.contains(tag)) {
        allTags.add(tag);
      }
    }
    allTags.sort();
    await _persistPreference(preferences.setStringList(_tagsKey, allTags));
    await _persistPreference(
      preferences.setStringList(_documentTagsKey(document.path), cleanTags),
    );
    invalidateLibraryCache();
    return DocumentTagUpdate(documentTags: cleanTags, allTags: allTags);
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

  static String _documentPinnedKey(String path) {
    return '$_documentPinnedPrefix$path';
  }

  static String _referencedSourceUriKey(String path) {
    return '$_referencedSourceUriPrefix$path';
  }

  static String _documentTagsKey(String path) {
    return '$_documentTagsPrefix$path';
  }

  static List<String> _allTags(SharedPreferences preferences) {
    final tags = preferences.getStringList(_tagsKey) ?? [];
    return _cleanTags(tags);
  }

  static List<String> _documentTags(SharedPreferences preferences, String path) {
    final tags = preferences.getStringList(_documentTagsKey(path)) ?? [];
    return _cleanTags(tags);
  }

  static bool _documentPinned(SharedPreferences preferences, String path) {
    return preferences.getBool(_documentPinnedKey(path)) ?? false;
  }

  static List<String> _cleanTags(List<String> tags) {
    final unique = <String>{};
    for (final tag in tags) {
      final cleanTag = tag.trim();
      if (cleanTag.isNotEmpty) {
        unique.add(cleanTag);
      }
    }
    final sorted = unique.toList()..sort();
    return sorted;
  }

  static String _validateTagName(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FileSystemException('标签名称不能为空');
    }
    if (cleanName.length > 16) {
      throw const FileSystemException('标签名称不能超过 16 个字');
    }
    return cleanName;
  }

  static Future<void> _persistPreference(Future<bool> write) async {
    if (!await write) {
      throw const FileSystemException('无法保存文档库状态');
    }
  }

  static Future<void> _clearDocumentMetadata(
    SharedPreferences preferences,
    String path,
  ) async {
    await _persistPreference(preferences.remove(_recentOpenedKey(path)));
    await _persistPreference(preferences.remove(_documentPinnedKey(path)));
    await _persistPreference(preferences.remove(_documentTagsKey(path)));
    await ReadingProgressService.removeProgress(path);
  }

  static Future<void> _restoreDocumentMetadata(
    SharedPreferences preferences,
    String path, {
    required int? recentOpened,
    required bool? pinned,
    required List<String>? tags,
    required double? progress,
  }) async {
    if (recentOpened != null) {
      await _persistPreference(
        preferences.setInt(_recentOpenedKey(path), recentOpened),
      );
    }
    if (pinned != null) {
      await _persistPreference(
        preferences.setBool(_documentPinnedKey(path), pinned),
      );
    }
    if (tags != null) {
      await _persistPreference(
        preferences.setStringList(_documentTagsKey(path), tags),
      );
    }
    if (progress != null) {
      await ReadingProgressService.saveProgress(path, progress);
    }
  }

  static Future<void> _moveDocumentMetadata(
    SharedPreferences preferences,
    String oldPath,
    String newPath,
  ) async {
    final recentOpened = preferences.getInt(_recentOpenedKey(oldPath));
    final pinned = preferences.getBool(_documentPinnedKey(oldPath));
    final tags = preferences.getStringList(_documentTagsKey(oldPath));
    if (recentOpened != null) {
      await _persistPreference(
        preferences.setInt(_recentOpenedKey(newPath), recentOpened),
      );
    }
    if (pinned == true) {
      await _persistPreference(
        preferences.setBool(_documentPinnedKey(newPath), true),
      );
    }
    if (tags != null) {
      await _persistPreference(
        preferences.setStringList(_documentTagsKey(newPath), tags),
      );
    }
    await ReadingProgressService.moveProgress(oldPath, newPath);
    await DocumentIdentityService.movePath(oldPath, newPath);
    await _persistPreference(preferences.remove(_recentOpenedKey(oldPath)));
    await _persistPreference(preferences.remove(_documentPinnedKey(oldPath)));
    await _persistPreference(preferences.remove(_documentTagsKey(oldPath)));
  }

  static Future<void> _moveReferencedSourceUri(
    SharedPreferences preferences,
    String oldPath,
    String newPath,
  ) async {
    final sourceUri = preferences.getString(_referencedSourceUriKey(oldPath));
    if (sourceUri != null) {
      await _persistPreference(
        preferences.setString(_referencedSourceUriKey(newPath), sourceUri),
      );
    }
    await _persistPreference(
      preferences.remove(_referencedSourceUriKey(oldPath)),
    );
  }

  Future<List<DocumentEntry>> _pickAndroidReferencedDocuments() async {
    final picked = await _documentAccessChannel.invokeListMethod<Object?>(
      'pickDocuments',
    );
    if (picked == null || picked.isEmpty) {
      return const [];
    }

    final preferences = await _preferences();
    final documents = <DocumentEntry>[];
    for (final item in picked) {
      final metadata = item is Map ? item : const <String, Object?>{};
      final path = metadata['path'] as String?;
      final sourceUri = metadata['uri'] as String?;
      if (path == null ||
          path.isEmpty ||
          sourceUri == null ||
          sourceUri.isEmpty) {
        throw const FileSystemException('系统文件选择器没有返回可读取的路径');
      }
      if (!DocumentFileRules.isSupportedPath(path)) {
        final pickedFile = File(path);
        if (pickedFile.existsSync()) {
          await pickedFile.delete();
        }
        throw FileSystemException('仅支持 Markdown 和 HTML 文档', path);
      }

      await _rememberReferencedDocument(
        preferences: preferences,
        path: path,
        sourceUri: sourceUri,
      );
      documents.add(
        await DocumentEntry.fromFile(
          File(path),
          isReferenced: true,
          tags: _documentTags(preferences, path),
          pinned: _documentPinned(preferences, path),
        ),
      );
    }
    return documents;
  }

  Future<DocumentFolderImportResult> _pickAndroidReferencedFolderDocuments() async {
    final result = await _documentAccessChannel.invokeMethod<Object?>(
      'pickFolderDocuments',
    );
    if (result == null) {
      return const DocumentFolderImportResult(
        documents: [],
        skipped: 0,
        failed: 0,
      );
    }
    final data = result is Map ? result : const <String, Object?>{};
    final rawItems = data['documents'];
    final items = rawItems is List ? rawItems : const <Object?>[];
    final preferences = await _preferences();
    final documents = <DocumentEntry>[];
    var failed = (data['failed'] as int?) ?? 0;
    for (final item in items) {
      try {
        final metadata = item is Map ? item : const <String, Object?>{};
        final path = metadata['path'] as String?;
        final sourceUri = metadata['uri'] as String?;
        if (path == null ||
            path.isEmpty ||
            sourceUri == null ||
            sourceUri.isEmpty) {
          failed++;
          continue;
        }
        await _rememberReferencedDocument(
          preferences: preferences,
          path: path,
          sourceUri: sourceUri,
        );
        documents.add(
          await DocumentEntry.fromFile(
            File(path),
            isReferenced: true,
            tags: _documentTags(preferences, path),
            pinned: _documentPinned(preferences, path),
          ),
        );
      } catch (error) {
        failed++;
        debugPrint('[DocumentFileService] import folder metadata failed: $error');
      }
    }
    return DocumentFolderImportResult(
      documents: documents,
      skipped: (data['skipped'] as int?) ?? 0,
      failed: failed,
    );
  }

  Future<DocumentEntry> _importAndroidExternalUri(Uri uri) async {
    final imported = await _documentAccessChannel
        .invokeMapMethod<String, Object?>(
      'importExternalUri',
      {'uri': uri.toString()},
    );
    if (imported == null) {
      throw FileSystemException('系统没有传入可读取的文件路径', uri.toString());
    }

    final path = imported['path'] as String?;
    final sourceUri = imported['uri'] as String?;
    if (path == null || path.isEmpty || sourceUri == null || sourceUri.isEmpty) {
      throw FileSystemException('系统没有传入可读取的文件路径', uri.toString());
    }
    if (!DocumentFileRules.isSupportedPath(path)) {
      final importedFile = File(path);
      if (importedFile.existsSync()) {
        await importedFile.delete();
      }
      throw FileSystemException('仅支持 Markdown 和 HTML 文档', path);
    }

    final preferences = await _preferences();
    await _rememberReferencedDocument(
      preferences: preferences,
      path: path,
      sourceUri: sourceUri,
    );
    return DocumentEntry.fromFile(
      File(path),
      isReferenced: true,
      tags: _documentTags(preferences, path),
      pinned: _documentPinned(preferences, path),
    );
  }

  static Future<void> _rememberReferencedDocument({
    required SharedPreferences preferences,
    required String path,
    required String sourceUri,
  }) async {
    final paths = preferences.getStringList(_referencedPathsKey) ?? [];
    final previousPath = paths.cast<String?>().firstWhere(
          (candidate) =>
              candidate != null &&
              candidate != path &&
              preferences.getString(_referencedSourceUriKey(candidate)) ==
                  sourceUri,
          orElse: () => null,
        );
    await _persistPreference(
      preferences.setString(_referencedSourceUriKey(path), sourceUri),
    );
    if (previousPath != null) {
      await _moveDocumentMetadata(preferences, previousPath, path);
      paths.remove(previousPath);
    }
    if (!paths.contains(path)) {
      paths.add(path);
    }
    if (previousPath != null ||
        !(preferences.getStringList(_referencedPathsKey) ?? []).contains(path)) {
      await _persistPreference(
        preferences.setStringList(_referencedPathsKey, paths),
      );
    }
    await DocumentIdentityService.getOrCreateId(
      path: path,
      sourceUri: sourceUri,
    );
    if (previousPath != null) {
      await _persistPreference(
        preferences.remove(_referencedSourceUriKey(previousPath)),
      );
      if (Platform.isAndroid) {
        final previousFile = File(previousPath);
        if (previousFile.existsSync()) {
          try {
            await previousFile.delete();
          } catch (error) {
            debugPrint(
              '[DocumentFileService] remove old referenced mirror failed: $error',
            );
          }
        }
      }
    }
  }

  Future<String?> _refreshReferencedMirror(
    SharedPreferences preferences,
    String path,
  ) async {
    // Rate-limit: skip if refreshed within the last 5 minutes.
    final lastRefresh = _lastRefreshTimes[path];
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _cacheMaxAge) {
      return null;
    }

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
      _lastRefreshTimes[path] = DateTime.now();
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

  Future<String?> _migratePrefixedReferencedMirror(
    SharedPreferences preferences,
    String path,
  ) async {
    final sourceUri = preferences.getString(_referencedSourceUriKey(path));
    if (sourceUri == null || sourceUri.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final match = _prefixedMirrorNamePattern.firstMatch(p.basename(path));
    final restoredName = match?.group(1);
    if (restoredName == null ||
        restoredName.isEmpty ||
        !DocumentFileRules.isSupportedPath(restoredName)) {
      return null;
    }

    File? migratedFile;
    try {
      final parent = file.parent;
      final destinationDirectory = Directory(
        p.join(parent.path, DateTime.now().microsecondsSinceEpoch.toString()),
      );
      await destinationDirectory.create(recursive: true);
      final destinationPath = p.join(destinationDirectory.path, restoredName);
      migratedFile = await file.rename(destinationPath);
      await _moveDocumentMetadata(preferences, path, migratedFile.path);
      await _moveReferencedSourceUri(preferences, path, migratedFile.path);
      return migratedFile.path;
    } catch (error) {
      debugPrint(
        '[DocumentFileService] migrate referenced mirror name failed: $error',
      );
      if (migratedFile != null &&
          migratedFile.existsSync() &&
          !file.existsSync()) {
        try {
          await migratedFile.rename(file.path);
          await _moveDocumentMetadata(
            preferences,
            migratedFile.path,
            file.path,
          );
          await _moveReferencedSourceUri(
            preferences,
            migratedFile.path,
            file.path,
          );
        } catch (rollbackError) {
          debugPrint(
            '[DocumentFileService] rollback mirror migration failed: '
            '$rollbackError',
          );
        }
      }
      if (!file.existsSync() && migratedFile?.existsSync() == true) {
        return migratedFile!.path;
      }
      return null;
    }
  }
}
