import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';

export 'package:liquid_glass_widgets/types/glass_quality.dart'
    show GlassQuality;

export 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        AdaptiveGlass,
        GlassCard,
        GlassChip,
        GlassContainer,
        GlassDialog,
        GlassDialogAction,
        GlassDivider,
        GlassGroupedSection,
        GlassIconButton,
        GlassIconButtonShape,
        GlassIsolationScope,
        GlassListTile,
        GlassTab,
        GlassTabBar,
        GlassToolbar,
        LiquidGlassSettings,
        LiquidRoundedSuperellipse;

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
  // Was 0.2: the fringe reads as a grey halo on a bright page.
  static const double chromaticAberration = 0.08;

  // Specular light budget before intensity scaling.
  static const double darkSpecular = 0.42;
  static const double lightSpecular = 0.55;

  // Ambient body darkening, before intensity scaling. The shaders add a fixed
  // floor on top of it (the premium path darkens by ~0.08 even at zero), so a
  // budget tuned for dark glass washes a bright page grey in light mode.
  static const double darkAmbient = 0.12;
  static const double lightAmbient = 0.03;

  // Full-perimeter edge highlight ring, before intensity scaling. The premium
  // shader renders no ring at ambientRim 0; ~1.5–2 reads as a clearly visible
  // but not gaudy highlight.
  // Was 2.0: the ring was wide enough to look like a fog band around every
  // surface except the bottom tab (which uses the package's own defaults).
  static const double edgeRim = 0.9;

  // Meniscus rim darkening, before intensity scaling. iOS light glass takes
  // its edge definition from the highlight ring, so a dark meniscus band over
  // a bright page reads as a grey outline; light mode keeps only a hint.
  static const double darkEdgeAbsorption = 0.10;
  // Light glass takes its edge from the highlight only; any dark meniscus over
  // a bright page reads as a grey outline.
  static const double lightEdgeAbsorption = 0.0;

  // Light-mode whitening veil, luminance gated by the package so text and
  // icons under the glass stay crisp. Without it a light surface can only mute
  // the bright backdrop it sits on and reads as a grey wash; dark mode leaves
  // it off because dark glass reads through the backdrop instead.
  static const double lightWhiten = 0.25;
  static const double darkWhiten = 0.0;

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

/// Semantic role of a glass surface.
///
/// The role owns two policy decisions so call sites do not repeat them: the
/// default blur budget and the quality tier. [AppGlassRole.staticChrome] and
/// [AppGlassRole.staticPanel] are the only roles allowed to render
/// [GlassQuality.premium]; anything that can move inside a tab, page
/// transition, scroll or drag stays on [GlassQuality.standard] to avoid the
/// premium backdrop-group black flash.
enum AppGlassRole {
  staticChrome,
  animatedChrome,
  staticPanel,
  draggedSurface,
  interactiveControl,
  groupedCard,
}

/// Single adapter between the app's curated intensity and the
/// `liquid_glass_widgets` material model.
///
/// Every glass surface in the app resolves its [LiquidGlassSettings] here.
/// [material] is a pure function so the intensity/quality policy is unit
/// testable; [build] only adds the context-dependent pieces (brightness, tint
/// and the stored intensity). Components that need a different blur budget
/// pass [blurOverride] instead of rebuilding the material chain.
class AppGlassSettings {
  const AppGlassSettings._();

  /// Default blur budget for [role], before intensity scaling.
  static double blurFor(AppGlassRole role) {
    switch (role) {
      case AppGlassRole.staticChrome:
      case AppGlassRole.animatedChrome:
        return LiquidGlassTokens.chromeBlur;
      case AppGlassRole.staticPanel:
      case AppGlassRole.draggedSurface:
        return LiquidGlassTokens.panelBlur;
      case AppGlassRole.interactiveControl:
      case AppGlassRole.groupedCard:
        return LiquidGlassTokens.controlBlur;
    }
  }

  /// Quality policy for [role].
  ///
  /// Premium is reserved for chrome and panels with no sliding or
  /// transforming ancestor. The premium shader tracks those transforms
  /// through its backdrop group and flashes black when the assumption is
  /// violated, so moving surfaces stay on the standard tier.
  static GlassQuality qualityFor(AppGlassRole role) {
    switch (role) {
      case AppGlassRole.staticChrome:
      case AppGlassRole.staticPanel:
        return GlassQuality.premium;
      case AppGlassRole.animatedChrome:
      case AppGlassRole.draggedSurface:
      case AppGlassRole.interactiveControl:
      case AppGlassRole.groupedCard:
        return GlassQuality.standard;
    }
  }

  /// Builds the full material for [role] from an explicit intensity.
  ///
  /// Kept free of [BuildContext] so the policy can be tested directly.
  static LiquidGlassSettings material({
    required AppGlassRole role,
    required double intensity,
    required Brightness brightness,
    required Color color,
    double? blurOverride,
  }) {
    final dark = brightness == Brightness.dark;
    final baseBlur = blurOverride ?? blurFor(role);
    final baseLight = dark
        ? LiquidGlassTokens.darkSpecular
        : LiquidGlassTokens.lightSpecular;
    final ambient = dark
        ? LiquidGlassTokens.darkAmbient
        : LiquidGlassTokens.lightAmbient;
    final edgeAbsorption = dark
        ? LiquidGlassTokens.darkEdgeAbsorption
        : LiquidGlassTokens.lightEdgeAbsorption;
    // The veil rides the shared depth scale so weak glass fades it out
    // instead of leaving a flat white lid on top of the backdrop.
    final whiten = LiquidGlassIntensity.scaleLight(
      dark ? LiquidGlassTokens.darkWhiten : LiquidGlassTokens.lightWhiten,
      intensity,
    );
    return LiquidGlassSettings(
      blur: LiquidGlassIntensity.scaleBlur(baseBlur, intensity),
      thickness: LiquidGlassIntensity.scaleThickness(
        LiquidGlassTokens.thickness,
        intensity,
      ),
      glassColor: LiquidGlassIntensity.scaleTint(color, intensity),
      refractiveIndex: LiquidGlassIntensity.refractiveIndex(intensity),
      chromaticAberration: LiquidGlassTokens.chromaticAberration,
      lightIntensity: LiquidGlassIntensity.scaleLight(baseLight, intensity),
      ambientStrength: ambient,
      ambientRim: LiquidGlassIntensity.scaleRim(
        LiquidGlassTokens.edgeRim,
        intensity,
      ),
      edgeAbsorption: LiquidGlassIntensity.scaleRim(edgeAbsorption, intensity),
      whitenStrength: whiten,
      whitenGated: true,
      saturation: LiquidGlassTokens.saturation,
    );
  }

  /// Resolves the material for a widget, honoring the stored intensity.
  static LiquidGlassSettings build(
    BuildContext context, {
    required AppGlassRole role,
    Color? color,
    double? blurOverride,
    double? intensityOverride,
  }) {
    // The curated intensity is a fixed value (the custom control was removed
    // in build 197), so a plain read keeps this helper usable from tap
    // callbacks where Provider forbids select().
    final intensity =
        intensityOverride ??
        context.read<AppSettingsController>().liquidGlassIntensityValue;
    return material(
      role: role,
      intensity: intensity,
      brightness: Theme.of(context).brightness,
      color: color ?? liquidGlassContainerColor(context),
      blurOverride: blurOverride,
    );
  }

  /// App-level fallback for library widgets that receive no explicit settings.
  ///
  /// App surfaces pass their own resolved [LiquidGlassSettings], so this is a
  /// safety net rather than the primary material source. It cannot be
  /// brightness-aware because it is installed once at startup; use [material]
  /// for anything that needs light/dark budgets.
  static LiquidGlassSettings fallbackGlobal() {
    return material(
      role: AppGlassRole.interactiveControl,
      intensity: AppSettingsController.liquidGlassIntensityDefault,
      brightness: Brightness.light,
      color: const Color(0x52FFFFFF),
    );
  }
}

/// A real liquid-glass surface backed by [AdaptiveGlass].
///
/// The shader pipeline supplies blur, refraction, Fresnel rim lighting and
/// soft elevation shadows, so callers only choose the tint ([color]), the
/// optional hairline ([borderColor]) and the quality tier. All material
/// channels (blur, tint, thickness, refractive index, specular light, the edge
/// rim, and the light-mode whitening veil) scale with the stored intensity
/// setting, and the channels that read differently on a bright page — ambient
/// darkening, meniscus rim darkening, whitening — are budgeted per brightness.
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
    // Legacy wrapper surfaces keep build 197's visual contract: premium
    // surfaces are static chrome, everything else is an interactive control.
    // New code picks its role via [AppGlassSettings] directly.
    final role = quality == GlassQuality.premium
        ? AppGlassRole.staticChrome
        : AppGlassRole.interactiveControl;
    final settings = AppGlassSettings.build(
      context,
      role: role,
      color: color,
      blurOverride: blur,
      intensityOverride: intensityOverride,
    );
    // Package shapes take a single radius; callers use circular radii.
    final radius = borderRadius.topLeft.x;
    return AdaptiveGlass(
      shape: LiquidRoundedSuperellipse(
        borderRadius: radius,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!, width: AppHairline.width),
      ),
      settings: settings,
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
/// settings cards. The surface is a component-library [GlassContainer]; the
/// tile itself stays non-interactive.
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
    return GlassContainer(
      width: size,
      height: size,
      shape: LiquidRoundedSuperellipse(
        borderRadius: radius,
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.20),
          width: AppHairline.width,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      settings: AppGlassSettings.build(
        context,
        role: AppGlassRole.interactiveControl,
        color: tint ?? AppColors.primary.withValues(alpha: 0.10),
      ),
      useOwnLayer: true,
      quality: AppGlassSettings.qualityFor(AppGlassRole.interactiveControl),
      child: Center(child: child),
    );
  }
}

/// Glass frame around standard Material text fields.
///
/// The field itself stays a normal Flutter [TextField] so keyboard, selection,
/// validation and autofocus behavior do not change; the component library
/// supplies the surrounding glass material. This matches the package's
/// documented composition rule: glass containers hold standard form controls.
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
    return GlassContainer(
      height: height,
      padding: padding,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius.topLeft.x),
      clipBehavior: Clip.antiAlias,
      settings: AppGlassSettings.build(
        context,
        role: AppGlassRole.interactiveControl,
        color: liquidGlassContainerColor(context, alpha: dark ? 0.14 : 0.30),
      ),
      useOwnLayer: true,
      quality: AppGlassSettings.qualityFor(AppGlassRole.interactiveControl),
      child: child,
    );
  }
}

/// Glass filter chip backed by the component library's [GlassChip].
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
    final selectedColor = AppColors.primary.withValues(
      alpha: dark ? 0.16 : 0.12,
    );
    return GlassChip(
      label: label,
      icon: icon == null ? null : Icon(icon, size: 17),
      onTap: onTap,
      onDeleted: onDeleted,
      selected: selected,
      selectedColor: selectedColor,
      iconColor: foreground,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: 0,
      ),
      deleteIcon: Semantics(
        label: '删除标签',
        button: true,
        child: Icon(Icons.close_rounded, size: 16, color: foreground),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      settings: AppGlassSettings.build(
        context,
        role: AppGlassRole.interactiveControl,
        color: selected
            ? selectedColor
            : liquidGlassContainerColor(context, alpha: dark ? 0.12 : 0.28),
      ),
      useOwnLayer: true,
      quality: AppGlassSettings.qualityFor(AppGlassRole.interactiveControl),
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
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        shape: const LiquidRoundedSuperellipse(borderRadius: 30),
        clipBehavior: Clip.antiAlias,
        settings: AppGlassSettings.build(
          context,
          role: AppGlassRole.staticPanel,
          color: liquidGlassCardColor(context),
          blurOverride: LiquidGlassTokens.panelBlur,
        ),
        useOwnLayer: true,
        // Dialog routes animate their child in; the premium tier tracks
        // transform changes through its backdrop group and can flash black.
        quality: AppGlassSettings.qualityFor(AppGlassRole.staticPanel),
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
