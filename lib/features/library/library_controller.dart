import 'package:flutter/foundation.dart';

import '../../core/document_file_service.dart';
import 'document_entry.dart';

enum LibrarySortMode {
  modifiedNewest('按修改时间：新到旧'),
  name('按名称：A 到 Z');

  const LibrarySortMode(this.label);

  final String label;
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

  List<DocumentEntry> get documents {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _allDocuments.where((document) {
      final matchesQuery =
          query.isEmpty || document.name.toLowerCase().contains(query);
      final tag = _selectedTag;
      final matchesTag = tag == null || document.tags.contains(tag);
      return matchesQuery && matchesTag;
    }).toList();

    filtered.sort(_compareDocuments);
    return filtered;
  }

  List<DocumentEntry> get documentsIgnoringSearch {
    final tag = _selectedTag;
    final filtered = _allDocuments.where((document) {
      if (tag == null) {
        return true;
      }
      return document.tags.contains(tag);
    }).toList();

    filtered.sort(_compareDocuments);
    return filtered;
  }

  List<DocumentEntry> get allDocuments => _allDocuments;

  bool get isLoading => _isLoading;

  bool get isImporting => _isImporting;

  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;

  String? get selectedTag => _selectedTag;

  LibrarySortMode get sortMode => _sortMode;

  List<String> get tags => _tags;

  Future<void> loadDocuments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allDocuments = await documentService.scanLibrary();
      _tags = await documentService.loadTags();
    } catch (error) {
      _errorMessage = '读取文档库失败：$error';
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
      _tags = await documentService.loadTags();
      return imported;
    } catch (error) {
      _errorMessage = '导入外部文档失败：$error';
      return const [];
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
      _tags = await documentService.loadTags();
      return imported;
    } catch (error) {
      _errorMessage = '打开外部文档失败：$error';
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

  Future<DocumentEntry> refreshDocument(DocumentEntry document) async {
    final refreshed = await documentService.refreshDocument(document);
    _replaceDocument(document.path, refreshed);
    _errorMessage = null;
    notifyListeners();
    return refreshed;
  }

  Future<DocumentEntry> markDocumentOpened(DocumentEntry document) async {
    final openedAt = await documentService.markDocumentOpened(document);
    final opened = document.copyWith(recentOpenedAt: openedAt);
    _replaceDocument(document.path, opened);
    notifyListeners();
    return opened;
  }

  Future<double> loadReadingOffset(DocumentEntry document) {
    return documentService.loadReadingOffset(document);
  }

  Future<void> saveReadingOffset(
    DocumentEntry document,
    double offset,
  ) {
    return documentService.saveReadingOffset(document, offset);
  }

  Future<void> createTag(String name) async {
    await documentService.createTag(name);
    final tag = name.trim();
    if (!_tags.contains(tag)) {
      _tags = [..._tags, tag]..sort();
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> deleteTag(String name) async {
    await documentService.deleteTag(name);
    final tag = name.trim();
    _tags = _tags.where((item) => item != tag).toList();
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
    notifyListeners();
  }

  Future<void> updateDocumentTags(
    DocumentEntry document,
    List<String> tags,
  ) async {
    final update = await documentService.updateDocumentTags(document, tags);
    _tags = update.allTags;
    _replaceDocument(
      document.path,
      document.copyWith(tags: update.documentTags),
    );
    _errorMessage = null;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  void updateSelectedTag(String? tag) {
    if (_selectedTag == tag) {
      return;
    }
    _selectedTag = tag;
    notifyListeners();
  }

  void updateSortMode(LibrarySortMode sortMode) {
    if (_sortMode == sortMode) {
      return;
    }
    _sortMode = sortMode;
    notifyListeners();
  }

  int _compareDocuments(DocumentEntry left, DocumentEntry right) {
    return switch (_sortMode) {
      LibrarySortMode.modifiedNewest => right.modifiedAt.compareTo(
          left.modifiedAt,
        ),
      LibrarySortMode.name => left.name.toLowerCase().compareTo(
            right.name.toLowerCase(),
          ),
    };
  }

  void _replaceDocument(String oldPath, DocumentEntry replacement) {
    final index = _allDocuments.indexWhere(
      (document) => document.path == oldPath,
    );
    if (index == -1) {
      _allDocuments = [..._allDocuments, replacement];
      return;
    }
    _allDocuments = [
      ..._allDocuments.take(index),
      replacement,
      ..._allDocuments.skip(index + 1),
    ];
  }

  void _removeDocument(String path) {
    _allDocuments = _allDocuments
        .where((document) => document.path != path)
        .toList();
  }
}
