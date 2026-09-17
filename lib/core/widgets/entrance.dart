import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design_tokens.dart';

/// One-shot entrance for list/grid items: fade in + rise + subtle scale,
/// staggered by [index]. Plays once per element mount and never loops, so
/// it is safe to use in trees exercised by `pumpAndSettle` widget tests.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxIndex = 12,
    this.rise = 12.0,
  });

  final int index;
  final Widget child;
  final int maxIndex;
  final double rise;

  @override
  Widget build(BuildContext context) {
    if (index >= maxIndex) {
      return child;
    }
    final delay = Duration(milliseconds: index * 45);
    final effects = <Effect>[
      FadeEffect(
        delay: delay,
        duration: AppMotion.slow,
        curve: AppMotion.emphasized,
      ),
      MoveEffect(
        delay: delay,
        duration: AppMotion.slow,
        curve: AppMotion.emphasized,
        begin: Offset(0, rise),
        end: Offset.zero,
      ),
      ScaleEffect(
        delay: delay,
        duration: AppMotion.slow,
        curve: AppMotion.emphasized,
        begin: const Offset(0.97, 0.97),
        end: const Offset(1, 1),
      ),
    ];
    return child.animate(effects: effects);
  }
}

/// One-shot entrance for full-state widgets (loading / empty / error).
/// Fades in while rising slightly; completes once and stops.
class StateShell extends StatelessWidget {
  const StateShell({super.key, required this.child, this.rise = 12.0});

  final Widget child;
  final double rise;

  @override
  Widget build(BuildContext context) {
    final effects = <Effect>[
      FadeEffect(duration: AppMotion.normal, curve: AppMotion.emphasized),
      MoveEffect(
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
        begin: Offset(0, rise),
        end: Offset.zero,
      ),
    ];
    return child.animate(effects: effects);
  }
}
