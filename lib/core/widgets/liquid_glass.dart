import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';

class LiquidGlassTokens {
  static const androidBlurAmount = 0.0625;
  static const androidSaturation = 140.0;
  static const androidAberrationIntensity = 2.0;
  static const androidDisplacementScale = 70.0;
  static const androidElasticity = 0.15;
  static const androidEdgeHighlightBorderWidth = 1.5;
  static const androidEdgeHighlightOpacity = 1.0;
  static const androidBlurSigma = 4.0 + androidBlurAmount * 32.0;
  static const metalFxDarkBase = Color(0xFF0D0D0D);
  static const metalFxCyan = Color(0xFFAAE8FF);
  static const metalFxMint = Color(0xFFC5FE9E);
  static const metalFxRose = Color(0xFFF7888D);
  static const metalFxGold = Color(0xFFFFFDC3);
  static const metalFxBlue = Color(0xFF007CFF);
  static const metalFxDarkGlowOpacity = 0.70;
  static const metalFxDarkReflectionOpacity = 0.34;
  static const metalFxDarkRingWidth = 1.4;
  static const bottomBarHeight = 58.0;
  static const bottomBarIndicatorHeight = 56.0;
  static const bottomBarPadding = 3.0;
  static const bottomBarItemWidth = 116.0;
  static const floatingBottomBarHeight = 64.0;
  static const floatingBottomBarPadding = 4.0;
  static const floatingBottomBarItemWidth = 76.0;
  static const floatingBottomBarIndicatorHeight = 56.0;
  static const floatingBottomBarPanelOffsetMax = 5.0;
  static const blurSigma = 24.0;
  static const effectBlurSigma = androidBlurSigma;
  static const materialAlphaLight = 0.38;
  static const materialAlphaDark = 0.58;
  static const ultraThinAlpha = 0.15;
  static const cardAlphaLight = 0.68;
  static const cardAlphaDark = 0.64;
  static const headerAlphaLight = 0.54;
  static const headerAlphaDark = 0.56;
  static const shellRefractionAmount = 24.0;
}

class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    required this.child,
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill)),
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.blurSigma = LiquidGlassTokens.blurSigma,
    this.boxShadow = const [],
    this.innerHighlight = true,
    this.tintPrimary = false,
    this.chromaticEdge = true,
    this.edgeHighlight = true,
    this.metalFxDarkEffect = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double blurSigma;
  final List<BoxShadow> boxShadow;
  final bool innerHighlight;
  final bool tintPrimary;
  final bool chromaticEdge;
  final bool edgeHighlight;
  final bool metalFxDarkEffect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final useMetalFxDark = dark && metalFxDarkEffect;
    final resolvedColor = useMetalFxDark
        ? Colors.transparent
        : color ??
              (dark
                  ? Colors.white.withValues(
                      alpha: LiquidGlassTokens.materialAlphaDark,
                    )
                  : palette.card.withValues(
                      alpha: LiquidGlassTokens.materialAlphaLight,
                    ));
    final resolvedBorder =
        borderColor ??
        (useMetalFxDark
            ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.24)
            : dark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.42));
    final resolvedShadows = useMetalFxDark
        ? [
            BoxShadow(
              color: LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.13),
              blurRadius: 28,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: LiquidGlassTokens.metalFxRose.withValues(alpha: 0.08),
              blurRadius: 34,
              spreadRadius: -10,
              offset: const Offset(0, -3),
            ),
            ...boxShadow,
          ]
        : boxShadow;
    final filter = useMetalFxDark
        ? ImageFilter.blur(sigmaX: blurSigma + 1, sigmaY: blurSigma + 1)
        : ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: resolvedShadows,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: filter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: resolvedColor,
                borderRadius: borderRadius,
                border: Border.all(color: resolvedBorder),
              ),
              child: Stack(
                children: [
                  if (useMetalFxDark)
                    _MetalFxDarkReflection(borderRadius: borderRadius),
                  if (chromaticEdge)
                    _LiquidGlassChromaticEdge(
                      borderRadius: borderRadius,
                      darkMetal: useMetalFxDark,
                    ),
                  if (innerHighlight && !useMetalFxDark)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(
                                  alpha: dark ? 0.20 : 0.38,
                                ),
                                Colors.white.withValues(alpha: 0.05),
                                Colors.black.withValues(
                                  alpha: dark ? 0.14 : 0.05,
                                ),
                              ],
                              stops: const [0, 0.52, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (edgeHighlight)
                    _LiquidGlassEdgeHighlight(
                      borderRadius: borderRadius,
                      darkMetal: useMetalFxDark,
                    ),
                  if (useMetalFxDark)
                    _MetalFxDarkRim(borderRadius: borderRadius),
                  if (tintPrimary && !useMetalFxDark)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.12),
                                Colors.transparent,
                                AppColors.primaryFocus.withValues(alpha: 0.08),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassChromaticEdge extends StatelessWidget {
  const _LiquidGlassChromaticEdge({
    required this.borderRadius,
    required this.darkMetal,
  });

  final BorderRadius borderRadius;
  final bool darkMetal;

  @override
  Widget build(BuildContext context) {
    final intensity = darkMetal
        ? LiquidGlassTokens.androidAberrationIntensity * 1.25
        : LiquidGlassTokens.androidAberrationIntensity / 2;
    final roseOpacity = darkMetal ? 0.20 : 0.09;
    final cyanOpacity = darkMetal ? 0.24 : 0.10;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(-0.8 * intensity, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: LiquidGlassTokens.metalFxRose.withValues(
                      alpha: roseOpacity,
                    ),
                    width: 1,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Transform.translate(
              offset: Offset(0.8 * intensity, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: LiquidGlassTokens.metalFxCyan.withValues(
                      alpha: cyanOpacity,
                    ),
                    width: 1,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassEdgeHighlight extends StatelessWidget {
  const _LiquidGlassEdgeHighlight({
    required this.borderRadius,
    required this.darkMetal,
  });

  final BorderRadius borderRadius;
  final bool darkMetal;

  @override
  Widget build(BuildContext context) {
    final opacity = LiquidGlassTokens.androidEdgeHighlightOpacity;
    final brightColor = darkMetal
        ? LiquidGlassTokens.metalFxGold
        : Colors.white;
    final midColor = darkMetal ? LiquidGlassTokens.metalFxCyan : Colors.white;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                midColor.withValues(alpha: (darkMetal ? 0.18 : 0.12) * opacity),
                brightColor.withValues(
                  alpha: (darkMetal ? 0.34 : 0.40) * opacity,
                ),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.28, 0.66, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetalFxDarkReflection extends StatelessWidget {
  const _MetalFxDarkReflection({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final opacity = LiquidGlassTokens.metalFxDarkReflectionOpacity;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: RadialGradient(
              center: const Alignment(-0.78, -0.92),
              radius: 1.25,
              colors: [
                LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.18 * opacity),
                LiquidGlassTokens.metalFxMint.withValues(alpha: 0.10 * opacity),
                Colors.transparent,
              ],
              stops: const [0, 0.22, 0.72],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: RadialGradient(
                center: const Alignment(0.86, 0.92),
                radius: 1.1,
                colors: [
                  LiquidGlassTokens.metalFxRose.withValues(
                    alpha: 0.12 * opacity,
                  ),
                  LiquidGlassTokens.metalFxBlue.withValues(
                    alpha: 0.10 * opacity,
                  ),
                  Colors.transparent,
                ],
                stops: const [0, 0.20, 0.68],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetalFxDarkRim extends StatelessWidget {
  const _MetalFxDarkRim({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _MetalFxDarkRimPainter(borderRadius)),
      ),
    );
  }
}

class _MetalFxDarkRimPainter extends CustomPainter {
  const _MetalFxDarkRimPainter(this.borderRadius);

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final rrect = borderRadius
        .toRRect(rect)
        .deflate(LiquidGlassTokens.metalFxDarkRingWidth / 2);
    final glowRRect = rrect.deflate(1.2);
    final glowOpacity = LiquidGlassTokens.metalFxDarkGlowOpacity;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.30 * glowOpacity),
          LiquidGlassTokens.metalFxMint.withValues(alpha: 0.24 * glowOpacity),
          LiquidGlassTokens.metalFxRose.withValues(alpha: 0.20 * glowOpacity),
          LiquidGlassTokens.metalFxBlue.withValues(alpha: 0.24 * glowOpacity),
        ],
        stops: const [0, 0.34, 0.68, 1],
      ).createShader(rect);
    canvas.drawRRect(glowRRect, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = LiquidGlassTokens.metalFxDarkRingWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.70),
          LiquidGlassTokens.metalFxGold.withValues(alpha: 0.62),
          LiquidGlassTokens.metalFxRose.withValues(alpha: 0.42),
          LiquidGlassTokens.metalFxBlue.withValues(alpha: 0.58),
        ],
        stops: const [0, 0.22, 0.48, 0.74, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, ringPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.16),
        ],
        stops: const [0, 0.46, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(2.2), innerPaint);
  }

  @override
  bool shouldRepaint(covariant _MetalFxDarkRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}

Color liquidGlassContainerColor(BuildContext context, {double? alpha}) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final resolvedAlpha =
      alpha ??
      (dark
          ? LiquidGlassTokens.materialAlphaDark
          : LiquidGlassTokens.materialAlphaLight);
  if (dark) {
    return Colors.transparent;
  }
  return palette.card.withValues(alpha: resolvedAlpha);
}

Color liquidGlassCardColor(BuildContext context) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) {
    return Colors.transparent;
  }
  return palette.card.withValues(alpha: LiquidGlassTokens.cardAlphaLight);
}

Color liquidGlassHeaderColor(BuildContext context) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) {
    return Colors.transparent;
  }
  return palette.card.withValues(alpha: LiquidGlassTokens.headerAlphaLight);
}

bool liquidGlassEnabled(BuildContext context) {
  return context.select<AppSettingsController, bool>(
    (s) => s.liquidGlassEnabled,
  );
}

bool readLiquidGlassEnabled(BuildContext context) {
  return context.read<AppSettingsController>().liquidGlassEnabled;
}

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    required this.child,
    super.key,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
    this.color,
    this.borderColor,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      color: color ?? liquidGlassCardColor(context),
      borderColor:
          borderColor ??
          (dark
              ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.46)),
      blurSigma: LiquidGlassTokens.effectBlurSigma,
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: dark
                  ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: dark ? 34 : 28,
              spreadRadius: dark ? -8 : 0,
              offset: const Offset(0, 14),
            ),
            if (dark)
              BoxShadow(
                color: LiquidGlassTokens.metalFxRose.withValues(alpha: 0.08),
                blurRadius: 26,
                spreadRadius: -12,
                offset: const Offset(0, -4),
              ),
          ],
      child: child,
    );
  }
}

class LiquidGlassSheetPanel extends StatelessWidget {
  const LiquidGlassSheetPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: LiquidGlassPanel(
        padding: padding,
        borderRadius: borderRadius,
        child: SafeArea(
          top: false,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

class LiquidGlassTextFieldFrame extends StatelessWidget {
  const LiquidGlassTextFieldFrame({
    required this.child,
    super.key,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill)),
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: LiquidGlassSurface(
        borderRadius: borderRadius,
        padding: padding,
        color: liquidGlassContainerColor(context, alpha: dark ? 0.54 : 0.34),
        borderColor: dark
            ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.42),
        blurSigma: LiquidGlassTokens.effectBlurSigma,
        boxShadow: [
          BoxShadow(
            color: dark
                ? LiquidGlassTokens.metalFxBlue.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: dark ? 22 : 16,
            spreadRadius: dark ? -8 : 0,
            offset: const Offset(0, 8),
          ),
        ],
        child: child,
      ),
    );
  }
}

class LiquidGlassChip extends StatelessWidget {
  const LiquidGlassChip({
    required this.label,
    super.key,
    this.selected = false,
    this.icon,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected
        ? (dark ? const Color(0xFFF1FBFF) : AppColors.primary)
        : palette.ink;
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      color: selected
          ? (dark
                ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.18)
                : AppColors.primary.withValues(alpha: 0.12))
          : liquidGlassContainerColor(context, alpha: dark ? 0.50 : 0.32),
      borderColor: selected
          ? (dark
                ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.42)
                : AppColors.primary.withValues(alpha: 0.24))
          : (dark
                ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.38)),
      blurSigma: LiquidGlassTokens.effectBlurSigma,
      tintPrimary: selected,
      boxShadow: [
        BoxShadow(
          color: dark
              ? LiquidGlassTokens.metalFxCyan.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: dark ? 18 : 14,
          spreadRadius: dark ? -8 : 0,
          offset: const Offset(0, 6),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          splashFactory: NoSplash.splashFactory,
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (onDeleted != null) ...[
                  const SizedBox(width: 4),
                  InkResponse(
                    onTap: onDeleted,
                    radius: 14,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassDialog extends StatelessWidget {
  const LiquidGlassDialog({
    required this.title,
    required this.content,
    super.key,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!liquidGlassEnabled(context)) {
      return AlertDialog(title: title, content: content, actions: actions);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge!,
              child: title,
            ),
            const SizedBox(height: AppSpacing.md),
            content,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: action,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
