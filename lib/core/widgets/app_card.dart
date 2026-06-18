import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';
import 'liquid_glass.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.forceClassic = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool forceClassic;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.fast,
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.press),
    );
  }

  void _springBack() {
    _controller.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 28),
        _controller.value,
        0,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass = !widget.forceClassic &&
        context.select<AppSettingsController, bool>(
            (s) => s.liquidGlassEnabled);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = liquidGlass ? 14.0 : AppRadii.lg;
    final borderRadius = BorderRadius.circular(radius);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: liquidGlass
          ? LiquidGlassSurface(
              borderRadius: borderRadius,
              color: liquidGlassCardColor(context),
              borderColor:
                  dark ? Colors.white.withOpacity(0.18) : Colors.transparent,
              blurSigma: LiquidGlassTokens.effectBlurSigma,
              chromaticEdge: dark,
              edgeHighlight: dark,
              innerHighlight: dark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.18 : 0.04),
                  blurRadius: dark ? 24 : 16,
                  offset: Offset(0, dark ? 12 : 8),
                ),
              ],
              child: Material(
                color: Colors.transparent,
                borderRadius: borderRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown:
                      widget.onTap != null ? (_) => _controller.forward() : null,
                  onTapUp: widget.onTap != null
                      ? (_) => _springBack()
                      : null,
                  onTapCancel: widget.onTap != null
                      ? _springBack
                      : null,
                  borderRadius: borderRadius,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
              ),
            )
          : Material(
              color: palette.card,
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              type: MaterialType.card,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown:
                    widget.onTap != null ? (_) => _controller.forward() : null,
                onTapUp:
                    widget.onTap != null ? (_) => _springBack() : null,
                onTapCancel:
                    widget.onTap != null ? _springBack : null,
                borderRadius: borderRadius,
                splashFactory: NoSplash.splashFactory,
                highlightColor: AppColors.primary.withOpacity(0.05),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: palette.hairline.withOpacity(0.72),
                    ),
                    borderRadius: borderRadius,
                  ),
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
              ),
            ),
    );
  }
}
