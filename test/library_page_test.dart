import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/app.dart';
import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/file_rules.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDocumentService implements DocumentLibraryService {
  FakeDocumentService(this._documents);

  final List<DocumentEntry> _documents;

  @override
  Future<DocumentEntry?> pickAndImportDocument() async => null;

  @override
  Future<List<DocumentEntry>> scanLibrary() async => List.of(_documents);

  @override
  Future<DocumentEntry> refreshDocument(DocumentEntry document) async => document;

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
    );
    _documents[index] = renamed;
    return renamed;
  }

  @override
  Future<void> removeDocument(DocumentEntry document) async {
    _documents.removeWhere((entry) => entry.path == document.path);
  }

  @override
  Future<void> markDocumentOpened(DocumentEntry document) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '简兮阅读器',
      packageName: 'com.jianxi.reader',
      version: '1.2.0',
      buildNumber: '20',
      buildSignature: '',
    );
  });

  testWidgets('shows the empty library state', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(documentService: FakeDocumentService([])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('empty_library')), findsOneWidget);
    expect(find.text('还没有文档'), findsOneWidget);
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

    await tester.enterText(
      find.byKey(const ValueKey('library_search_field')),
      'alpha',
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

  testWidgets('shows settings page reading and theme choices', (tester) async {
    await tester.pumpWidget(
      JianxiReaderApp(documentService: FakeDocumentService([])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('系统'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('阅读主题'), findsOneWidget);
    expect(find.text('版本 1.2.0 (20)'), findsOneWidget);
  });
}

DocumentEntry _document(
  String name, {
  DocumentType type = DocumentType.markdown,
  DateTime? modifiedAt,
  DateTime? recentOpenedAt,
}) {
  return DocumentEntry(
    path: '/tmp/$name',
    name: name,
    type: type,
    sizeBytes: 2048,
    modifiedAt: modifiedAt ?? DateTime(2025),
    recentOpenedAt: recentOpenedAt,
  );
}
