part of 'library_page.dart';

class _FixedLibraryHeader extends StatelessWidget {
  const _FixedLibraryHeader({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass = context.select<AppSettingsController, bool>(
      (settings) => settings.liquidGlassEnabled,
    );
    final headerContent = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const _LibraryHomeIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '首页',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${controller.allDocuments.length} 个文档',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            tooltip: '搜索文档',
            icon: Icons.search_rounded,
            onPressed: () => _openSearchPage(context),
          ),
          const SizedBox(width: 2),
          _HeaderIconButton(
            tooltip: '文档排序',
            icon: Icons.format_list_bulleted_rounded,
            onPressed: () => _showSortSheet(context),
          ),
        ],
      ),
    );

    if (liquidGlass) {
      // The header slides with the tab transition. Premium glass tracks
      // sliding transforms through its backdrop group and flashes black on
      // switch, so anything that moves stays on the standard tier.
      return LiquidGlassSurface(
        borderRadius: BorderRadius.circular(24),
        color: liquidGlassHeaderColor(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(
              bottom: BorderSide(
                color: palette.hairline.withValues(alpha: 0.20),
              ),
            ),
          ),
          child: headerContent,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.parchment.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: palette.hairline.withValues(alpha: 0.34)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: headerContent,
        ),
      ),
    );
  }

  void _openSearchPage(BuildContext context) {
    Navigator.of(context).push(
      appPageRoute<void>(
        transition: AppPageTransition.fadeThrough,
        builder: (context) => const _LibrarySearchPage(),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final controller = context.read<LibraryController>();
    showGlassActionSheet<void>(
      context: context,
      title: '文档排序',
      cancelLabel: '取消',
      settings: AppGlassSettings.build(context, role: AppGlassRole.staticPanel),
      quality: GlassQuality.standard,
      actions: [
        for (final mode in LibrarySortMode.values)
          GlassActionSheetAction(
            label: mode.label,
            icon: mode == controller.sortMode
                ? const Icon(Icons.check_rounded)
                : null,
            onPressed: () => controller.updateSortMode(mode),
          ),
      ],
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.selectedCount,
    required this.onClose,
    required this.onTags,
    required this.onRefresh,
    required this.onClearProgress,
    required this.onRemove,
  });

  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onTags;
  final VoidCallback onRefresh;
  final VoidCallback onClearProgress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '退出多选',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              '已选择 $selectedCount 个',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: '批量设置标签',
            onPressed: onTags,
            icon: const Icon(Icons.label_outline_rounded),
          ),
          IconButton(
            tooltip: '批量刷新',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '清除阅读进度',
            onPressed: onClearProgress,
            icon: const Icon(Icons.history_toggle_off_rounded),
          ),
          IconButton(
            tooltip: '批量移出',
            onPressed: onRemove,
            color: AppColors.error,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
        ],
      ),
    );

    if (liquidGlassEnabled(context)) {
      return LiquidGlassSurface(
        borderRadius: BorderRadius.circular(24),
        color: liquidGlassHeaderColor(context),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.parchment.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: palette.hairline.withValues(alpha: 0.34)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: content,
        ),
      ),
    );
  }
}

class _LibraryHomeIcon extends StatelessWidget {
  const _LibraryHomeIcon();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The header tile stays flat in both visual modes: the glass variant read
    // as a washed grey square over the light page.
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DocumentTypeIconPainter(
          primary: AppColors.primary,
          paper: palette.card,
          line: palette.ink,
        ),
      ),
    );
  }
}

class _DocumentTypeIconPainter extends CustomPainter {
  const _DocumentTypeIconPainter({
    required this.primary,
    required this.paper,
    required this.line,
  });

  final Color primary;
  final Color paper;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final backPaint = Paint()..color = primary.withValues(alpha: 0.18);
    final paperPaint = Paint()..color = paper.withValues(alpha: 0.92);
    final outlinePaint = Paint()
      ..color = primary.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final linePaint = Paint()
      ..color = line.withValues(alpha: 0.62)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.29, size.height * 0.22, 17, 24),
      const Radius.circular(5),
    );
    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.38, size.height * 0.29, 18, 25),
      const Radius.circular(5),
    );
    canvas.drawRRect(backRect, backPaint);
    canvas.drawRRect(frontRect, paperPaint);
    canvas.drawRRect(frontRect, outlinePaint);

    final foldPath = Path()
      ..moveTo(size.width * 0.61, size.height * 0.29)
      ..lineTo(size.width * 0.76, size.height * 0.44)
      ..lineTo(size.width * 0.61, size.height * 0.44)
      ..close();
    canvas.drawPath(foldPath, Paint()..color = primary.withValues(alpha: 0.18));
    canvas.drawLine(
      Offset(size.width * 0.61, size.height * 0.30),
      Offset(size.width * 0.75, size.height * 0.44),
      outlinePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, size.height * 0.54),
      Offset(size.width * 0.67, size.height * 0.54),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, size.height * 0.65),
      Offset(size.width * 0.62, size.height * 0.65),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DocumentTypeIconPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.paper != paper ||
        oldDelegate.line != line;
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassIconButton(
        icon: Icon(icon, size: 22, color: context.palette.ink),
        onPressed: onPressed,
        size: 40,
        shape: GlassIconButtonShape.roundedSquare,
        borderRadius: 13,
        semanticLabel: tooltip,
        settings: AppGlassSettings.build(
          context,
          role: AppGlassRole.interactiveControl,
        ),
        useOwnLayer: true,
        quality: AppGlassSettings.qualityFor(AppGlassRole.interactiveControl),
      ),
    );
  }
}

class _FloatingImportButton extends StatelessWidget {
  const _FloatingImportButton({
    required this.importing,
    required this.onPressed,
    super.key,
  });

  final bool importing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !importing;
    final fillOpacity = enabled ? 0.42 : 0.26;
    final button = Material(
      color: liquidGlassEnabled(context)
          ? Colors.transparent
          : AppColors.primary.withValues(alpha: fillOpacity),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.emphasized,
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: AppMotion.release,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: importing
                  ? const SizedBox.square(
                      key: ValueKey('import_spinner'),
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      key: ValueKey('import_icon'),
                      Icons.add_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: enabled ? 0.30 : 0.12),
            blurRadius: enabled ? 34 : 18,
            spreadRadius: enabled ? 1 : 0,
            offset: const Offset(0, 11),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: enabled ? 0.18 : 0.08),
            blurRadius: enabled ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Tooltip(
        message: '导入文档',
        child: liquidGlassEnabled(context)
            ? LiquidGlassSurface(
                borderRadius: BorderRadius.circular(30),
                color: AppColors.primary.withValues(alpha: fillOpacity),
                interactive: true,
                child: button,
              )
            : ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: button,
                ),
              ),
      ),
    );
  }
}
