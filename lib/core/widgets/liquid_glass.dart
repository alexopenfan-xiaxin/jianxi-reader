import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';

export 'package:liquid_glass_widgets/types/glass_quality.dart'
    show GlassQuality;

/// Liquid glass design constants.
///
/// Glass visuals (blur, refraction, lighting, shadows) are rendered by the
/// `liquid_glass_widgets` shader pipeline; these tokens pin the per-surface
/// blur budget and the refraction/highlight material, all of which the user
/// intensity then scales. Refraction needs real depth to read at all: the 2D
/// shader benchmarks its rim against a neutral thickness of 10 and the premium
/// shader multiplies thickness by dpr/3, so values at or below ~7 render as a
/// flat frosted lens with no visible bending or rim.
class LiquidGlassTokens {
  // Glass blur presets per surface class, before intensity scaling.
  static const double chromeBlur = 20.0;
  static const double panelBlur = 14.0;
  static const double controlBlur = 8.0;

  // Shared glass thickness (drives refraction depth and rim width).
  static const double thickness = 16.0;

  // Chromatic fringing along the refracted edge.
  static const double chromaticAberration = 0.010;

  // Specular light budget before intensity scaling.
  static const double darkSpecular = 0.42;
  static const double lightSpecular = 0.55;
  static const double ambientStrength = 0.12;

  // Full-perimeter edge highlight ring and meniscus rim darkening, before
  // intensity scaling. The premium shader renders no ring at ambientRim 0;
  // ~1.5–2 reads as a clearly visible but not gaudy highlight.
  static const double edgeRim = 2.0;
  static const double edgeAbsorption = 0.12;

  static const double saturation = 1.12;

  // Floating bottom navigation layout.
  static const bottomBarHeight = 58.0;
  static const bottomBarPadding = 3.0;
  static const floatingBottomBarHeight = 64.0;
  static const floatingBottomBarPadding = 4.0;
  static const floatingBottomBarItemWidth = 76.0;
  static const floatingBottomBarIndicatorHeight = 56.0;
  static const floatingBottomBarPanelOffsetMax = 5.0;
}

/// Scales every glass material channel by the user's intensity (0.0–1.0):
/// blur, tint, refraction depth, refractive index, specular light and the
/// edge-highlight ring. Scaling the full material is what makes the intensity
/// slider visibly change the glass — blur and tint alone read as almost no
/// change on surfaces whose look is dominated by refraction.
///
/// iOS liquid glass stays legible at low intensity: blur eases off gently
/// while tint, highlights and the rim fade faster, so weak glass reads nearly
/// clear instead of collapsing into a flat frosted box.
class LiquidGlassIntensity {
  const LiquidGlassIntensity._();

  static const double _minBlurScale = 0.30;
  static const double _minAlphaScale = 0.20;
  static const double _minBlur = 1.0;

  static double blurScale(double intensity) {
    final t = intensity.clamp(0.0, 1.0).toDouble();
    return _minBlurScale + (1 - _minBlurScale) * t;
  }

  static double alphaScale(double intensity) {
    final t = intensity.clamp(0.0, 1.0).toDouble();
    return _minAlphaScale + (1 - _minAlphaScale) * t;
  }

  static double scaleBlur(double baseBlur, double intensity) {
    final scaled = baseBlur * blurScale(intensity);
    return scaled < _minBlur ? _minBlur : scaled;
  }

  static Color scaleTint(Color color, double intensity) {
    final scaled = color.a * alphaScale(intensity);
    return color.withValues(alpha: scaled.clamp(0.0, 1.0).toDouble());
  }

  /// Shared material-depth scale for refraction thickness and specular
  /// light: depth and highlights ease off faster than blur.
  static double depthScale(double intensity) {
    final t = intensity.clamp(0.0, 1.0).toDouble();
    return 0.45 + 0.55 * t;
  }

  static double scaleThickness(double baseThickness, double intensity) {
    return baseThickness * depthScale(intensity);
  }

  static double scaleLight(double baseLight, double intensity) {
    return baseLight * depthScale(intensity);
  }

  /// Edge-highlight ring scale; the ring fades out fastest of all so weak
  /// glass reads clear instead of outlined.
  static double scaleRim(double baseRim, double intensity) {
    final t = intensity.clamp(0.0, 1.0).toDouble();
    return baseRim * (0.20 + 0.80 * t);
  }

  /// Refractive index lerps from a near-flat lens (1.05) at zero intensity
  /// to a pronounced one (1.42) at full intensity.
  static double refractiveIndex(double intensity) {
    final t = intensity.clamp(0.0, 1.0).toDouble();
    return 1.05 + 0.37 * t;
  }
}

/// A real liquid-glass surface backed by [AdaptiveGlass].
///
/// The shader pipeline supplies blur, refraction, Fresnel rim lighting and
/// soft elevation shadows, so callers only choose the tint ([color]), the
/// optional hairline ([borderColor]) and the quality tier. All material
/// channels (blur, tint, thickness, refractive index, specular light, edge
/// rim) scale with the stored intensity setting.
///
/// Quality tiers: [GlassQuality.premium] is only safe for chrome that never
/// moves on screen — premium tracks transforms through its backdrop group
/// and flashes black under a sliding ancestor. Anything inside a tab or page
/// transition (page headers, app bars, the bottom nav) must stay on the
/// default [GlassQuality.standard], which renders through a plain
/// [BackdropFilter] and is transform-safe.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    required this.child,
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill)),
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.blur,
    this.quality = GlassQuality.standard,
    this.interactive = false,
    this.intensityOverride,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  /// Optional tint for the glass; defaults to [liquidGlassContainerColor].
  final Color? color;

  /// Optional 1px hairline drawn on the shape boundary.
  final Color? borderColor;

  /// Overrides the blur preset (see [LiquidGlassTokens]).
  final double? blur;

  final GlassQuality quality;

  /// Marks press-scale surfaces so the fallback path skips backdrop relayout.
  final bool interactive;

  /// Bypasses the stored intensity setting, used by the intensity slider's
  /// live preview so it can render a candidate value before it is committed.
  final double? intensityOverride;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final intensity =
        intensityOverride ??
        context.select<AppSettingsController, double>(
          (settings) => settings.liquidGlassIntensityValue,
        );
    final baseBlur =
        blur ??
        (quality == GlassQuality.premium
            ? LiquidGlassTokens.chromeBlur
            : LiquidGlassTokens.controlBlur);
    final effectiveBlur = LiquidGlassIntensity.scaleBlur(baseBlur, intensity);
    final tint = LiquidGlassIntensity.scaleTint(
      color ?? liquidGlassContainerColor(context),
      intensity,
    );
    final baseLight = dark
        ? LiquidGlassTokens.darkSpecular
        : LiquidGlassTokens.lightSpecular;
    // Package shapes take a single radius; callers use circular radii.
    final radius = borderRadius.topLeft.x;
    return AdaptiveGlass(
      shape: LiquidRoundedSuperellipse(
        borderRadius: radius,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!, width: 1),
      ),
      settings: LiquidGlassSettings(
        blur: effectiveBlur,
        thickness: LiquidGlassIntensity.scaleThickness(
          LiquidGlassTokens.thickness,
          intensity,
        ),
        glassColor: tint,
        refractiveIndex: LiquidGlassIntensity.refractiveIndex(intensity),
        chromaticAberration: LiquidGlassTokens.chromaticAberration,
        lightIntensity: LiquidGlassIntensity.scaleLight(baseLight, intensity),
        ambientStrength: LiquidGlassTokens.ambientStrength,
        ambientRim: LiquidGlassIntensity.scaleRim(
          LiquidGlassTokens.edgeRim,
          intensity,
        ),
        edgeAbsorption: LiquidGlassIntensity.scaleRim(
          LiquidGlassTokens.edgeAbsorption,
          intensity,
        ),
        saturation: LiquidGlassTokens.saturation,
      ),
      quality: quality,
      isInteractive: interactive,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Tint for generic glass chrome. The light mode blends the card color;
/// dark mode uses a faint white veil so content stays legible.
Color liquidGlassContainerColor(BuildContext context, {double? alpha}) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) {
    return Colors.white.withValues(alpha: alpha ?? 0.10);
  }
  return palette.card.withValues(alpha: alpha ?? 0.32);
}

/// Tint for glass cards in lists and grids.
Color liquidGlassCardColor(BuildContext context) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) {
    return Colors.white.withValues(alpha: 0.07);
  }
  return palette.card.withValues(alpha: 0.62);
}

/// Tint for glass toolbars and headers.
Color liquidGlassHeaderColor(BuildContext context) {
  final palette = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) {
    return Colors.white.withValues(alpha: 0.09);
  }
  return palette.card.withValues(alpha: 0.52);
}

bool liquidGlassEnabled(BuildContext context) {
  return context.select<AppSettingsController, bool>(
    (s) => s.liquidGlassEnabled,
  );
}

bool readLiquidGlassEnabled(BuildContext context) {
  return context.read<AppSettingsController>().liquidGlassEnabled;
}

/// Elevated glass panel used by dialogs, sheets and popovers.
///
/// Defaults to [GlassQuality.premium], which suits static chrome. Pass
/// [GlassQuality.standard] for anything that moves or scrolls — a dragged
/// sheet re-captures its backdrop every frame, and the premium path is far
/// too expensive to pay per frame.
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    required this.child,
    super.key,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
    this.color,
    this.quality = GlassQuality.premium,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      color: color ?? liquidGlassCardColor(context),
      blur: LiquidGlassTokens.panelBlur,
      quality: quality,
      child: child,
    );
  }
}

/// Floating glass sheet container for modal bottom sheets.
///
/// Sheets are dragged, so callers should pass [GlassQuality.standard] (the
/// default here) unless the sheet is fully static.
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
    this.quality = GlassQuality.standard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: LiquidGlassPanel(
        padding: padding,
        borderRadius: borderRadius,
        quality: quality,
        child: SafeArea(
          top: false,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// Glass replacement for the small tinted icon tiles used in headers and
/// settings cards. The classic variant is a flat primary-tinted box; glass
/// mode keeps the same silhouette with a real translucent surface.
class LiquidGlassIconTile extends StatelessWidget {
  const LiquidGlassIconTile({
    required this.child,
    super.key,
    this.size = 48,
    this.radius = 13,
    this.tint,
  });

  final Widget child;
  final double size;
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(radius),
        color: tint ?? AppColors.primary.withValues(alpha: 0.10),
        borderColor: AppColors.primary.withValues(alpha: 0.20),
        child: Center(child: child),
      ),
    );
  }
}

/// Glass frame around app-bar text fields.
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
        color: liquidGlassContainerColor(context, alpha: dark ? 0.14 : 0.30),
        child: child,
      ),
    );
  }
}

/// Glass filter chip with selection state.
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
          ? AppColors.primary.withValues(alpha: dark ? 0.16 : 0.12)
          : liquidGlassContainerColor(context, alpha: dark ? 0.12 : 0.28),
      borderColor: selected ? AppColors.primary.withValues(alpha: 0.26) : null,
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

/// Dialog that switches between a plain [AlertDialog] and a glass panel
/// depending on the liquid-glass visual mode.
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
