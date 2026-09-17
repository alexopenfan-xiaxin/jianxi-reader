import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../design_tokens.dart';

/// Scales [child] down slightly while a pointer is pressed and springs it
/// back on release.
///
/// Uses a raw [Listener] rather than a gesture recognizer, so it composes
/// cleanly with any tap handling ([InkWell], [GestureDetector]) in the
/// subtree without competing in the gesture arena.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.975,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.fast, vsync: this);
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.press));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (!widget.enabled || !mounted) {
      return;
    }
    _controller.forward();
  }

  void _release() {
    if (!widget.enabled || !mounted) {
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 28),
        _controller.value,
        0,
        0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: widget.enabled ? (_) => _pressDown() : null,
        onPointerUp: widget.enabled ? (_) => _release() : null,
        onPointerCancel: widget.enabled ? (_) => _release() : null,
        child: widget.child,
      ),
    );
  }
}
