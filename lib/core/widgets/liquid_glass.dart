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
/// `liquid_glass_widgets` shader pipeline; these tokens only pin the blur
/// budget per surface class and shared layout metrics.
class LiquidGlassTokens {
  // Glass blur presets per surface class.
  static const double chromeBlur = 24.0;
  static const double panelBlur = 18.0;
  static const double controlBlur = 12.0;

  // Shared glass thickness (drives refraction depth).
  static const double thickness = 14.0;

  // Floating bottom navigation layout.
  static const bottomBarHeight = 58.0;
  static const bottomBarPadding = 3.0;
  static const floatingBottomBarHeight = 64.0;
  static const floatingBottomBarPadding = 4.0;
  static const floatingBottomBarItemWidth = 76.0;
  static const floatingBottomBarIndicatorHeight = 56.0;
  static const floatingBottomBarPanelOffsetMax = 5.0;
}

/// A real liquid-glass surface backed by [AdaptiveGlass].
///
/// The shader pipeline supplies blur, refraction, Fresnel rim lighting and
/// soft elevation shadows, so callers only choose the tint ([color]), the
/// optional hairline ([borderColor]) and the quality tier. Use
/// [GlassQuality.premium] only for static chrome (app bars, navigation,
/// dialogs); scrollable content stays on the default [GlassQuality.standard].
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBlur = blur ??
        (quality == GlassQuality.premium
            ? LiquidGlassTokens.chromeBlur
            : LiquidGlassTokens.controlBlur);
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
        thickness: LiquidGlassTokens.thickness,
        glassColor: color ?? liquidGlassContainerColor(context),
        refractiveIndex: 1.15,
        chromaticAberration: 0.008,
        lightIntensity: dark ? 0.38 : 0.52,
        saturation: 1.4,
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
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    required this.child,
    super.key,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      color: color ?? liquidGlassCardColor(context),
      blur: LiquidGlassTokens.panelBlur,
      quality: GlassQuality.premium,
      child: child,
    );
  }
}

/// Floating glass sheet container for modal bottom sheets.
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
      borderColor: selected
          ? AppColors.primary.withValues(alpha: 0.26)
          : null,
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
