import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// One-shot entrance for list/grid items: fade in + rise + subtle scale,
/// staggered by [index]. Plays once per element mount and never loops, so
/// it is safe to use in trees exercised by `pumpAndSettle` widget tests.
///
/// The per-item stagger is baked into a single [AnimationController] via an
/// [Interval] rather than scheduled with a [Timer]: a controller started in
/// the final frame of a `pumpAndSettle` keeps the pump loop alive through
/// transient callbacks, whereas a pending [Timer] would trip the binding's
/// `timersPending` invariant.
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
    return _StaggeredEntranceBody(index: index, rise: rise, child: child);
  }
}

class _StaggeredEntranceBody extends StatefulWidget {
  const _StaggeredEntranceBody({
    required this.index,
    required this.rise,
    required this.child,
  });

  final int index;
  final double rise;
  final Widget child;

  @override
  State<_StaggeredEntranceBody> createState() => _StaggeredEntranceBodyState();
}

class _StaggeredEntranceBodyState extends State<_StaggeredEntranceBody>
    with SingleTickerProviderStateMixin {
  static const Duration _staggerStep = Duration(milliseconds: 45);

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final delay = _staggerStep * widget.index;
    _controller = AnimationController(
      duration: delay + AppMotion.slow,
      vsync: this,
    )..forward();
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMilliseconds / (delay + AppMotion.slow).inMilliseconds,
        1.0,
        curve: AppMotion.emphasized,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final value = _progress.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.rise),
            child: Transform.scale(scale: 0.97 + 0.03 * value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// One-shot entrance for full-state widgets (loading / empty / error).
/// Fades in while rising slightly; completes once and stops.
class StateShell extends StatefulWidget {
  const StateShell({super.key, required this.child, this.rise = 12.0});

  final Widget child;
  final double rise;

  @override
  State<StateShell> createState() => _StateShellState();
}

class _StateShellState extends State<StateShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.normal, vsync: this)
      ..forward();
    _progress = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final value = _progress.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.rise),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
