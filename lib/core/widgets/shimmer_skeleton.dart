import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design_tokens.dart';

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
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
    return box.animate().shimmer(duration: 1400.ms, color: highlight);
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
