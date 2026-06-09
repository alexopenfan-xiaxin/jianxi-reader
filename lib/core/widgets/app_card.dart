import 'package:flutter/material.dart';
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
    final liquidGlass =
        context.watch<AppSettingsController>().liquidGlassEnabled;
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
              borderColor: Colors.white.withOpacity(dark ? 0.18 : 0.46),
              blurSigma: LiquidGlassTokens.effectBlurSigma,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.18 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
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
                      ? (_) => _controller.reverse()
                      : null,
                  onTapCancel: widget.onTap != null
                      ? () => _controller.reverse()
                      : null,
                  borderRadius: borderRadius,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: AppColors.primary.withOpacity(0.05),
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
                    widget.onTap != null ? (_) => _controller.reverse() : null,
                onTapCancel:
                    widget.onTap != null ? () => _controller.reverse() : null,
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
