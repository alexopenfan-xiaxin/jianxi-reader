import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/app.dart';
import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/file_rules.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:jianxi_reader/features/library/library_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final document = _document(uri.pathSegments.last);
    _documents.add(document);
    return document;
  }

  @override
  Future<List<DocumentEntry>> scanLibrary() async {
    scanCount++;
    return List.of(_documents);
  }

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
    final updated = _copyDocument(document, pinned: pinned);
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<DateTime> markDocumentOpened(DocumentEntry document) async {
    final openedAt = DateTime(2026, 6, 7, 12);
    final index = _documents.indexWhere((entry) => entry.path == document.path);
    if (index != -1) {
      _documents[index] = _copyDocument(document, recentOpenedAt: openedAt);
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
    _documents[index] = _copyDocument(document, tags: tags);
    return DocumentTagUpdate(documentTags: tags, allTags: await loadTags());
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '简兮阅读器',
      packageName: 'com.jianxi.reader',
      version: '1.2.0',
      buildNumber: '120',
      buildSignature: '',
    );
  });

  test('marking a document opened does not rescan the library', () async {
    final service = FakeDocumentService([
      _document('article.md', modifiedAt: DateTime(2026)),
    ]);
    final controller = LibraryController(documentService: service);

    await controller.loadDocuments();
    final scansAfterLoad = service.scanCount;
    final opened = await controller.markDocumentOpened(
      controller.allDocuments.single,
    );

    expect(service.scanCount, scansAfterLoad);
    expect(opened.recentOpenedAt, DateTime(2026, 6, 7, 12));
    expect(
      controller.allDocuments.single.recentOpenedAt,
      DateTime(2026, 6, 7, 12),
    );
  });

  testWidgets('shows the empty library state', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(documentService: FakeDocumentService([])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('empty_library')), findsOneWidget);
    expect(find.text('未有简牍'), findsOneWidget);
    expect(find.byKey(const ValueKey('import_button')), findsOneWidget);
  });

  testWidgets('shows the fixed home header and floating import action', (
    tester,
  ) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('1 个文档'), findsOneWidget);
    expect(find.byTooltip('搜索文档'), findsOneWidget);
    expect(find.byTooltip('文档排序'), findsOneWidget);
    expect(find.byKey(const ValueKey('import_button')), findsOneWidget);
  });

  testWidgets('filters documents from the search field', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026)),
          _document('beta.html', type: DocumentType.html),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索文档'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library_search_field')),
      'alpha',
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha.md'), findsOneWidget);
    expect(find.text('beta.html'), findsNothing);
  });

  testWidgets('filters documents by tag from the search page', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026), tags: ['工作']),
          _document('beta.html', type: DocumentType.html, tags: ['生活']),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索文档'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    expect(find.text('alpha.md'), findsOneWidget);
    expect(find.text('beta.html'), findsNothing);
  });

  testWidgets('imports multiple documents and keeps original names', (
    tester,
  ) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService(
          [],
          pickedDocuments: [
            _document('alpha.md', modifiedAt: DateTime(2026)),
            _document('beta.html', type: DocumentType.html),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入文件'));
    await tester.pumpAndSettle();

    expect(find.text('alpha.md'), findsOneWidget);
    expect(find.text('beta.html'), findsOneWidget);
    expect(find.text('已导入 2 个文档'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d{10,}_')), findsNothing);
  });

  testWidgets('changes the home view mode from appearance settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026)),
          _document('beta.html', type: DocumentType.html),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library_shelf_grid')), findsNothing);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书架'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library_shelf_grid')), findsOneWidget);
    expect(find.text('alpha.md'), findsOneWidget);
    expect(find.text('beta.html'), findsOneWidget);
  });

  testWidgets('restores the saved shelf view preference', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.libraryViewMode': 'shelf',
    });

    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library_shelf_grid')), findsOneWidget);
  });

  testWidgets('opens the rounded sort sheet from the header', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026)),
          _document('beta.html', type: DocumentType.html),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('文档排序'));
    await tester.pumpAndSettle();

    expect(find.text('文档排序'), findsOneWidget);
    expect(find.text('最近修改'), findsOneWidget);
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('文件大小'), findsOneWidget);
    expect(find.text('置顶优先'), findsOneWidget);
  });

  testWidgets('searches documents by type and tag text', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('alpha.md', modifiedAt: DateTime(2026), tags: ['工作']),
          _document('beta.html', type: DocumentType.html, tags: ['生活']),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索文档'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library_search_field')),
      'html',
    );
    await tester.pumpAndSettle();

    expect(find.text('beta.html'), findsOneWidget);
    expect(find.text('alpha.md'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('library_search_field')),
      '工作',
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha.md'), findsOneWidget);
    expect(find.text('beta.html'), findsNothing);
  });

  testWidgets('exposes rename and remove actions for a document', (
    tester,
  ) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('article.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('文档操作').first);
    await tester.pumpAndSettle();

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('设置标签'), findsOneWidget);
    expect(find.text('移出'), findsOneWidget);
  });

  testWidgets('opens shelf document actions with a long press', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.libraryViewMode': 'shelf',
    });

    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('article.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('article.md'));
    await tester.pumpAndSettle();

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('设置标签'), findsOneWidget);
    expect(find.text('移出'), findsOneWidget);
  });

  testWidgets('removes a document from the visible list', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('article.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('文档操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移出'));
    await tester.pumpAndSettle();

    expect(find.text('article.md'), findsNothing);
    expect(find.byKey(const ValueKey('empty_library')), findsOneWidget);
  });

  testWidgets('adds a tag from the document actions menu', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          _document('article.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('文档操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tag_name_field')), '工作');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsOneWidget);
  });

  testWidgets('opens the reading settings page from settings', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(documentService: FakeDocumentService([])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('阅读体验'), findsOneWidget);
    expect(find.text('关于应用'), findsOneWidget);
    expect(find.text('阅读主题'), findsNothing);

    await tester.tap(find.text('阅读体验'));
    await tester.pumpAndSettle();

    expect(find.text('阅读主题'), findsOneWidget);
    expect(find.text('页边距'), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('行距'), findsOneWidget);
  });

  testWidgets('opens the about page from settings', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(documentService: FakeDocumentService([])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于应用'));
    await tester.pumpAndSettle();

    expect(find.text('版本 1.2.0 (120)'), findsOneWidget);
    expect(find.text('应用更新'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('缓存清理'), findsOneWidget);
    expect(find.text('清理缓存'), findsOneWidget);
    expect(find.text('支持格式：Markdown、HTML'), findsNothing);
    expect(find.text('点击加入QQ交流群'), findsOneWidget);
    expect(
      find.text('开源地址：https://github.com/alexopenfan-xiaxin/jianxi-reader'),
      findsOneWidget,
    );
    expect(find.text('联系作者：alex.openfan@gmail.com'), findsOneWidget);
  });
}

DocumentEntry _document(
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

DocumentEntry _copyDocument(
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
