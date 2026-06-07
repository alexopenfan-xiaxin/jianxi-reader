import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/haptic_service.dart';
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
  static String? _sessionSaying;

  late AnimationController _staggerController;
  String _saying = '安静阅读，慢慢抵达。';

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
    final cachedSaying = _sessionSaying;
    if (cachedSaying == null) {
      _sessionSaying = _saying;
      _loadSaying();
    } else {
      _saying = cachedSaying;
    }
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
          final settings = context.watch<AppSettingsController>();
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
                AppSpacing.lg,
              ),
              children: [
                _Header(controller: controller, saying: _saying),
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
                else if (settings.libraryViewMode == LibraryViewMode.shelf)
                  _ShelfGrid(documents: controller.documents)
                else
                  ...controller.documents.asMap().entries.map(
                        (entry) => _StaggeredFadeIn(
                          index: entry.key,
                          controller: _staggerController,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
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

  Future<void> _loadSaying() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('https://uapis.cn/api/v1/saying'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        return;
      }
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return;
      }
      final text = data['text'];
      if (text is String && text.trim().isNotEmpty && mounted) {
        final saying = text.trim();
        _sessionSaying = saying;
        setState(() => _saying = saying);
      }
    } catch (_) {
      // The saying is decorative; keep the local fallback on network errors.
    } finally {
      client.close(force: true);
    }
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
  const _Header({required this.controller, required this.saying});

  final LibraryController controller;
  final String saying;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '简兮',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _GlowingImportButton(
              key: const ValueKey('import_button'),
              importing: controller.isImporting,
              onPressed: () => _importDocument(context, controller),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          saying,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: palette.muted,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }

  Future<void> _importDocument(
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
}

class _GlowingImportButton extends StatelessWidget {
  const _GlowingImportButton({
    required this.importing,
    required this.onPressed,
    super.key,
  });

  final bool importing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !importing;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(enabled ? 0.26 : 0.10),
            blurRadius: enabled ? 24 : 12,
            spreadRadius: enabled ? 1 : 0,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(enabled ? 0.12 : 0.04),
            blurRadius: enabled ? 8 : 4,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.primary.withOpacity(0.22)),
        ),
        child: IconButton.filled(
          tooltip: '导入文档',
          onPressed: enabled ? onPressed : null,
          icon: importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
        ),
      ),
    );
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color:
                        _isFocused ? AppColors.primaryFocus : palette.hairline,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
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
            ),
            const SizedBox(width: AppSpacing.sm),
            _SortModeButton(controller: widget.controller),
          ],
        ),
      ],
    );
  }
}

class _SortModeButton extends StatelessWidget {
  const _SortModeButton({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sortMode = controller.sortMode;
    return Tooltip(
      message: '排序：${sortMode.label}',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            controller.updateSortMode(
              sortMode == LibrarySortMode.modified
                  ? LibrarySortMode.name
                  : LibrarySortMode.modified,
            );
          },
          borderRadius: BorderRadius.circular(AppRadii.pill),
          splashFactory: NoSplash.splashFactory,
          child: Container(
            key: const ValueKey('library_sort_toggle'),
            width: 48,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.hairline.withOpacity(0.7)),
            ),
            child: Icon(
              sortMode == LibrarySortMode.modified
                  ? Icons.schedule_rounded
                  : Icons.sort_by_alpha_rounded,
              color: AppColors.primary,
            ),
          ),
        ),
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
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
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
      key: const ValueKey('empty_library'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primary.withOpacity(0.56),
                size: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('还没有文档', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                '导入后会记住文件位置；重新进入阅读页时会读取原文件的最新内容。',
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
    final documents = await controller.importExternalDocuments();
    if (!context.mounted || documents.isEmpty) return;
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
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: AppColors.primary.withOpacity(0.56),
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '没有匹配的文档',
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.72,
          ),
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
      duration: const Duration(milliseconds: 130),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
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
    return AnimatedBuilder(
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
          onTapUp: (_) => _pressController.reverse(),
          onTapCancel: () => _pressController.reverse(),
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
                      Text(
                        _documentSummary(widget.document),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cover.foreground.withOpacity(0.78),
                              fontSize: 12,
                              height: 1.35,
                              letterSpacing: 0,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
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
      case _DocumentMenuAction.remove:
        await removeDocumentFromLibrary(context, widget.document);
    }
  }

  Future<void> _showShelfActions(BuildContext context) async {
    _pressController.reverse();
    final action = await showModalBottomSheet<_DocumentMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('重命名'),
                onTap: () => Navigator.of(context).pop(
                  _DocumentMenuAction.rename,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('移出'),
                onTap: () => Navigator.of(context).pop(
                  _DocumentMenuAction.remove,
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _hoverAnim,
      builder: (context, child) => Transform.scale(
        scale: _hoverAnim.value,
        child: child,
      ),
      child: AppCard(
        onTap: () => _openDocument(context),
        padding: const EdgeInsets.all(AppSpacing.md),
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
                          padding: const EdgeInsets.only(right: AppSpacing.xxs),
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
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _documentSummary(widget.document),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.muted,
                          fontSize: 12,
                          letterSpacing: 0,
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
                return const <PopupMenuEntry<_DocumentMenuAction>>[
                  PopupMenuItem(
                    value: _DocumentMenuAction.rename,
                    child: Text('重命名'),
                  ),
                  PopupMenuItem(
                    value: _DocumentMenuAction.remove,
                    child: Text('移出'),
                  ),
                ];
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
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ReaderPage(document: document),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curve),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0.015),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 260),
    ),
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
