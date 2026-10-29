import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/accessibility.dart';

void main() {
  test('caps the system text scale but never shrinks below 1.0', () {
    final huge = AppAccessibility.clampTextScaler(TextScaler.linear(2.0));
    expect(huge.scale(10), 16.0);

    final normal = AppAccessibility.clampTextScaler(TextScaler.linear(1.0));
    expect(normal.scale(10), 10.0);

    final small = AppAccessibility.clampTextScaler(TextScaler.linear(0.8));
    expect(small.scale(10), 10.0);
  });

  testWidgets('honours the remove-animations switch', (tester) async {
    const probe = Duration(milliseconds: 300);

    Duration? withAnimations;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            withAnimations = AppAccessibility.duration(context, probe);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(withAnimations, probe);

    Duration? withoutAnimations;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            withoutAnimations = AppAccessibility.duration(context, probe);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(withoutAnimations, Duration.zero);
  });
}
