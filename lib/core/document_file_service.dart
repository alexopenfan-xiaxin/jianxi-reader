import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/metadata/library_schema.dart';
import '../data/metadata/metadata_store.dart';
import '../features/library/document_entry.dart';
import 'document_identity.dart';
import 'document_removal.dart';
import 'file_rules.dart';
import 'bookmark_service.dart';
import 'reading_history_service.dart';
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

  /// Removes [document] from the library and returns an undo receipt.
  Future<DocumentRemoval> removeDocument(DocumentEntry document);

  /// Puts a document removed by [removeDocument] back.
  Future<void> restoreDocument(DocumentRemoval removal);

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
  const DocumentTagUpdate({required this.documentTags, required this.allTags});

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
  static const _documentAccessChannel = MethodChannel(
    'com.jianxi.reader/document_access',
  );
  static const _referencedPathsKey = 'referenced.paths';
  static const _referencedSourceUriPrefix = 'referenced.sourceUri.';
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
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
    final entries = <DocumentEntry>[];
    final preferences = await _preferences();

    final directory = await ensureLibraryDirectory();
    final files = await directory
        .list(followLinks: false)
        .where(DocumentFileRules.isSupportedFile)
        .cast<File>()
        .toList();

    for (final file in files) {
      try {
        entries.add(
          await DocumentEntry.fromFile(
            file,
            recentOpenedAt: _recentOpenedAt(file.path),
            tags: _documentTags(file.path),
            pinned: _documentPinned(file.path),
          ),
        );
      } catch (error) {
        debugPrint('[DocumentFileService] scan file failed: $error');
      }
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
      try {
        entries.add(
          await DocumentEntry.fromFile(
            file,
            recentOpenedAt: _recentOpenedAt(refreshedPath),
            isReferenced: true,
            sourceUri: preferences.getString(
              _referencedSourceUriKey(refreshedPath),
            ),
            tags: _documentTags(refreshedPath),
            pinned: _documentPinned(refreshedPath),
          ),
        );
      } catch (error) {
        debugPrint('[DocumentFileService] scan referenced file failed: $error');
      }
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
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
    if (_cachedEntries != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheMaxAge) {
      return _cachedEntries!;
    }
    // Returning an empty cache miss lets the controller decide when to do the
    // one full scan, instead of scanning twice in the initial/refresh path.
    return const [];
  }

  @override
  void invalidateLibraryCache() {
    _cachedEntries = null;
    _cacheTimestamp = null;
  }

  @override
  Future<List<DocumentEntry>> pickAndImportDocuments() async {
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
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
    Object? firstError;
    var pathsChanged = false;
    for (final pickedFile in result.files) {
      try {
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
          pathsChanged = true;
        }
        imported.add(
          await DocumentEntry.fromFile(
            source,
            isReferenced: true,
            sourceUri: source.uri.toString(),
            tags: _documentTags(sourcePath),
            pinned: _documentPinned(sourcePath),
          ),
        );
      } catch (error) {
        firstError ??= error;
        debugPrint('[DocumentFileService] pick import failed: $error');
      }
    }
    if (imported.isEmpty && firstError != null) {
      throw firstError;
    }
    if (pathsChanged) {
      await _persistPreference(
        preferences.setStringList(_referencedPathsKey, paths),
      );
    }

    return imported;
  }

  @override
  Future<DocumentFolderImportResult> pickAndImportFolderDocuments() async {
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
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
    await for (final entity in Directory(
      folderPath,
    ).list(recursive: true, followLinks: false)) {
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
            sourceUri: entity.uri.toString(),
            tags: _documentTags(entity.path),
            pinned: _documentPinned(entity.path),
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
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
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
      sourceUri: uri.toString(),
      tags: _documentTags(sourcePath),
      pinned: _documentPinned(sourcePath),
    );
  }

  @override
  Future<DocumentEntry> refreshDocument(DocumentEntry document) async {
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
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
      recentOpenedAt: _recentOpenedAt(path),
      isReferenced: document.isReferenced,
      sourceUri:
          document.sourceUri ??
          preferences.getString(_referencedSourceUriKey(path)),
      tags: _documentTags(path),
      pinned: _documentPinned(path),
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
    // Read helpers below are synchronous; make sure the metadata cache is warm.
    await MetadataStore.load();
    var cleanBaseName = DocumentFileRules.validateBaseName(baseName);
    final source = File(document.path);
    final sourceExtension = p.extension(document.path);
    if (sourceExtension.isNotEmpty &&
        cleanBaseName.toLowerCase().endsWith(sourceExtension.toLowerCase())) {
      cleanBaseName = cleanBaseName
          .substring(0, cleanBaseName.length - sourceExtension.length)
          .trim();
      if (cleanBaseName.isEmpty) {
        throw const FileSystemException('文件名不能为空');
      }
    }
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
      await _moveDocumentMetadata(document.path, renamedFile.path);
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
        await _moveDocumentMetadata(renamedFile.path, source.path);
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
      recentOpenedAt: _recentOpenedAt(renamedFile.path),
      isReferenced: document.isReferenced,
      sourceUri: document.sourceUri,
      tags: _documentTags(renamedFile.path),
      pinned: _documentPinned(renamedFile.path),
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
  Future<DocumentRemoval> removeDocument(DocumentEntry document) async {
    final preferences = await _preferences();
    final referencedPaths = document.isReferenced
        ? preferences.getStringList(_referencedPathsKey) ?? []
        : null;
    final sourceUri = document.isReferenced
        ? preferences.getString(_referencedSourceUriKey(document.path))
        : null;
    final captured = (await MetadataStore.load()).recordForPath(document.path);
    final recentOpened = captured?.recentOpenedAtMillis;
    final pinned = captured?.pinned;
    final tags = captured == null ? null : List<String>.of(captured.tags);
    final progress = await ReadingProgressService.loadProgress(document.path);
    final documentId = await DocumentIdentityService.getIdForPath(
      document.path,
    );
    // Capture what is about to be deleted so "撤销" can put it back.
    final bookmarks = documentId == null
        ? const <ReadingBookmark>[]
        : await BookmarkService.forDocument(documentId);
    final history = documentId == null
        ? const <ReadingHistoryEvent>[]
        : (await ReadingHistoryService.loadAll())
              .where((event) => event.documentId == documentId)
              .toList();
    final file = File(document.path);
    // Only ever delete a copy this app owns. A referenced document's on-disk
    // path is the Android mirror; on any other platform it is the user's own
    // file, so the metadata is removed and the file is left untouched.
    final isManagedCopy = document.isReferenced
        ? (sourceUri != null && Platform.isAndroid)
        : true;
    File? stagedFile;
    if (isManagedCopy && file.existsSync()) {
      // Park it in .trash instead of deleting: the undo window is the only
      // thing standing between a mis-tap and a lost document.
      stagedFile = await DocumentTrash.stage(file);
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
      await _clearDocumentMetadata(document.path);
      await DocumentIdentityService.removePath(document.path);
      if (documentId != null) {
        try {
          await BookmarkService.removeForDocument(documentId);
          await ReadingHistoryService.removeForDocument(documentId);
        } catch (error) {
          debugPrint(
            '[DocumentFileService] remove bookmark/history failed: $error',
          );
        }
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
            preferences.setStringList(_referencedPathsKey, referencedPaths),
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
          document.path,
          documentId: documentId,
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

    return DocumentRemoval(
      document: document,
      removedAtMillis: DateTime.now().millisecondsSinceEpoch,
      documentId: documentId,
      trashedPath: stagedFile?.path,
      recentOpenedAtMillis: recentOpened,
      pinned: pinned,
      tags: tags ?? const [],
      progress: progress,
      referencedPaths: referencedPaths,
      sourceUri: sourceUri,
      bookmarks: bookmarks,
      history: history,
    );
  }

  /// Puts a removed document back, including its file, tags, bookmarks and
  /// reading state. Best effort: a missing parked file still restores metadata.
  @override
  Future<void> restoreDocument(DocumentRemoval removal) async {
    final preferences = await _preferences();
    final path = removal.document.path;

    final trashedPath = removal.trashedPath;
    if (trashedPath != null) {
      final parked = File(trashedPath);
      if (await parked.exists()) {
        final target = File(path);
        await target.parent.create(recursive: true);
        await parked.rename(path);
      }
      await _discardEmptyTrashFolder(trashedPath);
    }

    if (removal.referencedPaths != null) {
      final paths = List<String>.from(
        preferences.getStringList(_referencedPathsKey) ?? const <String>[],
      );
      if (!paths.contains(path)) {
        paths.add(path);
      }
      await _persistPreference(
        preferences.setStringList(_referencedPathsKey, paths),
      );
      final sourceUri = removal.sourceUri;
      if (sourceUri != null) {
        await _persistPreference(
          preferences.setString(_referencedSourceUriKey(path), sourceUri),
        );
      }
    }

    await _restoreDocumentMetadata(
      path,
      documentId: removal.documentId,
      recentOpened: removal.recentOpenedAtMillis,
      pinned: removal.pinned,
      tags: removal.tags,
      progress: removal.progress,
    );

    final documentId = removal.documentId;
    if (documentId != null) {
      await DocumentIdentityService.restorePath(path, documentId);
      await BookmarkService.restoreAll(removal.bookmarks);
      await ReadingHistoryService.restoreAll(removal.history);
    }

    invalidateLibraryCache();
    _lastRefreshTimes.remove(path);
  }

  static Future<void> _discardEmptyTrashFolder(String trashedPath) async {
    final folder = Directory(p.dirname(trashedPath));
    if (p.basename(folder.path) == DocumentTrash.directoryName) {
      return;
    }
    if (p.basename(folder.parent.path) != DocumentTrash.directoryName) {
      return;
    }
    try {
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('[DocumentFileService] cannot clean trash folder: $error');
    }
  }

  /// Drops parked files older than 24 hours. Called once at startup.
  static Future<int> purgeExpiredTrash() async {
    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final libraryDirectory = Directory(
        p.join(appDirectory.path, libraryFolderName),
      );
      return await DocumentTrash.purge(libraryDirectory);
    } catch (error) {
      debugPrint('[DocumentFileService] trash purge skipped: $error');
      return 0;
    }
  }

  @override
  Future<DocumentEntry> setDocumentPinned(
    DocumentEntry document,
    bool pinned,
  ) async {
    final id = await _idFor(document);
    await MetadataStore.transaction((snapshot) async {
      final record = snapshot.ensureRecord(
        document.path,
        id: id,
        sourceUri: document.sourceUri,
      );
      snapshot.upsertRecord(record.copyWith(pinned: pinned));
    });
    invalidateLibraryCache();
    return document.copyWith(pinned: pinned);
  }

  @override
  Future<DateTime> markDocumentOpened(DocumentEntry document) async {
    final openedAt = DateTime.now();
    final id = await _idFor(document);
    await MetadataStore.transaction((snapshot) async {
      final record = snapshot.ensureRecord(
        document.path,
        id: id,
        sourceUri: document.sourceUri,
      );
      snapshot.upsertRecord(
        record.copyWith(recentOpenedAtMillis: openedAt.millisecondsSinceEpoch),
      );
    });
    invalidateLibraryCache();
    return openedAt;
  }

  @override
  Future<List<String>> loadTags() async {
    final snapshot = await MetadataStore.load();
    return _cleanTags(snapshot.tags);
  }

  @override
  Future<List<String>> loadPinnedTags() async {
    final snapshot = await MetadataStore.load();
    return _cleanTags(snapshot.pinnedTags);
  }

  @override
  Future<void> createTag(String name) async {
    final tag = _validateTagName(name);
    await MetadataStore.transaction((snapshot) async {
      if (!snapshot.tags.contains(tag)) {
        snapshot.tags
          ..add(tag)
          ..sort();
      }
    });
    invalidateLibraryCache();
  }

  @override
  Future<void> deleteTag(String name) async {
    final tag = _validateTagName(name);
    await MetadataStore.transaction((snapshot) async {
      snapshot.tags.remove(tag);
      snapshot.pinnedTags.remove(tag);
      for (final record in List<DocumentRecord>.of(snapshot.documents)) {
        if (!record.tags.contains(tag)) continue;
        snapshot.upsertRecord(
          record.copyWith(
            tags: record.tags.where((existing) => existing != tag).toList(),
          ),
        );
      }
    });
    invalidateLibraryCache();
  }

  @override
  Future<void> setTagPinned(String name, bool pinned) async {
    final tag = _validateTagName(name);
    await MetadataStore.transaction((snapshot) async {
      snapshot.pinnedTags.remove(tag);
      if (pinned) {
        snapshot.pinnedTags
          ..add(tag)
          ..sort();
      }
    });
    invalidateLibraryCache();
  }

  @override
  Future<DocumentTagUpdate> updateDocumentTags(
    DocumentEntry document,
    List<String> tags,
  ) async {
    final cleanTags = _cleanTags(tags).map(_validateTagName).toList();
    final id = await _idFor(document);
    final allTags = await MetadataStore.transaction((snapshot) async {
      final record = snapshot.ensureRecord(
        document.path,
        id: id,
        sourceUri: document.sourceUri,
      );
      snapshot.upsertRecord(record.copyWith(tags: cleanTags));
      snapshot.registerTags(cleanTags);
      return List<String>.of(snapshot.tags);
    });
    invalidateLibraryCache();
    return DocumentTagUpdate(documentTags: cleanTags, allTags: allTags);
  }

  /// The stable id for [document], creating the record when needed.
  static Future<String> _idFor(DocumentEntry document) {
    return DocumentIdentityService.getOrCreateId(
      path: document.path,
      sourceUri: document.sourceUri,
    );
  }

  /// Read helpers below run inside scan/import loops, so they read the cached
  /// snapshot synchronously. Every entry point awaits `MetadataStore.load()`
  /// first, which makes the cache authoritative.

  static DateTime? _recentOpenedAt(String path) {
    final milliseconds = MetadataStore.cachedSnapshot
        ?.recordForPath(path)
        ?.recentOpenedAtMillis;
    if (milliseconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  static String _referencedSourceUriKey(String path) {
    return '$_referencedSourceUriPrefix$path';
  }

  static List<String> _documentTags(String path) {
    final tags =
        MetadataStore.cachedSnapshot?.recordForPath(path)?.tags ?? const [];
    return _cleanTags(tags);
  }

  static bool _documentPinned(String path) {
    return MetadataStore.cachedSnapshot?.recordForPath(path)?.pinned ?? false;
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

  static Future<void> _clearDocumentMetadata(String path) async {
    await MetadataStore.transaction((snapshot) async {
      snapshot.removeRecordForPath(path);
    });
    await ReadingProgressService.clearProgress(path);
  }

  static Future<void> _restoreDocumentMetadata(
    String path, {
    required String? documentId,
    required int? recentOpened,
    required bool? pinned,
    required List<String>? tags,
    required double? progress,
  }) async {
    final id =
        documentId ??
        await DocumentIdentityService.getIdForPath(path) ??
        'doc_${DateTime.now().microsecondsSinceEpoch}';
    await MetadataStore.transaction((snapshot) async {
      final existing = snapshot.recordForPath(path);
      final record = existing ?? DocumentRecord(id: id, path: path);
      snapshot.upsertRecord(
        record.copyWith(
          pinned: pinned ?? record.pinned,
          tags: tags ?? record.tags,
          recentOpenedAtMillis: recentOpened,
          clearRecentOpenedAt: recentOpened == null,
        ),
      );
    });
    if (progress != null) {
      await ReadingProgressService.saveProgress(path, progress);
    }
  }

  static Future<void> _moveDocumentMetadata(
    String oldPath,
    String newPath,
  ) async {
    await MetadataStore.transaction((snapshot) async {
      final record = snapshot.recordForPath(oldPath);
      if (record == null) return;
      snapshot.removeRecordForPath(oldPath);
      snapshot.upsertRecord(record.copyWith(path: newPath));
    });
    await ReadingProgressService.moveProgress(oldPath, newPath);
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
    Object? firstError;
    for (final item in picked) {
      try {
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
            sourceUri: sourceUri,
            tags: _documentTags(path),
            pinned: _documentPinned(path),
          ),
        );
      } catch (error) {
        firstError ??= error;
        debugPrint('[DocumentFileService] Android pick import failed: $error');
      }
    }
    if (documents.isEmpty && firstError != null) {
      throw firstError;
    }
    return documents;
  }

  Future<DocumentFolderImportResult>
  _pickAndroidReferencedFolderDocuments() async {
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
            tags: _documentTags(path),
            pinned: _documentPinned(path),
          ),
        );
      } catch (error) {
        failed++;
        debugPrint(
          '[DocumentFileService] import folder metadata failed: $error',
        );
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
        .invokeMapMethod<String, Object?>('importExternalUri', {
          'uri': uri.toString(),
        });
    if (imported == null) {
      throw FileSystemException('系统没有传入可读取的文件路径', uri.toString());
    }

    final path = imported['path'] as String?;
    final sourceUri = imported['uri'] as String?;
    if (path == null ||
        path.isEmpty ||
        sourceUri == null ||
        sourceUri.isEmpty) {
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
      sourceUri: sourceUri,
      tags: _documentTags(path),
      pinned: _documentPinned(path),
    );
  }

  static Future<void> _rememberReferencedDocument({
    required SharedPreferences preferences,
    required String path,
    required String sourceUri,
  }) async {
    final originalPaths = preferences.getStringList(_referencedPathsKey) ?? [];
    final previousSourceUri = preferences.getString(
      _referencedSourceUriKey(path),
    );
    final paths = List<String>.from(originalPaths);
    final previousPath = paths.cast<String?>().firstWhere(
      (candidate) =>
          candidate != null &&
          candidate != path &&
          preferences.getString(_referencedSourceUriKey(candidate)) ==
              sourceUri,
      orElse: () => null,
    );
    try {
      await _persistPreference(
        preferences.setString(_referencedSourceUriKey(path), sourceUri),
      );
      if (previousPath != null) {
        await _moveDocumentMetadata(previousPath, path);
        paths.remove(previousPath);
      }
      if (!paths.contains(path)) {
        paths.add(path);
      }
      if (previousPath != null ||
          !(preferences.getStringList(_referencedPathsKey) ?? []).contains(
            path,
          )) {
        await _persistPreference(
          preferences.setStringList(_referencedPathsKey, paths),
        );
      }
      await DocumentIdentityService.getOrCreateId(
        path: path,
        sourceUri: sourceUri,
      );
    } catch (error, stackTrace) {
      // Best-effort rollback of the preference pointers. File/metadata
      // movement is idempotent enough to retry on the next import.
      try {
        if (previousSourceUri == null) {
          await preferences.remove(_referencedSourceUriKey(path));
        } else {
          await preferences.setString(
            _referencedSourceUriKey(path),
            previousSourceUri,
          );
        }
        await preferences.setStringList(_referencedPathsKey, originalPaths);
      } catch (rollbackError) {
        debugPrint(
          '[DocumentFileService] referenced metadata rollback failed: '
          '$rollbackError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
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
          .invokeMapMethod<String, Object?>('refreshDocument', {
            'uri': sourceUri,
            'path': path,
          });
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
      await _moveDocumentMetadata(path, migratedFile.path);
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
          await _moveDocumentMetadata(migratedFile.path, file.path);
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
