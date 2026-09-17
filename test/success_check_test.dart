import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jianxi_reader/core/design_tokens.dart';
import 'package:jianxi_reader/core/widgets/success_check.dart';

void main() {
  testWidgets('SuccessCheck plays once and settles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: SuccessCheck(size: 64))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SuccessCheck), findsOneWidget);
  });

  testWidgets('showSuccessFeedback appears and dismisses itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        // The toast resolves its colors via context.palette, which the app
        // theme registers as a ThemeExtension.
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSuccessFeedback(context, '已是最新版本'),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('触发'));
    await tester.pump();
    expect(find.text('已是最新版本'), findsOneWidget);

    // Entrance finishes, then the toast holds briefly before reversing out.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已是最新版本'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已是最新版本'), findsNothing);
  });
}
