import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/widgets/app_card.dart';
import '../reader/reader_page.dart';
import 'document_actions.dart';
import 'document_entry.dart';
import 'library_controller.dart';

enum _DocumentMenuAction { rename, remove }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerController.forward();
    });
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
          if (controller.allDocuments.isNotEmpty &&
              _staggerController.status == AnimationStatus.dismissed) {
            _staggerController.forward();
          }
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                112,
              ),
              children: [
                _Header(controller: controller),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorBanner(message: controller.errorMessage!),
                ],
                const SizedBox(height: AppSpacing.lg),
                _LibraryTools(controller: controller),
                const SizedBox(height: AppSpacing.lg),
                if (controller.isLoading)
                  const _LoadingState()
                else if (controller.allDocuments.isEmpty)
                  const _EmptyState()
                else if (controller.documents.isEmpty)
                  const _NoResultsState()
                else
                  ...controller.documents.asMap().entries.map(
                    (entry) => _StaggeredFadeIn(
                      index: entry.key,
                      controller: _staggerController,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _DocumentTile(document: entry.value),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _StaggeredFadeIn({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('简兮', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '安静地管理和阅读你的 Markdown 与 HTML 文档。',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: context.palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton.filled(
          key: const ValueKey('import_button'),
          tooltip: '导入文档',
          onPressed: controller.isImporting
              ? null
              : () => _importDocument(context, controller),
          icon: controller.isImporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  Future<void> _importDocument(
    BuildContext context,
    LibraryController controller,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final document = await controller.importExternalDocument();
    if (!context.mounted || document == null) {
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReaderPage(document: document),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (context.mounted) {
      await controller.loadDocuments();
    }
  }
}

class _LibraryTools extends StatefulWidget {
  const _LibraryTools({required this.controller});

  final LibraryController controller;

  @override
  State<_LibraryTools> createState() => _LibraryToolsState();
}

class _LibraryToolsState extends State<_LibraryTools> {
  late final TextEditingController _searchController;
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _LibraryTools oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.controller.searchQuery) {
      _searchController.text = widget.controller.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: _isFocused ? AppColors.primaryFocus : palette.hairline,
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: TextField(
            key: const ValueKey('library_search_field'),
            focusNode: _focusNode,
            controller: _searchController,
            onChanged: widget.controller.updateSearchQuery,
            decoration: InputDecoration(
              hintText: '搜索文档',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: widget.controller.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.updateSearchQuery('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.hairline.withValues(alpha: 0.3)),
            ),
            child: SegmentedButton<LibrarySortMode>(
              segments: LibrarySortMode.values
                  .map(
                    (sortMode) => ButtonSegment(
                      value: sortMode,
                      label: Text(sortMode.label),
                    ),
                  )
                  .toList(),
              selected: {widget.controller.sortMode},
              onSelectionChanged: (selection) {
                widget.controller.updateSortMode(selection.first);
              },
            ),
          ),
        ),
      ],
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
          Icon(Icons.error_outline_rounded, color: AppColors.error),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('还没有文档', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                '点击右上角的 + 按钮导入文档。\n应用会记住文件位置并在原位读取。',
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
              label: const Text('导入第一个文档'),
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
    final document = await controller.importExternalDocument();
    if (!context.mounted || document == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReaderPage(document: document),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (context.mounted) {
      await controller.loadDocuments();
    }
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('没有匹配的文档',
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

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({required this.document});

  final DocumentEntry document;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> with SingleTickerProviderStateMixin {
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
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hoverAnim,
      builder: (context, child) => Transform.scale(
        scale: _hoverAnim.value,
        child: child,
      ),
      child: AppCard(
        onTap: () => _openDocument(context),
        child: Row(
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
                          padding: const EdgeInsets.only(right: AppSpacing.xxs),
                          child: Icon(Icons.link_rounded, size: 14,
                            color: context.palette.muted),
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
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _documentSummary(widget.document),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            PopupMenuButton<_DocumentMenuAction>(
              tooltip: '文档操作',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (context) {
                final items = <PopupMenuEntry<_DocumentMenuAction>>[
                  const PopupMenuItem(
                    value: _DocumentMenuAction.rename,
                    child: Text('重命名'),
                  ),
                  const PopupMenuItem(
                    value: _DocumentMenuAction.remove,
                    child: Text('移出'),
                  ),
                ];
                return items;
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
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReaderPage(document: widget.document),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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
      case _DocumentMenuAction.remove:
        await removeDocumentFromLibrary(context, widget.document);
    }
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
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.15),
          width: 2,
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
