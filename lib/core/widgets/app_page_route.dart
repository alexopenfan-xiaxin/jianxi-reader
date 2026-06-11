import 'package:flutter/material.dart';

import '../design_tokens.dart';

PageRouteBuilder<T> appPageRoute<T>({
  required WidgetBuilder builder,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final primary = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );
      final incomingOffset = Tween<Offset>(
        begin: const Offset(0.028, 0),
        end: Offset.zero,
      ).animate(primary);

      return FadeTransition(
        opacity: primary,
        child: SlideTransition(
          position: incomingOffset,
          child: child,
        ),
      );
    },
  );
}
