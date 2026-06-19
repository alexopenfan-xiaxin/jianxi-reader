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
      return LiquidGlassSurface(
        borderRadius: BorderRadius.circular(24),
        color: liquidGlassHeaderColor(context),
        borderColor: Colors.white.withOpacity(0.16),
        blurSigma: LiquidGlassTokens.effectBlurSigma,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(
              bottom: BorderSide(color: palette.hairline.withOpacity(0.20)),
            ),
          ),
          child: headerContent,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.parchment.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(color: palette.hairline.withOpacity(0.34)),
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
      appPageRoute<void>(builder: (context) => const _LibrarySearchPage()),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.36),
      builder: (context) => const _SortSheet(),
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
        borderColor: Colors.white.withOpacity(0.16),
        blurSigma: LiquidGlassTokens.effectBlurSigma,
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.parchment.withOpacity(0.94),
        border: Border(
          bottom: BorderSide(color: palette.hairline.withOpacity(0.34)),
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
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.14),
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
    final backPaint = Paint()..color = primary.withOpacity(0.18);
    final paperPaint = Paint()..color = paper.withOpacity(0.92);
    final outlinePaint = Paint()
      ..color = primary.withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final linePaint = Paint()
      ..color = line.withOpacity(0.62)
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
    canvas.drawPath(foldPath, Paint()..color = primary.withOpacity(0.18));
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 29),
      color: context.palette.ink,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
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
          : AppColors.primary.withOpacity(fillOpacity),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withOpacity(0.34)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: importing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.add_rounded,
                    size: 32,
                    color: Colors.white,
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
            color: AppColors.primary.withOpacity(enabled ? 0.30 : 0.12),
            blurRadius: enabled ? 34 : 18,
            spreadRadius: enabled ? 1 : 0,
            offset: const Offset(0, 11),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(enabled ? 0.18 : 0.08),
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
                color: AppColors.primary.withOpacity(fillOpacity),
                borderColor: Colors.white.withOpacity(0.34),
                blurSigma: LiquidGlassTokens.effectBlurSigma,
                tintPrimary: true,
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

class _SortSheet extends StatelessWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryController>(
      builder: (context, controller, _) {
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '文档排序',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final mode in LibrarySortMode.values)
              _SortOptionTile(
                mode: mode,
                selected: controller.sortMode == mode,
                onTap: () {
                  controller.updateSortMode(mode);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '取消',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        );

        if (liquidGlassEnabled(context)) {
          return LiquidGlassSheetPanel(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            borderRadius: BorderRadius.circular(42),
            child: content,
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(42),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final LibrarySortMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: Text(
            mode.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.primary : context.palette.hairline,
              width: selected ? 5 : 2,
            ),
          ),
        ),
      ],
    );

    if (liquidGlassEnabled(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: LiquidGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? AppColors.primary.withOpacity(0.10)
              : liquidGlassContainerColor(context, alpha: 0.18),
          borderColor: selected
              ? AppColors.primary.withOpacity(0.22)
              : Colors.white.withOpacity(0.28),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              splashFactory: NoSplash.splashFactory,
              child: SizedBox(height: 62, child: row),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.palette.hairline),
          ),
        ),
        child: row,
      ),
    );
  }
}
