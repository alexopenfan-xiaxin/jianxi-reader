import 'package:flutter/material.dart';

import '../design_tokens.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
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
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    final borderRadius = BorderRadius.circular(AppRadii.lg);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Material(
        color: palette.card,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        type: MaterialType.card,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
          onTapUp: widget.onTap != null
              ? (_) => _controller.reverse()
              : null,
          onTapCancel: widget.onTap != null
              ? () => _controller.reverse()
              : null,
          borderRadius: borderRadius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: palette.hairline.withValues(alpha: 0.6),
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
