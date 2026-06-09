import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';
import '../haptic_service.dart';
import 'liquid_glass.dart';

class GlassSegment<T> {
  const GlassSegment({
    required this.value,
    required this.label,
    this.icon,
    this.selectedIcon,
  });

  final T value;
  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
}

class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  }) : assert(segments.length > 1);

  final List<GlassSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass =
        context.watch<AppSettingsController>().liquidGlassEnabled;
    final selectedIndex = segments.indexWhere((segment) {
      return segment.value == value;
    });
    final effectiveIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / segments.length;
        var activeValue = value;

        void selectValue(T nextValue) {
          if (nextValue != activeValue) {
            activeValue = nextValue;
            HapticService.selectionClick();
            onChanged(nextValue);
          }
        }

        void selectFromLocalPosition(Offset localPosition) {
          final nextIndex = (localPosition.dx / itemWidth)
              .floor()
              .clamp(0, segments.length - 1)
              .toInt();
          selectValue(segments[nextIndex].value);
        }

        return GestureDetector(
          onHorizontalDragStart: (details) {
            selectFromLocalPosition(details.localPosition);
          },
          onHorizontalDragUpdate: (details) {
            selectFromLocalPosition(details.localPosition);
          },
          child: SizedBox(
            height: liquidGlass ? LiquidGlassTokens.bottomBarHeight : 48,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _GlassTrack(
                    palette: palette,
                    liquidGlass: liquidGlass,
                  ),
                ),
                AnimatedPositioned(
                  duration: liquidGlass ? AppMotion.normal : AppMotion.fast,
                  curve: AppMotion.emphasized,
                  left: effectiveIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Padding(
                    padding: EdgeInsets.all(
                      liquidGlass ? LiquidGlassTokens.bottomBarPadding : 4,
                    ),
                    child: _GlassThumb(liquidGlass: liquidGlass),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (var index = 0; index < segments.length; index++)
                        Expanded(
                          child: _GlassSegmentButton<T>(
                            segment: segments[index],
                            selected: index == effectiveIndex,
                            onTap: () => selectValue(segments[index].value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlassTrack extends StatelessWidget {
  const _GlassTrack({required this.palette, required this.liquidGlass});

  final AppPalette palette;
  final bool liquidGlass;

  @override
  Widget build(BuildContext context) {
    if (liquidGlass) {
      return LiquidGlassSurface(
        blurSigma: LiquidGlassTokens.bilipaiTunedBlurSigma,
        color: liquidGlassContainerColor(context),
        borderColor: Colors.white.withOpacity(0.34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        child: const SizedBox.expand(),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.card.withOpacity(0.70),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.hairline.withOpacity(0.42)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassThumb extends StatelessWidget {
  const _GlassThumb({required this.liquidGlass});

  final bool liquidGlass;

  @override
  Widget build(BuildContext context) {
    if (liquidGlass) {
      return LiquidGlassSurface(
        blurSigma: LiquidGlassTokens.bilipaiTunedBlurSigma,
        color: AppColors.primary.withOpacity(0.10),
        borderColor: AppColors.primary.withOpacity(0.22),
        tintPrimary: true,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        child: const SizedBox.expand(),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSegmentButton<T> extends StatelessWidget {
  const _GlassSegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final GlassSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = selected
        ? segment.selectedIcon ?? segment.icon ?? Icons.check_rounded
        : segment.icon;
    final color = selected ? AppColors.primary : palette.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        splashFactory: NoSplash.splashFactory,
        highlightColor: AppColors.primary.withOpacity(0.04),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
