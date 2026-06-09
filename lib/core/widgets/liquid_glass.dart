import 'dart:ui';

import 'package:flutter/material.dart';

import '../design_tokens.dart';

class LiquidGlassTokens {
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
  static const bilipaiTunedBlurSigma = 4.0;
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
                              Colors.white.withOpacity(dark ? 0.14 : 0.34),
                              Colors.white.withOpacity(0.04),
                              Colors.black.withOpacity(dark ? 0.10 : 0.03),
                            ],
                            stops: const [0, 0.52, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
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
