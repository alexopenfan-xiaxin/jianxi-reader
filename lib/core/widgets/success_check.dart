import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../spring_curve.dart';

/// An animated success mark: a circle pops in and the check stroke draws
/// itself. The whole thing plays once and stops, so it stays safe for
/// `pumpAndSettle`-driven widget tests.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({
    super.key,
    this.size = 40,
    this.color,
    this.strokeWidth = 3.2,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pop;
  late final Animation<double> _circle;
  late final Animation<double> _check;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();
    _pop = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: SpringCurve.bouncy),
      ),
    );
    _circle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: AppMotion.release),
      ),
    );
    _check = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 1.0, curve: SpringCurve.gentle),
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
    final color = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _pop.value,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _SuccessCheckPainter(
              circle: _circle.value,
              check: _check.value.clamp(0.0, 1.0),
              color: color,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter({
    required this.circle,
    required this.check,
    required this.color,
    required this.strokeWidth,
  });

  final double circle;
  final double check;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final fill = Paint()..color = color.withValues(alpha: 0.12 * circle);
    canvas.drawCircle(center, radius, fill);

    final ring = Paint()
      ..color = color.withValues(alpha: 0.45 * circle)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius * (0.72 + 0.28 * circle), ring);

    if (check <= 0) {
      return;
    }
    final path = Path()
      ..moveTo(center.dx - radius * 0.34, center.dy + radius * 0.02)
      ..lineTo(center.dx - radius * 0.06, center.dy + radius * 0.30)
      ..lineTo(center.dx + radius * 0.38, center.dy - radius * 0.32);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * check);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawn, stroke);
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) =>
      circle != oldDelegate.circle ||
      check != oldDelegate.check ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// Shows a lightweight success toast ([SuccessCheck] + [message]) above the
/// current content and dismisses it automatically.
void showSuccessFeedback(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SuccessToast(
      message: message,
      onDismissed: () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  overlay.insert(entry);
}

class _SuccessToast extends StatefulWidget {
  const _SuccessToast({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<_SuccessToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _rise;
  Timer? _holdTimer;
  bool _dismissed = false;

  static const _holdDuration = Duration(milliseconds: 1300);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.slow, vsync: this);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
      reverseCurve: AppMotion.exit,
    );
    _rise = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.release));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // A cancellable Timer (not Future.delayed): dispose must be able to
        // retract it, or a toast removed mid-hold leaves the pending timer
        // behind and trips the widget-test timersPending invariant.
        _holdTimer = Timer(_holdDuration, () {
          if (mounted && !_dismissed) {
            _controller.reverse();
          }
        });
      } else if (status == AnimationStatus.dismissed) {
        _dismiss();
      }
    });
    _controller.forward();
  }

  void _dismiss() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _dismiss();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _rise,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.card.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: palette.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SuccessCheck(size: 26),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              widget.message,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(letterSpacing: 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
