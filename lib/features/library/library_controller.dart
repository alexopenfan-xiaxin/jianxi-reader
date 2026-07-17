import 'package:flutter/foundation.dart';

import '../../core/document_error_describer.dart';
import '../../core/document_file_service.dart';
import '../../core/reading_progress_service.dart';
import 'document_entry.dart';

enum LibrarySortMode {
  modifiedNewest('最近修改'),
  recentlyOpened('最近阅读'),
  name('文件名'),
  sizeLargest('文件大小'),
  type('文件类型'),
  tagCount('标签数量'),
  pinnedFirst('置顶优先');

  const LibrarySortMode(this.label);

  final String label;
}

class LibraryBatchResult {
  const LibraryBatchResult({required this.success, required this.failure});

  final int success;
  final int failure;

  bool get hasFailure => failure > 0;
}

class LibraryController extends ChangeNotifier {
  LibraryController({required this.documentService});

  final DocumentLibraryService documentService;

  List<DocumentEntry> _allDocuments = const [];
  bool _isLoading = false;
  bool _isImporting = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedTag;
  LibrarySortMode _sortMode = LibrarySortMode.modifiedNewest;
  List<String> _tags = const [];
  List<String> _pinnedTags = const [];

  // Cached computed lists — invalidated on data change.
  List<DocumentEntry>? _cachedDocuments;
  List<DocumentEntry>? _cachedDocumentsIgnoringSearch;

  List<DocumentEntry> get documents {
    return _cachedDocuments ??= _computeDocuments(
      query: _searchQuery,
      tag: _selectedTag,
    );
  }

  List<DocumentEntry> get documentsIgnoringSearch {
    return _cachedDocumentsIgnoringSearch ??= _computeDocuments(
      query: '',
      tag: _selectedTag,
    );
  }

  List<DocumentEntry> _computeDocuments({
    required String query,
    required String? tag,
  }) {
    final q = query.trim().toLowerCase();
    final filtered = _allDocuments.where((document) {
      final matchesQuery = q.isEmpty || _matchesQuery(document, q);
      final matchesTag = tag == null || document.tags.contains(tag);
      return matchesQuery && matchesTag;
    }).toList();
    filtered.sort(_compareDocuments);
    return filtered;
  }

  void _invalidateCache() {
    _cachedDocuments = null;
    _cachedDocumentsIgnoringSearch = null;
  }

  List<DocumentEntry> get allDocuments => _allDocuments;

  bool get isLoading => _isLoading;

  bool get isImporting => _isImporting;

  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;

  String? get selectedTag => _selectedTag;

  LibrarySortMode get sortMode => _sortMode;

  List<String> get tags => _tags;

  List<String> get pinnedTags => _pinnedTags;

  List<DocumentEntry> get recentDocuments {
    final recent =
        _allDocuments
            .where((document) => document.recentOpenedAt != null)
            .toList()
          ..sort((left, right) {
            return right.recentOpenedAt!.compareTo(left.recentOpenedAt!);
          });
    return recent.take(5).toList();
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    _errorMessage = null;

    // Phase 1: show cached results immediately if available.
    try {
      final cached = await documentService.scanLibraryCached();
      if (cached.isNotEmpty) {
        _allDocuments = cached;
        await _loadTags();
        _invalidateCache();
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[LibraryController] cached scan failed: $error');
    }

    // Phase 2: full background refresh.
    try {
      _allDocuments = await documentService.scanLibrary();
      await _loadTags();
      _invalidateCache();
    } catch (error) {
      debugPrint('[LibraryController] load documents failed: $error');
      _errorMessage = '读取文档库失败：${describeDocumentError(error)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<DocumentEntry>> importExternalDocuments() async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final imported = await documentService.pickAndImportDocuments();
      _allDocuments = await documentService.scanLibrary();
      await _loadTags();
      _invalidateCache();
      return imported;
    } catch (error) {
      debugPrint(
        '[LibraryController] import external documents failed: $error',
      );
      _errorMessage = '导入外部文档失败：${describeDocumentError(error)}';
      return const [];
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<DocumentFolderImportResult> importExternalFolderDocuments() async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await documentService.pickAndImportFolderDocuments();
      _allDocuments = await documentService.scanLibrary();
      await _loadTags();
      _invalidateCache();
      return result;
    } catch (error) {
      debugPrint('[LibraryController] import folder documents failed: $error');
      _errorMessage = '导入文件夹失败：${describeDocumentError(error)}';
      return const DocumentFolderImportResult(
        documents: [],
        skipped: 0,
        failed: 0,
      );
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<DocumentEntry> importExternalUri(Uri uri) async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final imported = await documentService.importExternalUri(uri);
      await documentService.markDocumentOpened(imported);
      _allDocuments = await documentService.scanLibrary();
      await _loadTags();
      _invalidateCache();
      return imported;
    } catch (error) {
      debugPrint('[LibraryController] import external uri failed: $error');
      _errorMessage = '打开外部文档失败：${describeDocumentError(error)}';
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<DocumentEntry> renameDocument(
    DocumentEntry document,
    String baseName,
  ) async {
    final renamed = await documentService.renameDocument(document, baseName);
    _replaceDocument(document.path, renamed);
    _errorMessage = null;
    notifyListeners();
    return renamed;
  }

  Future<void> removeDocument(DocumentEntry document) async {
    await documentService.removeDocument(document);
    _removeDocument(document.path);
    _errorMessage = null;
    notifyListeners();
  }

  Future<LibraryBatchResult> removeDocuments(
    List<DocumentEntry> documents,
  ) async {
    var success = 0;
    var failure = 0;
    for (final document in documents) {
      try {
        await documentService.removeDocument(document);
        _removeDocument(document.path);
        success += 1;
      } catch (error) {
        debugPrint('[LibraryController] remove document failed: $error');
        failure += 1;
      }
    }
    _errorMessage = failure == 0 ? null : '部分文档移出失败：$failure 个';
    _invalidateCache();
    notifyListeners();
    return LibraryBatchResult(success: success, failure: failure);
  }

  Future<DocumentEntry> refreshDocument(DocumentEntry document) async {
    final refreshed = await documentService.refreshDocument(document);
    _replaceDocument(document.path, refreshed);
    _errorMessage = null;
    notifyListeners();
    return refreshed;
  }

  Future<LibraryBatchResult> refreshDocuments(
    List<DocumentEntry> documents,
  ) async {
    var success = 0;
    var failure = 0;
    for (final document in documents) {
      try {
        final refreshed = await documentService.refreshDocument(document);
        _replaceDocument(document.path, refreshed);
        success += 1;
      } catch (error) {
        debugPrint('[LibraryController] refresh document failed: $error');
        failure += 1;
      }
    }
    _errorMessage = failure == 0 ? null : '部分文档刷新失败：$failure 个';
    _invalidateCache();
    notifyListeners();
    return LibraryBatchResult(success: success, failure: failure);
  }

  Future<DocumentEntry> markDocumentOpened(DocumentEntry document) async {
    final openedAt = await documentService.markDocumentOpened(document);
    final opened = document.copyWith(recentOpenedAt: openedAt);
    _replaceDocument(document.path, opened);
    notifyListeners();
    return opened;
  }

  Future<void> createTag(String name) async {
    await documentService.createTag(name);
    await _loadTags();
    _errorMessage = null;
    _invalidateCache();
    notifyListeners();
  }

  Future<void> deleteTag(String name) async {
    await documentService.deleteTag(name);
    final tag = name.trim();
    _tags = _tags.where((item) => item != tag).toList();
    _pinnedTags = _pinnedTags.where((item) => item != tag).toList();
    if (_selectedTag == tag) {
      _selectedTag = null;
    }
    _allDocuments = _allDocuments.map((document) {
      if (!document.tags.contains(tag)) {
        return document;
      }
      return document.copyWith(
        tags: document.tags.where((item) => item != tag).toList(),
      );
    }).toList();
    _errorMessage = null;
    _invalidateCache();
    notifyListeners();
  }

  Future<void> updateDocumentTags(
    DocumentEntry document,
    List<String> tags,
  ) async {
    final update = await documentService.updateDocumentTags(document, tags);
    await _loadTags();
    _replaceDocument(
      document.path,
      document.copyWith(tags: update.documentTags),
    );
    _errorMessage = null;
    _invalidateCache();
    notifyListeners();
  }

  Future<void> updateDocumentsTags(
    List<DocumentEntry> documents,
    List<String> tags,
  ) async {
    for (final document in documents) {
      final update = await documentService.updateDocumentTags(document, tags);
      _replaceDocument(
        document.path,
        document.copyWith(tags: update.documentTags),
      );
    }
    await _loadTags();
    _errorMessage = null;
    _invalidateCache();
    notifyListeners();
  }

  Future<void> addDocumentsTags(
    List<DocumentEntry> documents,
    List<String> tags,
  ) async {
    final cleanTags = tags.map((tag) => tag.trim()).where((tag) {
      return tag.isNotEmpty;
    }).toSet();
    for (final document in documents) {
      final mergedTags = {...document.tags, ...cleanTags}.toList()..sort();
      final update = await documentService.updateDocumentTags(
        document,
        mergedTags,
      );
      _replaceDocument(
        document.path,
        document.copyWith(tags: update.documentTags),
      );
    }
    await _loadTags();
    _errorMessage = null;
    _invalidateCache();
    notifyListeners();
  }

  Future<void> setPinned(DocumentEntry document, bool pinned) async {
    final updated = await documentService.setDocumentPinned(document, pinned);
    _replaceDocument(document.path, updated);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> setTagPinned(String tag, bool pinned) async {
    await documentService.setTagPinned(tag, pinned);
    await _loadTags();
    _errorMessage = null;
    _invalidateCache();
    notifyListeners();
  }

  Future<LibraryBatchResult> clearDocumentsProgress(
    List<DocumentEntry> documents,
  ) async {
    var success = 0;
    var failure = 0;
    for (final document in documents) {
      try {
        await ReadingProgressService.removeProgress(document.path);
        success += 1;
      } catch (error) {
        debugPrint('[LibraryController] clear progress failed: $error');
        failure += 1;
      }
    }
    _errorMessage = failure == 0 ? null : '部分阅读进度清理失败：$failure 个';
    notifyListeners();
    return LibraryBatchResult(success: success, failure: failure);
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    _invalidateCache();
    notifyListeners();
  }

  void updateSelectedTag(String? tag) {
    if (_selectedTag == tag) {
      return;
    }
    _selectedTag = tag;
    _invalidateCache();
    notifyListeners();
  }

  void updateSortMode(LibrarySortMode sortMode) {
    if (_sortMode == sortMode) {
      return;
    }
    _sortMode = sortMode;
    _invalidateCache();
    notifyListeners();
  }

  int _compareDocuments(DocumentEntry left, DocumentEntry right) {
    final result = switch (_sortMode) {
      LibrarySortMode.modifiedNewest => right.modifiedAt.compareTo(
        left.modifiedAt,
      ),
      LibrarySortMode.recentlyOpened => _compareNullableDateDesc(
        left.recentOpenedAt,
        right.recentOpenedAt,
      ),
      LibrarySortMode.name => left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      ),
      LibrarySortMode.sizeLargest => right.sizeBytes.compareTo(left.sizeBytes),
      LibrarySortMode.type => left.type.label.compareTo(right.type.label),
      LibrarySortMode.tagCount => right.tags.length.compareTo(left.tags.length),
      LibrarySortMode.pinnedFirst => _comparePinned(left, right),
    };
    if (result != 0) {
      return result;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  Future<void> _loadTags() async {
    final tags = await documentService.loadTags();
    final pinnedTags = await documentService.loadPinnedTags();
    _pinnedTags = pinnedTags.where(tags.contains).toList();
    _tags = tags.toList()
      ..sort((left, right) {
        final leftPinned = _pinnedTags.contains(left);
        final rightPinned = _pinnedTags.contains(right);
        if (leftPinned != rightPinned) {
          return leftPinned ? -1 : 1;
        }
        return left.compareTo(right);
      });
  }

  bool _matchesQuery(DocumentEntry document, String query) {
    final fields = <String>[
      document.name,
      document.type.label,
      document.type.badge,
      document.path,
      document.sizeLabel,
      ...document.tags,
      if (document.recentOpenedAt != null) '最近 最近阅读 已读',
      if (document.recentOpenedAt == null) '未读',
      if (document.pinned) '置顶',
    ];
    return fields.any((field) => field.toLowerCase().contains(query));
  }

  int _compareNullableDateDesc(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return right.compareTo(left);
  }

  int _comparePinned(DocumentEntry left, DocumentEntry right) {
    if (left.pinned != right.pinned) {
      return left.pinned ? -1 : 1;
    }
    return _compareNullableDateDesc(left.recentOpenedAt, right.recentOpenedAt);
  }

  void _replaceDocument(String oldPath, DocumentEntry replacement) {
    final index = _allDocuments.indexWhere(
      (document) => document.path == oldPath,
    );
    if (index == -1) {
      _allDocuments = [..._allDocuments, replacement];
    } else {
      _allDocuments = List<DocumentEntry>.from(_allDocuments)
        ..[index] = replacement;
    }
    _invalidateCache();
  }

  void _removeDocument(String path) {
    _allDocuments = List<DocumentEntry>.from(_allDocuments)
      ..removeWhere((document) => document.path == path);
    _invalidateCache();
  }
}
