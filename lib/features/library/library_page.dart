import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/haptic_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/liquid_glass.dart';
import '../reader/reader_page.dart';
import 'document_actions.dart';
import 'document_entry.dart';
import 'library_controller.dart';

enum _DocumentMenuAction { rename, tags, remove }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  bool _hasPlayedInitialListAnimation = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: AppMotion.slow,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<LibraryController>(
        builder: (context, controller, _) {
          final settings = context.select<AppSettingsController, LibraryViewMode>(
            (s) => s.libraryViewMode,
          );
          if (!_hasPlayedInitialListAnimation &&
              controller.documents.isNotEmpty) {
            _hasPlayedInitialListAnimation = true;
            _staggerController.reset();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _staggerController.forward();
              }
            });
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      82,
                      AppSpacing.lg,
                      118,
                    ),
                    children: [
                      if (controller.errorMessage != null) ...[
                        _ErrorBanner(message: controller.errorMessage!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _LibraryAnimatedContent(
                        controller: controller,
                        viewMode: settings,
                        staggerController: _staggerController,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _FixedLibraryHeader(controller: controller),
              ),
              Positioned(
                right: AppSpacing.lg,
                bottom: 86,
                child: _FloatingImportButton(
                  key: const ValueKey('import_button'),
                  importing: controller.isImporting,
                  onPressed: () => _importDocuments(context, controller),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importDocuments(
    BuildContext context,
    LibraryController controller,
  ) {
    return _importAndMaybeOpen(context, controller);
  }
}

Future<void> _importAndMaybeOpen(
  BuildContext context,
  LibraryController controller,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final documents = await controller.importExternalDocuments();
  if (!context.mounted || documents.isEmpty) {
    return;
  }
  HapticService.selectionClick();
  if (documents.length > 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 ${documents.length} 个文档')),
    );
    return;
  }
  await _openReader(context, documents.single);
  if (context.mounted) {
    await controller.loadDocuments();
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  const _StaggeredFadeIn({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= 12) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final delay = index * 0.06;
        final t = ((controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _LibraryAnimatedContent extends StatelessWidget {
  const _LibraryAnimatedContent({
    required this.controller,
    required this.viewMode,
    required this.staggerController,
  });

  final LibraryController controller;
  final LibraryViewMode viewMode;
  final AnimationController staggerController;

  @override
  Widget build(BuildContext context) {
    final contentKey = ValueKey(
      '${controller.isLoading}:'
      '${controller.allDocuments.length}:'
      '${controller.documents.length}:'
      '${viewMode.name}',
    );

    return AnimatedSwitcher(
      duration: AppMotion.normal,
      reverseDuration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: contentKey,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (controller.isLoading) {
      return const _AnimatedStateShell(child: _LoadingState());
    }
    if (controller.allDocuments.isEmpty) {
      return const _AnimatedStateShell(child: _EmptyState());
    }
    if (controller.documents.isEmpty) {
      return const _AnimatedStateShell(child: _NoResultsState());
    }
    if (viewMode == LibraryViewMode.shelf) {
      return _ShelfGrid(documents: controller.documents);
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.documents.length,
      itemBuilder: (context, index) {
        return _StaggeredFadeIn(
          index: index,
          controller: staggerController,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DocumentTile(document: controller.documents[index]),
          ),
        );
      },
    );
  }
}

class _AnimatedStateShell extends StatelessWidget {
  const _AnimatedStateShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppMotion.normal,
      curve: AppMotion.enter,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _FixedLibraryHeader extends StatelessWidget {
  const _FixedLibraryHeader({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass =
        context.watch<AppSettingsController>().liquidGlassEnabled;
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

class _LibrarySearchPage extends StatefulWidget {
  const _LibrarySearchPage();

  @override
  State<_LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends State<_LibrarySearchPage> {
  late final TextEditingController _controller;
  late final LibraryController _libraryController;

  @override
  void initState() {
    super.initState();
    _libraryController = context.read<LibraryController>();
    _controller = TextEditingController(text: _libraryController.searchQuery);
  }

  @override
  void dispose() {
    _libraryController.updateSearchQuery('');
    _libraryController.updateSelectedTag(null);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLiquidGlass = liquidGlassEnabled(context);
    return Scaffold(
      backgroundColor: palette.parchment,
      body: SafeArea(
        child: Consumer<LibraryController>(
          builder: (context, controller, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: isLiquidGlass
                          ? LiquidGlassTextFieldFrame(
                              height: 52,
                              child: _LibrarySearchTextField(
                                controller: _controller,
                                libraryController: controller,
                              ),
                            )
                          : Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: palette.dividerSoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
                              ),
                              child: _LibrarySearchTextField(
                                controller: _controller,
                                libraryController: controller,
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '搜索指定标签',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.muted,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SearchTagWrap(controller: controller),
                if (controller.documents.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  ...controller.documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _SearchResultTile(document: document),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchTagWrap extends StatelessWidget {
  const _SearchTagWrap({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final tags = controller.tags;
    if (tags.isEmpty) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: const [_SearchTagChip(label: '无标签', selected: true)],
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _SearchTagChip(
          label: '全部',
          selected: controller.selectedTag == null,
          onTap: () => controller.updateSelectedTag(null),
        ),
        for (final tag in tags)
          _SearchTagChip(
            label: tag,
            selected: controller.selectedTag == tag,
            onTap: () => controller.updateSelectedTag(tag),
          ),
      ],
    );
  }
}

class _LibrarySearchTextField extends StatelessWidget {
  const _LibrarySearchTextField({
    required this.controller,
    required this.libraryController,
  });

  final TextEditingController controller;
  final LibraryController libraryController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('library_search_field'),
      controller: controller,
      autofocus: true,
      onChanged: libraryController.updateSearchQuery,
      decoration: InputDecoration(
        hintText: '搜索文档',
        prefixIcon: const Icon(Icons.search_rounded),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        suffixIcon: libraryController.searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: '清除搜索',
                onPressed: () {
                  controller.clear();
                  libraryController.updateSearchQuery('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _SearchTagChip extends StatelessWidget {
  const _SearchTagChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : context.palette.ink;
    if (liquidGlassEnabled(context)) {
      return LiquidGlassChip(
        label: label,
        selected: selected,
        icon: Icons.label_outline_rounded,
        onTap: onTap,
      );
    }
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.label_outline_rounded, size: 18),
      label: Text(label),
      backgroundColor: selected
          ? AppColors.primary.withOpacity(0.12)
          : context.palette.dividerSoft,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: 0,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _openReader(context, document),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(document.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _documentSummary(document),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.palette.muted,
                  letterSpacing: 0,
                ),
          ),
        ],
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LibraryStateIllustration(
            kind: _LibraryStateArtKind.warningPage,
            size: 42,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

enum _LibraryStateArtKind { emptyPage, searchPage, warningPage }

class _LibraryStateIllustration extends StatelessWidget {
  const _LibraryStateIllustration({
    required this.kind,
    this.size = 80,
  });

  final _LibraryStateArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LibraryStateIllustrationPainter(
          kind: kind,
          primary: AppColors.primary,
          line: context.palette.ink,
          muted: context.palette.muted,
          error: AppColors.error,
        ),
      ),
    );
  }
}

class _LibraryStateIllustrationPainter extends CustomPainter {
  const _LibraryStateIllustrationPainter({
    required this.kind,
    required this.primary,
    required this.line,
    required this.muted,
    required this.error,
  });

  final _LibraryStateArtKind kind;
  final Color primary;
  final Color line;
  final Color muted;
  final Color error;

  @override
  void paint(Canvas canvas, Size size) {
    final pagePaint = Paint()
      ..color = primary.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = line.withOpacity(0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = kind == _LibraryStateArtKind.warningPage ? error : primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.04
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.14,
        size.width * 0.50,
        size.height * 0.66,
      ),
      Radius.circular(size.shortestSide * 0.08),
    );
    canvas.drawRRect(page, pagePaint);
    canvas.drawRRect(page, linePaint);

    final foldPath = Path()
      ..moveTo(size.width * 0.59, size.height * 0.14)
      ..lineTo(size.width * 0.72, size.height * 0.27)
      ..lineTo(size.width * 0.59, size.height * 0.27)
      ..close();
    canvas.drawPath(foldPath, Paint()..color = primary.withOpacity(0.12));
    canvas.drawPath(foldPath, linePaint);

    for (final y in [0.40, 0.52, 0.64]) {
      canvas.drawLine(
        Offset(size.width * 0.32, size.height * y),
        Offset(size.width * 0.62, size.height * y),
        linePaint..color = muted.withOpacity(0.45),
      );
    }

    switch (kind) {
      case _LibraryStateArtKind.emptyPage:
        canvas.drawLine(
          Offset(size.width * 0.36, size.height * 0.86),
          Offset(size.width * 0.66, size.height * 0.86),
          accentPaint,
        );
      case _LibraryStateArtKind.searchPage:
        canvas.drawCircle(
          Offset(size.width * 0.70, size.height * 0.68),
          size.shortestSide * 0.13,
          accentPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.79, size.height * 0.77),
          Offset(size.width * 0.90, size.height * 0.88),
          accentPaint,
        );
      case _LibraryStateArtKind.warningPage:
        canvas.drawLine(
          Offset(size.width * 0.80, size.height * 0.56),
          Offset(size.width * 0.80, size.height * 0.70),
          accentPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.80, size.height * 0.78),
          size.shortestSide * 0.015,
          Paint()..color = error,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LibraryStateIllustrationPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.primary != primary ||
        oldDelegate.line != line ||
        oldDelegate.muted != muted ||
        oldDelegate.error != error;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      key: const ValueKey('empty_library'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LibraryStateIllustration(
              kind: _LibraryStateArtKind.emptyPage,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('未有简牍', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                '选择一个 Markdown 或 HTML 文档开始阅读',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: palette.muted,
                      height: 1.55,
                      letterSpacing: 0,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                final controller = context.read<LibraryController>();
                _importFirstDocument(context, controller);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('导入文档'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFirstDocument(
    BuildContext context,
    LibraryController controller,
  ) async {
    await _importAndMaybeOpen(context, controller);
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LibraryStateIllustration(
              kind: _LibraryStateArtKind.searchPage,
              size: 72,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '未寻得匹配文档',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfGrid extends StatelessWidget {
  const _ShelfGrid({required this.documents});

  final List<DocumentEntry> documents;

  static const _grid2Col = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: AppSpacing.sm,
    mainAxisSpacing: AppSpacing.sm,
    childAspectRatio: 0.72,
  );
  static const _grid3Col = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: AppSpacing.sm,
    mainAxisSpacing: AppSpacing.sm,
    childAspectRatio: 0.72,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          key: const ValueKey('library_shelf_grid'),
          itemCount: documents.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: columns == 2 ? _grid2Col : _grid3Col,
          itemBuilder: (context, index) {
            return _ShelfDocumentCard(document: documents[index]);
          },
        );
      },
    );
  }
}

class _ShelfDocumentCard extends StatefulWidget {
  const _ShelfDocumentCard({required this.document});

  final DocumentEntry document;

  @override
  State<_ShelfDocumentCard> createState() => _ShelfDocumentCardState();
}

class _ShelfDocumentCardState extends State<_ShelfDocumentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: AppMotion.fast,
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: AppMotion.press),
    );
  }

  void _springBack() {
    _pressController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 28),
        _pressController.value,
        0,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cover = _CoverStyle.forDocument(widget.document);
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _pressAnimation.value, child: child);
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDocument(context),
          onLongPress: () => _showShelfActions(context),
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) => _springBack(),
          onTapCancel: _springBack,
          splashFactory: NoSplash.splashFactory,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cover.start, cover.end],
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: cover.border.withOpacity(0.55)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    color: cover.spine.withOpacity(0.72),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ShelfTypeMark(document: widget.document),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        widget.document.name,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: cover.foreground,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _DocumentMetaRow(
                        tags: widget.document.tags,
                        summary: _documentSummary(widget.document),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = context.read<LibraryController>();
    await _openReader(context, widget.document);
    if (context.mounted) {
      await controller.loadDocuments();
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    _DocumentMenuAction action,
  ) async {
    switch (action) {
      case _DocumentMenuAction.rename:
        await showRenameDocumentDialog(context, widget.document);
      case _DocumentMenuAction.tags:
        await _showTagEditor(context, widget.document);
      case _DocumentMenuAction.remove:
        await removeDocumentFromLibrary(context, widget.document);
    }
  }

  Future<void> _showShelfActions(BuildContext context) async {
    _springBack();
    final action = await _showGlassDocumentMenu(context, widget.document);
    if (action != null && mounted) {
      await _handleAction(context, action);
    }
  }
}

class _ShelfTypeMark extends StatelessWidget {
  const _ShelfTypeMark({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    final isMd = document.type == DocumentType.markdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMd ? Icons.description_rounded : Icons.code_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            document.type.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}

class _CoverStyle {
  const _CoverStyle({
    required this.start,
    required this.end,
    required this.spine,
    required this.border,
    required this.foreground,
  });

  final Color start;
  final Color end;
  final Color spine;
  final Color border;
  final Color foreground;

  static const _styles = [
    _CoverStyle(
      start: Color(0xFF2F5C8F),
      end: Color(0xFF16324F),
      spine: Color(0xFF0E2238),
      border: Color(0xFF5E89B9),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF7A5C38),
      end: Color(0xFF3E2F22),
      spine: Color(0xFF2A2018),
      border: Color(0xFFB18A5B),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF346B57),
      end: Color(0xFF183D32),
      spine: Color(0xFF102A23),
      border: Color(0xFF69A58B),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF6A4D7D),
      end: Color(0xFF33243E),
      spine: Color(0xFF241A2C),
      border: Color(0xFFA487B7),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF8A4B42),
      end: Color(0xFF472620),
      spine: Color(0xFF301A16),
      border: Color(0xFFC17A70),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF4C6171),
      end: Color(0xFF24313A),
      spine: Color(0xFF182129),
      border: Color(0xFF8199AA),
      foreground: Colors.white,
    ),
  ];

  static _CoverStyle forDocument(DocumentEntry document) {
    final source = '${document.path}/${document.name}/${document.type.name}';
    final hash = source.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    return _styles[hash % _styles.length];
  }
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({required this.document});

  final DocumentEntry document;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _hoverAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _hoverController, curve: AppMotion.emphasized),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass = context.select<AppSettingsController, bool>(
      (s) => s.liquidGlassEnabled,
    );
    final forceClassicCard = liquidGlass &&
        Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _hoverAnim,
      builder: (context, child) => Transform.scale(
        scale: _hoverAnim.value,
        child: child,
      ),
      child: AppCard(
        onTap: () => _openDocument(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        forceClassic: forceClassicCard,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(document: widget.document),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.document.isReferenced)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.xxs,
                                ),
                                child: Icon(
                                  Icons.link_rounded,
                                  size: 14,
                                  color: palette.muted,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                widget.document.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        _DocumentMetaRow(
                          tags: widget.document.tags,
                          summary: _documentSummary(widget.document),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: '文档操作',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () async {
                final action = await _showGlassDocumentMenu(
                  context,
                  widget.document,
                );
                if (action != null && context.mounted) {
                  await _handleAction(context, action);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = context.read<LibraryController>();
    await _openReader(context, widget.document);
    if (context.mounted) {
      await controller.loadDocuments();
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    _DocumentMenuAction action,
  ) async {
    switch (action) {
      case _DocumentMenuAction.rename:
        await showRenameDocumentDialog(context, widget.document);
      case _DocumentMenuAction.tags:
        await _showTagEditor(context, widget.document);
      case _DocumentMenuAction.remove:
        await removeDocumentFromLibrary(context, widget.document);
    }
  }
}

Future<_DocumentMenuAction?> _showGlassDocumentMenu(
  BuildContext context,
  DocumentEntry document,
) {
  return showModalBottomSheet<_DocumentMenuAction>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.14),
    builder: (context) {
      return LiquidGlassSheetPanel(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _GlassMenuTile(
              icon: Icons.drive_file_rename_outline_rounded,
              title: '重命名',
              action: _DocumentMenuAction.rename,
            ),
            _GlassMenuTile(
              icon: Icons.label_outline_rounded,
              title: '设置标签',
              action: _DocumentMenuAction.tags,
            ),
            _GlassMenuTile(
              icon: Icons.remove_circle_outline_rounded,
              title: '移出',
              action: _DocumentMenuAction.remove,
              destructive: true,
            ),
          ],
        ),
      );
    },
  );
}

class _GlassMenuTile extends StatelessWidget {
  const _GlassMenuTile({
    required this.icon,
    required this.title,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final _DocumentMenuAction action;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : context.palette.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              letterSpacing: 0,
            ),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

Future<void> _showTagEditor(BuildContext context, DocumentEntry document) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TagEditorSheet(document: document),
  );
}

class _TagEditorSheet extends StatefulWidget {
  const _TagEditorSheet({required this.document});

  final DocumentEntry document;

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  late final TextEditingController _tagController;
  late final Set<String> _selectedTags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
    _selectedTags = widget.document.tags.toSet();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryController>(
      builder: (context, controller, _) {
        final isLiquidGlass = liquidGlassEnabled(context);
        final tagField = TextField(
          key: const ValueKey('tag_name_field'),
          controller: _tagController,
          decoration: InputDecoration(
            hintText: '新建标签',
            border: isLiquidGlass ? InputBorder.none : null,
            enabledBorder: isLiquidGlass ? InputBorder.none : null,
            focusedBorder: isLiquidGlass ? InputBorder.none : null,
            filled: isLiquidGlass ? false : null,
            isDense: isLiquidGlass,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createTag(controller),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置标签',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.muted,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in controller.tags)
                  _EditableTagChip(
                    tag: tag,
                    selected: _selectedTags.contains(tag),
                    canDelete: !controller.allDocuments.any(
                      (document) => document.tags.contains(tag),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    onDeleted: () => _deleteTag(controller, tag),
                  ),
                if (controller.tags.isEmpty)
                  Text(
                    '默认无标签。先创建标签，再为文档勾选。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.palette.muted,
                          letterSpacing: 0,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: isLiquidGlass
                      ? LiquidGlassTextFieldFrame(child: tagField)
                      : tagField,
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => _createTag(controller),
                  child: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : () => _saveTags(controller),
                    child: Text(_isSaving ? '保存中' : '保存'),
                  ),
                ),
              ],
            ),
          ],
        );

        if (isLiquidGlass) {
          return LiquidGlassSheetPanel(
            margin: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: content,
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.card.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createTag(LibraryController controller) async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) {
      return;
    }
    try {
      await controller.createTag(tag);
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建标签失败：$error')),
        );
      }
    }
  }

  Future<void> _deleteTag(LibraryController controller, String tag) async {
    try {
      await controller.deleteTag(tag);
      setState(() => _selectedTags.remove(tag));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除标签失败：$error')),
        );
      }
    }
  }

  Future<void> _saveTags(LibraryController controller) async {
    setState(() => _isSaving = true);
    try {
      await controller.updateDocumentTags(
        widget.document,
        _selectedTags.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存标签失败：$error')),
        );
      }
    }
  }
}

class _EditableTagChip extends StatelessWidget {
  const _EditableTagChip({
    required this.tag,
    required this.selected,
    required this.canDelete,
    required this.onSelected,
    required this.onDeleted,
  });

  final String tag;
  final bool selected;
  final bool canDelete;
  final ValueChanged<bool> onSelected;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    if (liquidGlassEnabled(context)) {
      return LiquidGlassChip(
        label: tag,
        selected: selected,
        icon: Icons.label_outline_rounded,
        onTap: () => onSelected(!selected),
        onDeleted: canDelete ? onDeleted : null,
      );
    }
    return InputChip(
      label: Text(tag),
      selected: selected,
      onSelected: onSelected,
      onDeleted: canDelete ? onDeleted : null,
    );
  }
}

class _DocumentMetaRow extends StatelessWidget {
  const _DocumentMetaRow({required this.tags, required this.summary});

  final List<String> tags;
  final String summary;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
                fontSize: 12,
                letterSpacing: 0,
              ),
        ),
      );
    }
    final visibleTags = tags.take(2).toList();
    final overflow = tags.length - visibleTags.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Flexible(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final tag in visibleTags) _SmallTagChip(label: tag),
                if (overflow > 0) _SmallTagChip(label: '+$overflow'),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.muted,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTagChip extends StatelessWidget {
  const _SmallTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (liquidGlassEnabled(context)) {
      return LiquidGlassChip(label: label, selected: true);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    final isMd = document.type == DocumentType.markdown;
    final badgeColor = isMd ? AppColors.primary : AppColors.htmlBadge;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: badgeColor.withOpacity(0.18),
        ),
      ),
      child: Icon(
        isMd ? Icons.description_rounded : Icons.code_rounded,
        color: badgeColor,
        size: 20,
      ),
    );
  }
}

Future<void> _openReader(BuildContext context, DocumentEntry document) {
  return Navigator.of(context).push(
    appPageRoute<void>(builder: (context) => ReaderPage(document: document)),
  );
}

String _documentSummary(DocumentEntry document) {
  final timePrefix = document.recentOpenedAt == null ? '修改' : '最近阅读';
  final time = document.recentOpenedAt ?? document.modifiedAt;
  return '${document.type.label} · ${document.sizeLabel} · $timePrefix ${_timeLabel(time)}';
}

String _timeLabel(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} 天前';
  }
  return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
}
