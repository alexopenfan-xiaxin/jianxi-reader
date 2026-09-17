import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/app.dart';
import 'package:jianxi_reader/core/file_rules.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:jianxi_reader/features/library/library_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_document_service.dart';

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
      fakeDocument('article.md', modifiedAt: DateTime(2026)),
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
          fakeDocument('beta.html', type: DocumentType.html),
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026), tags: ['工作']),
          fakeDocument('beta.html', type: DocumentType.html, tags: ['生活']),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索文档'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search_tag_工作')));
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
            fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
            fakeDocument('beta.html', type: DocumentType.html),
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
          fakeDocument('beta.html', type: DocumentType.html),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library_shelf_grid')), findsNothing);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观与动画'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文库'));
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
          fakeDocument('beta.html', type: DocumentType.html),
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
          fakeDocument('alpha.md', modifiedAt: DateTime(2026), tags: ['工作']),
          fakeDocument('beta.html', type: DocumentType.html, tags: ['生活']),
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
          fakeDocument('article.md', modifiedAt: DateTime(2026)),
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

  testWidgets('enters shelf selection with a long press', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.libraryViewMode': 'shelf',
    });

    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          fakeDocument('article.md', modifiedAt: DateTime(2026)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('article.md'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 个'), findsOneWidget);
  });

  testWidgets('removes a document from the visible list', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          fakeDocument('article.md', modifiedAt: DateTime(2026)),
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
          fakeDocument('article.md', modifiedAt: DateTime(2026)),
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

    expect(find.text('外观与动画'), findsOneWidget);
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
