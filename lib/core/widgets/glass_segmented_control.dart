import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';
import '../haptic_service.dart';
import '../spring_curve.dart';
import 'liquid_glass.dart';

/// One option of an app segmented control.
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Two-state segmented control used across settings and reading options.
///
/// In liquid-glass mode the control is the component library's
/// [lg.GlassSegmentedControl], resolved through [AppGlassSettings] so the
/// material matches the rest of the app. Classic mode keeps the pre-migration
/// Material/backdrop implementation so its appearance does not change.
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
    final liquidGlass = context.select<AppSettingsController, bool>(
      (settings) => settings.liquidGlassEnabled,
    );
    if (!liquidGlass) {
      return _ClassicSegmentedControl<T>(
        segments: segments,
        value: value,
        onChanged: onChanged,
      );
    }

    final palette = context.palette;
    final selectedIndex = segments.indexWhere((segment) {
      return segment.value == value;
    });
    final effectiveIndex = selectedIndex < 0 ? 0 : selectedIndex;

    void selectIndex(int index) {
      final nextValue = segments[index].value;
      if (nextValue != value) {
        HapticService.selectionClick();
        onChanged(nextValue);
      }
    }

    final indicatorColor = AppColors.primary.withValues(alpha: 0.14);
    return lg.GlassSegmentedControl(
      segments: [
        for (final segment in segments)
          lg.GlassSegment(
            label: segment.label,
            icon: segment.icon == null ? null : Icon(segment.icon, size: 18),
          ),
      ],
      selectedIndex: effectiveIndex,
      onSegmentSelected: selectIndex,
      height: LiquidGlassTokens.bottomBarHeight,
      borderRadius: AppRadii.pill,
      padding: const EdgeInsets.all(LiquidGlassTokens.bottomBarPadding),
      selectedTextStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      unselectedTextStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: palette.ink,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      indicatorColor: indicatorColor,
      settings: AppGlassSettings.build(
        context,
        role: AppGlassRole.interactiveControl,
      ),
      indicatorSettings: AppGlassSettings.build(
        context,
        role: AppGlassRole.interactiveControl,
        color: indicatorColor,
      ),
      useOwnLayer: true,
      quality: AppGlassSettings.qualityFor(AppGlassRole.interactiveControl),
    );
  }
}

/// Pre-migration classic implementation. Kept verbatim in structure so the
/// classic visual mode does not change with the component-library migration.
class _ClassicSegmentedControl<T> extends StatelessWidget {
  const _ClassicSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<GlassSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selectedIndex = segments.indexWhere((segment) {
      return segment.value == value;
    });
    final effectiveIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / segments.length;
        final trackRadius = BorderRadius.circular(AppRadii.pill);
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
            height: 48,
            child: Stack(
              children: [
                Positioned.fill(child: _ClassicTrack(palette: palette)),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: trackRadius,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: AppMotion.normal,
                          curve: SpringCurve.snappy,
                          left: effectiveIndex * itemWidth,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: _ClassicThumb(),
                          ),
                        ),
                        Positioned.fill(
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < segments.length;
                                index++
                              )
                                Expanded(
                                  child: _ClassicSegmentButton<T>(
                                    segment: segments[index],
                                    selected: index == effectiveIndex,
                                    onTap: () {
                                      selectValue(segments[index].value);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _ClassicTrack extends StatelessWidget {
  const _ClassicTrack({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
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
              color: palette.card.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: palette.hairline.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicThumb extends StatelessWidget {
  const _ClassicThumb();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
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
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicSegmentButton<T> extends StatelessWidget {
  const _ClassicSegmentButton({
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
    final icon = selected ? segment.icon ?? Icons.check_rounded : segment.icon;
    final color = selected ? AppColors.primary : palette.ink;

    return Semantics(
      selected: selected,
      button: true,
      label: segment.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
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
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
