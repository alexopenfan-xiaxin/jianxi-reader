import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jianxi_reader/core/widgets/press_scale.dart';

void main() {
  const boxKey = Key('press_box');

  double scaleX(WidgetTester tester) {
    final transform = tester.widget<Transform>(find.byType(Transform));
    return transform.transform.storage[0];
  }

  Widget harness({bool enabled = true}) {
    return MaterialApp(
      home: Center(
        child: PressScale(
          enabled: enabled,
          child: Container(key: boxKey, width: 100, height: 100),
        ),
      ),
    );
  }

  testWidgets('scales down on press and springs back on release', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    expect(scaleX(tester), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(boxKey)),
    );
    await tester.pump();
    expect(scaleX(tester), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleX(tester), 1.0);
  });

  testWidgets('does not scale when disabled', (tester) async {
    await tester.pumpWidget(harness(enabled: false));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(boxKey)),
    );
    await tester.pump();
    expect(scaleX(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
