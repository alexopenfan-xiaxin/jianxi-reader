import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Translates a highlight band across [child] once, then stops.
///
/// Driven by an [AnimationController] with the optional [delay] baked into
/// the curve interval, so no [Timer] is ever scheduled and the sweep stays
/// `pumpAndSettle`-safe in widget tests.
class OneShotShimmer extends StatefulWidget {
  const OneShotShimmer({
    super.key,
    required this.child,
    required this.color,
    this.duration = const Duration(milliseconds: 1400),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Color color;
  final Duration duration;
  final Duration delay;

  @override
  State<OneShotShimmer> createState() => _OneShotShimmerState();
}

class _OneShotShimmerState extends State<OneShotShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(duration: total, vsync: this)..forward();
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        widget.delay.inMilliseconds / total.inMilliseconds,
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
        // The gradient midpoint travels from off-screen left (-1.5) to
        // off-screen right (1.5); the band itself is invisible at both
        // ends, so the sweep fades in and out instead of popping.
        final center = -1.5 + 3.0 * _progress.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(center - 0.5, 0.0),
              end: Alignment(center + 0.5, 0.0),
              colors: [Colors.transparent, widget.color, Colors.transparent],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcOver,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A placeholder block used by skeleton loading states.
///
/// Renders a neutral base tint with a single one-shot shimmer sweep. The
/// sweep never repeats, so skeletons remain `pumpAndSettle`-safe in widget
/// tests: a persistent load simply ends on the static base tint.
class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.055 : 0.05,
    );
    final highlight = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.16 : 0.09,
    );
    return OneShotShimmer(
      color: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A library document card in its loading form: badge block, title line and
/// summary line, all shimmering once.
class LibrarySkeletonCard extends StatelessWidget {
  const LibrarySkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.hairline.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBlock(width: 48, height: 48, borderRadius: 10),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBlock(height: 16, borderRadius: 5),
                SizedBox(height: AppSpacing.sm),
                ShimmerBlock(width: 120, height: 12, borderRadius: 5),
                SizedBox(height: AppSpacing.xs),
                ShimmerBlock(width: 76, height: 12, borderRadius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
