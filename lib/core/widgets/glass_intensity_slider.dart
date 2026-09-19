import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../haptic_service.dart';
import '../spring_curve.dart';
import 'liquid_glass.dart';

/// Design-conscious control for the liquid-glass intensity setting.
///
/// The track is a real glass pill and the thumb a smaller glass lens, so the
/// control is itself a sample of the material it configures. The preview
/// above it renders an actual [LiquidGlassSurface] at the dragged value via
/// [LiquidGlassSurface.intensityOverride], so the effect is visible while the
/// gesture is still in flight. The value is only committed on drag/tap end,
/// so the rest of the app does not rebuild on every frame of the gesture.
class GlassIntensitySlider extends StatefulWidget {
  const GlassIntensitySlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;

  final ValueChanged<double> onChanged;

  @override
  State<GlassIntensitySlider> createState() => _GlassIntensitySliderState();
}

class _GlassIntensitySliderState extends State<GlassIntensitySlider> {
  late double _dragValue;
  bool _dragging = false;
  int _lastStep = -1;

  @override
  void initState() {
    super.initState();
    _dragValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant GlassIntensitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The user owns the gesture while dragging; ignore external updates.
    if (!_dragging && widget.value != oldWidget.value) {
      _dragValue = widget.value;
    }
  }

  void _updateFromPosition(Offset localPosition, double trackWidth) {
    final next = (localPosition.dx / trackWidth).clamp(0.0, 1.0).toDouble();
    if ((next - _dragValue).abs() < 0.001) {
      return;
    }
    setState(() => _dragValue = next);
    // Tick haptics at 5% steps so the slider feels detented, not buzzy.
    final step = (next * 20).round();
    if (step != _lastStep) {
      _lastStep = step;
      HapticService.selectionClick();
    }
  }

  void _commit() {
    final next = _dragValue.clamp(0.0, 1.0).toDouble();
    if ((next - widget.value).abs() < 0.001) {
      return;
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IntensityPreview(value: _dragValue),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _dragging = true;
                _updateFromPosition(
                  details.localPosition,
                  constraints.maxWidth,
                );
              },
              onTapUp: (_) {
                _dragging = false;
                _commit();
              },
              onHorizontalDragDown: (details) {
                _dragging = true;
                _updateFromPosition(
                  details.localPosition,
                  constraints.maxWidth,
                );
              },
              onHorizontalDragUpdate: (details) {
                _updateFromPosition(
                  details.localPosition,
                  constraints.maxWidth,
                );
              },
              onHorizontalDragEnd: (_) {
                _dragging = false;
                _commit();
              },
              onHorizontalDragCancel: () {
                _dragging = false;
              },
              child: _Track(value: _dragValue, dragging: _dragging),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text('轻透', style: _labelStyle(context, palette.muted)),
            const Spacer(),
            Text(
              '${(_dragValue * 100).round()}%',
              style: _labelStyle(
                context,
                AppColors.primary,
                weight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text('浓郁', style: _labelStyle(context, palette.muted)),
          ],
        ),
      ],
    );
  }

  TextStyle? _labelStyle(
    BuildContext context,
    Color color, {
    FontWeight? weight,
  }) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: weight,
      letterSpacing: 0,
    );
  }
}

/// The glass track plus its draggable lens thumb.
class _Track extends StatelessWidget {
  const _Track({required this.value, required this.dragging});

  final double value;

  final bool dragging;

  @override
  Widget build(BuildContext context) {
    // Alignment x spans -1 (left edge) to 1 (right edge); Align offsets by
    // half the thumb width, so no manual measuring is needed.
    final alignment = Alignment(-1.0 + 2.0 * value, 0.0);
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: liquidGlassContainerColor(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: alignment,
                child: FractionallySizedBox(
                  widthFactor: value <= 0.0 ? 0.0001 : value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: 0.05 + 0.10 * value,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: alignment,
                child: AnimatedScale(
                  scale: dragging ? 1.18 : 1.0,
                  duration: AppMotion.fast,
                  curve: SpringCurve.snappy,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(13),
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderColor: AppColors.primary.withValues(alpha: 0.34),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pattern and text seen through a real glass surface at [value], so the
/// slider previews the exact material — blur, tint, refraction depth and
/// edge highlight — the app will render.
class _IntensityPreview extends StatelessWidget {
  const _IntensityPreview({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 104,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.card,
                      AppColors.primary.withValues(alpha: 0.30),
                      palette.parchment,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: Text(
                '简兮阅读器\n液态玻璃强度预览',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
            ),
            Positioned.fill(
              child: LiquidGlassSurface(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                color: liquidGlassContainerColor(context),
                intensityOverride: value,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
