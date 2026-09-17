import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/file_rules.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';

/// In-memory [DocumentLibraryService] shared by widget tests.
class FakeDocumentService implements DocumentLibraryService {
  FakeDocumentService(this._documents, {List<DocumentEntry>? pickedDocuments})
    : _pickedDocuments = pickedDocuments ?? const [];

  final List<DocumentEntry> _documents;
  final List<DocumentEntry> _pickedDocuments;
  int scanCount = 0;

  @override
  Future<List<DocumentEntry>> pickAndImportDocuments() async {
    _documents.addAll(_pickedDocuments);
    return List.of(_pickedDocuments);
  }

  @override
  Future<DocumentFolderImportResult> pickAndImportFolderDocuments() async {
    return const DocumentFolderImportResult(
      documents: [],
      skipped: 0,
      failed: 0,
    );
  }

  @override
  Future<DocumentEntry> importExternalUri(Uri uri) async {
    final document = fakeDocument(uri.pathSegments.last);
    _documents.add(document);
    return document;
  }

  @override
  Future<List<DocumentEntry>> scanLibrary() async {
    scanCount++;
    return List.of(_documents);
  }

  @override
  Future<List<DocumentEntry>> scanLibraryCached() => scanLibrary();

  @override
  void invalidateLibraryCache() {}

  @override
  Future<DocumentEntry> refreshDocument(DocumentEntry document) async =>
      document;

  @override
  Future<DocumentEntry> renameDocument(
    DocumentEntry document,
    String baseName,
  ) async {
    final index = _documents.indexWhere((entry) => entry.path == document.path);
    final renamed = DocumentEntry(
      path: document.path,
      name: '$baseName.md',
      type: document.type,
      sizeBytes: document.sizeBytes,
      modifiedAt: document.modifiedAt,
      recentOpenedAt: document.recentOpenedAt,
      isReferenced: document.isReferenced,
      tags: document.tags,
      pinned: document.pinned,
    );
    _documents[index] = renamed;
    return renamed;
  }

  @override
  Future<void> removeDocument(DocumentEntry document) async {
    _documents.removeWhere((entry) => entry.path == document.path);
  }

  @override
  Future<DocumentEntry> setDocumentPinned(
    DocumentEntry document,
    bool pinned,
  ) async {
    final index = _documents.indexWhere((entry) => entry.path == document.path);
    final updated = copyFakeDocument(document, pinned: pinned);
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<DateTime> markDocumentOpened(DocumentEntry document) async {
    final openedAt = DateTime(2026, 6, 7, 12);
    final index = _documents.indexWhere((entry) => entry.path == document.path);
    if (index != -1) {
      _documents[index] = copyFakeDocument(document, recentOpenedAt: openedAt);
    }
    return openedAt;
  }

  @override
  Future<List<String>> loadTags() async {
    final tags = <String>{};
    for (final document in _documents) {
      tags.addAll(document.tags);
    }
    return tags.toList()..sort();
  }

  @override
  Future<List<String>> loadPinnedTags() async => const [];

  @override
  Future<void> createTag(String name) async {}

  @override
  Future<void> deleteTag(String name) async {}

  @override
  Future<void> setTagPinned(String name, bool pinned) async {}

  @override
  Future<DocumentTagUpdate> updateDocumentTags(
    DocumentEntry document,
    List<String> tags,
  ) async {
    final index = _documents.indexWhere((entry) => entry.path == document.path);
    _documents[index] = copyFakeDocument(document, tags: tags);
    return DocumentTagUpdate(documentTags: tags, allTags: await loadTags());
  }
}

DocumentEntry fakeDocument(
  String name, {
  DocumentType type = DocumentType.markdown,
  DateTime? modifiedAt,
  DateTime? recentOpenedAt,
  List<String> tags = const [],
  bool pinned = false,
}) {
  return DocumentEntry(
    path: '/tmp/$name',
    name: name,
    type: type,
    sizeBytes: 2048,
    modifiedAt: modifiedAt ?? DateTime(2025),
    recentOpenedAt: recentOpenedAt,
    tags: tags,
    pinned: pinned,
  );
}

DocumentEntry copyFakeDocument(
  DocumentEntry document, {
  DateTime? recentOpenedAt,
  List<String>? tags,
  bool? pinned,
}) {
  return DocumentEntry(
    path: document.path,
    name: document.name,
    type: document.type,
    sizeBytes: document.sizeBytes,
    modifiedAt: document.modifiedAt,
    recentOpenedAt: recentOpenedAt ?? document.recentOpenedAt,
    isReferenced: document.isReferenced,
    tags: tags ?? document.tags,
    pinned: pinned ?? document.pinned,
  );
}
