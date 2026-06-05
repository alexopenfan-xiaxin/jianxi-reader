import 'package:flutter/foundation.dart';

import '../../core/document_file_service.dart';
import 'document_entry.dart';

enum LibrarySortMode {
  modified('修改'),
  name('名称');

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
  LibrarySortMode _sortMode = LibrarySortMode.modified;

  List<DocumentEntry> get documents {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _allDocuments.where((document) {
      if (query.isEmpty) {
        return true;
      }
      return document.name.toLowerCase().contains(query);
    }).toList();

    filtered.sort(_compareDocuments);
    return filtered;
  }

  List<DocumentEntry> get allDocuments => _allDocuments;

  bool get isLoading => _isLoading;

  bool get isImporting => _isImporting;

  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;

  LibrarySortMode get sortMode => _sortMode;

  Future<void> loadDocuments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allDocuments = await documentService.scanLibrary();
    } catch (error) {
      _errorMessage = '读取文档库失败：$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DocumentEntry?> importExternalDocument() async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final imported = await documentService.pickAndImportDocument();
      _allDocuments = await documentService.scanLibrary();
      return imported;
    } catch (error) {
      _errorMessage = '导入外部文档失败：$error';
      return null;
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
    _allDocuments = await documentService.scanLibrary();
    _errorMessage = null;
    notifyListeners();
    return renamed;
  }

  Future<void> removeDocument(DocumentEntry document) async {
    await documentService.removeDocument(document);
    _allDocuments = await documentService.scanLibrary();
    _errorMessage = null;
    notifyListeners();
  }

  Future<DocumentEntry> refreshDocument(DocumentEntry document) async {
    final refreshed = await documentService.refreshDocument(document);
    _allDocuments = await documentService.scanLibrary();
    _errorMessage = null;
    notifyListeners();
    return refreshed;
  }

  Future<void> markDocumentOpened(DocumentEntry document) async {
    await documentService.markDocumentOpened(document);
    _allDocuments = await documentService.scanLibrary();
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
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
      LibrarySortMode.modified => right.modifiedAt.compareTo(left.modifiedAt),
      LibrarySortMode.name => left.name.toLowerCase().compareTo(
            right.name.toLowerCase(),
          ),
    };
  }
}
