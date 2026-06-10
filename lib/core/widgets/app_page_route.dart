import 'package:flutter/material.dart';

import '../design_tokens.dart';

PageRouteBuilder<T> appPageRoute<T>({
  required WidgetBuilder builder,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final primary = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasized,
        reverseCurve: AppMotion.exit,
      );
      final incomingOffset = Tween<Offset>(
        begin: const Offset(0.045, 0.012),
        end: Offset.zero,
      ).animate(primary);
      final incomingScale = Tween<double>(begin: 0.992, end: 1).animate(
        primary,
      );

      return FadeTransition(
        opacity: primary,
        child: SlideTransition(
          position: incomingOffset,
          child: ScaleTransition(
            scale: incomingScale,
            child: child,
          ),
        ),
      );
    },
  );
}
