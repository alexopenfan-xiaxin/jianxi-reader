import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/app.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
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

  testWidgets('tab switch preserves library state', (tester) async {
    // Portrait so the bottom navigation bar (rather than the landscape rail)
    // renders, matching the phone form factor this app targets.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      JianxiReaderApp(
        documentService: FakeDocumentService([
          fakeDocument('alpha.md', modifiedAt: DateTime(2026)),
          fakeDocument('beta.html', type: DocumentType.html),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // Selection mode is state held by the library page itself.
    await tester.longPress(find.text('alpha.md'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 个'), findsOneWidget);

    // Round-trip through the settings tab: the library page must keep its
    // state (the IndexedStack below the tab entrance must not remount).
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 个'), findsOneWidget);
  });
}
