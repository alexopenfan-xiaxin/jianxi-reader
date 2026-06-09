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
  static const materialAlphaDark = 0.30;
  static const ultraThinAlpha = 0.15;
  static const cardAlphaLight = 0.68;
  static const cardAlphaDark = 0.42;
  static const headerAlphaLight = 0.54;
  static const headerAlphaDark = 0.36;
  static const shellRefractionAmount = 24.0;
}

class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    required this.child,
    super.key,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppRadii.pill),
    ),
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.blurSigma = LiquidGlassTokens.blurSigma,
    this.boxShadow = const [],
    this.innerHighlight = true,
    this.tintPrimary = false,
    this.chromaticEdge = true,
    this.edgeHighlight = true,
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = color ??
        (dark
            ? Colors.white.withOpacity(LiquidGlassTokens.materialAlphaDark)
            : palette.card.withOpacity(LiquidGlassTokens.materialAlphaLight));
    final resolvedBorder = borderColor ??
        (dark
            ? Colors.white.withOpacity(0.16)
            : Colors.white.withOpacity(0.42));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: resolvedColor,
              borderRadius: borderRadius,
              border: Border.all(color: resolvedBorder),
            ),
            child: Stack(
              children: [
                if (chromaticEdge)
                  _LiquidGlassChromaticEdge(borderRadius: borderRadius),
                if (innerHighlight)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(dark ? 0.20 : 0.38),
                              Colors.white.withOpacity(0.05),
                              Colors.black.withOpacity(dark ? 0.14 : 0.05),
                            ],
                            stops: const [0, 0.52, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (edgeHighlight)
                  _LiquidGlassEdgeHighlight(borderRadius: borderRadius),
                if (tintPrimary)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.12),
                              Colors.transparent,
                              AppColors.primaryFocus.withOpacity(0.08),
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
    );
  }
}

class _LiquidGlassChromaticEdge extends StatelessWidget {
  const _LiquidGlassChromaticEdge({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final intensity = LiquidGlassTokens.androidAberrationIntensity / 2;
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
                    color: const Color(0xFFFF3B5F).withOpacity(0.09),
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
                    color: const Color(0xFF34D5FF).withOpacity(0.10),
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
  const _LiquidGlassEdgeHighlight({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final opacity = LiquidGlassTokens.androidEdgeHighlightOpacity;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.12 * opacity),
                Colors.white.withOpacity(0.40 * opacity),
                Colors.white.withOpacity(0),
              ],
              stops: const [0, 0.28, 0.66, 1],
            ),
          ),
        ),
      ),
    );
  }
}

Color liquidGlassContainerColor(BuildContext context, {double? alpha}) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final resolvedAlpha = alpha ??
      (dark
          ? LiquidGlassTokens.materialAlphaDark
          : LiquidGlassTokens.materialAlphaLight);
  return (dark ? Colors.white : palette.card).withOpacity(resolvedAlpha);
}

Color liquidGlassCardColor(BuildContext context) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return (dark ? Colors.white : palette.card).withOpacity(
    dark ? LiquidGlassTokens.cardAlphaDark : LiquidGlassTokens.cardAlphaLight,
  );
}

Color liquidGlassHeaderColor(BuildContext context) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return (dark ? Colors.white : palette.card).withOpacity(
    dark ? LiquidGlassTokens.headerAlphaDark : LiquidGlassTokens.headerAlphaLight,
  );
}

bool liquidGlassEnabled(BuildContext context) {
  return context.watch<AppSettingsController>().liquidGlassEnabled;
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
      borderColor: borderColor ?? Colors.white.withOpacity(dark ? 0.18 : 0.46),
      blurSigma: LiquidGlassTokens.effectBlurSigma,
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.22 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 14),
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
        child: SafeArea(top: false, child: child),
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
        color: liquidGlassContainerColor(context, alpha: dark ? 0.24 : 0.34),
        borderColor: Colors.white.withOpacity(dark ? 0.18 : 0.42),
        blurSigma: LiquidGlassTokens.effectBlurSigma,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.16 : 0.06),
            blurRadius: 16,
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
    final foreground = selected ? AppColors.primary : palette.ink;
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      color: selected
          ? AppColors.primary.withOpacity(dark ? 0.18 : 0.12)
          : liquidGlassContainerColor(context, alpha: dark ? 0.20 : 0.32),
      borderColor: selected
          ? AppColors.primary.withOpacity(0.24)
          : Colors.white.withOpacity(dark ? 0.16 : 0.38),
      blurSigma: LiquidGlassTokens.effectBlurSigma,
      tintPrimary: selected,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.14 : 0.06),
          blurRadius: 14,
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
          highlightColor: AppColors.primary.withOpacity(0.05),
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
