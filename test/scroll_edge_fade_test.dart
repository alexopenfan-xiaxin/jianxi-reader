import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jianxi_reader/core/widgets/scroll_edge_fade.dart';

void main() {
  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: ScrollEdgeFade(
          topInset: 80,
          child: ListView.builder(
            itemCount: 60,
            itemBuilder: (context, index) =>
                SizedBox(height: 48, child: Text('row $index')),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps one mask mounted before and after scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    // The mask must exist at rest too: swapping the returned widget type
    // rebuilds the scroll subtree and throws the offset away.
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('scrolling is not reset by the fade band', (tester) async {
    await tester.pumpWidget(harness());

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(0));

    // And it keeps moving on a second drag, rather than snapping back.
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(300),
    );
  });
}
