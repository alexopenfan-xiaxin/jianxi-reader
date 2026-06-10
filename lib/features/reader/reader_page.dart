import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/reading_settings_panel.dart';
import '../library/document_actions.dart';
import '../library/document_entry.dart';
import '../library/library_controller.dart';
import 'document_search_controller.dart';
import 'html_document_view.dart';
import 'markdown_viewer.dart';

enum _ReaderMenuAction { rename, remove }

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.document, super.key});

  final DocumentEntry document;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late DocumentEntry _document;
  late LibraryController _libraryController;
  final _scrollController = ScrollController();
  final _searchController = DocumentSearchController();
  final _searchTextController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showGlass = false;
  bool _isPreparingDocument = true;
  bool _isSearching = false;
  String? _prepareError;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _libraryController = context.read<LibraryController>();
    _scrollController.addListener(_handleScroll);
    _searchController.addListener(_handleSearchStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareDocument());
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchStateChanged);
    _searchController.dispose();
    _searchTextController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final nextShowGlass = _scrollController.offset > 20;
    if (nextShowGlass != _showGlass && mounted) {
      setState(() => _showGlass = nextShowGlass);
    }
  }

  void _handleSearchStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final settings = context.watch<AppSettingsController>();
    final readingPalette = settings.readingPalette(
      defaultBackground: palette.parchment,
      defaultForeground: palette.ink,
      defaultMuted: palette.muted,
      defaultSurface: palette.card,
      defaultBorder: palette.hairline,
      defaultLink: AppColors.primary,
    );
    final showGlassAppBar = settings.liquidGlassEnabled || _showGlass;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: readingPalette.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            showGlassAppBar ? Colors.transparent : readingPalette.background,
        foregroundColor: readingPalette.foreground,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: showGlassAppBar
            ? LiquidGlassSurface(
                borderRadius: BorderRadius.zero,
                color: readingPalette.background.withOpacity(
                  settings.liquidGlassEnabled ? 0.42 : 0.80,
                ),
                borderColor: Colors.transparent,
                blurSigma: settings.liquidGlassEnabled
                    ? LiquidGlassTokens.effectBlurSigma
                    : 18,
                innerHighlight: settings.liquidGlassEnabled,
                child: const SizedBox.expand(),
              )
            : null,
        title: _isSearching
            ? _ReaderSearchField(
                controller: _searchTextController,
                focusNode: _searchFocusNode,
                foreground: readingPalette.foreground,
                liquidGlass: settings.liquidGlassEnabled,
                onChanged: _searchController.updateQuery,
              )
            : AnimatedOpacity(
                opacity: showGlassAppBar ? 1 : 0,
                duration: AppMotion.fast,
                child: Text(
                  _document.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: readingPalette.foreground,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
              ),
        actions: _isSearching
            ? [
                _ReaderSearchCount(controller: _searchController),
                IconButton(
                  tooltip: '上一个',
                  onPressed: _searchController.hasMatches
                      ? _searchController.previous
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  tooltip: '下一个',
                  onPressed:
                      _searchController.hasMatches ? _searchController.next : null,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                IconButton(
                  tooltip: '关闭搜索',
                  onPressed: _closeSearch,
                  icon: const Icon(Icons.close_rounded),
                ),
              ]
            : [
                IconButton(
                  tooltip: '文档内搜索',
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: '阅读显示',
                  onPressed: () => showReadingDisplaySheet(context),
                  icon: const Icon(Icons.text_fields_rounded),
                ),
                if (settings.liquidGlassEnabled)
                  IconButton(
                    tooltip: '文档操作',
                    onPressed: () async {
                      final action = await _showReaderDocumentMenu(context);
                      if (action != null && mounted) {
                        await _handleAction(action);
                      }
                    },
                    icon: const Icon(Icons.more_horiz_rounded),
                  )
                else
                  PopupMenuButton<_ReaderMenuAction>(
                    tooltip: '文档操作',
                    onSelected: _handleAction,
                    itemBuilder: (context) {
                      return const <PopupMenuEntry<_ReaderMenuAction>>[
                        PopupMenuItem(
                          value: _ReaderMenuAction.rename,
                          child: Text('重命名'),
                        ),
                        PopupMenuItem(
                          value: _ReaderMenuAction.remove,
                          child: Text('移出'),
                        ),
                      ];
                    },
                  ),
              ],
      ),
      body: Column(
        children: [
          _ReaderProgressBar(scrollController: _scrollController),
          Expanded(
            child: _buildBody(topPadding, settings, readingPalette),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    double topPadding,
    AppSettingsController settings,
    ReadingPalette readingPalette,
  ) {
    if (_isPreparingDocument) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_prepareError != null) {
      return _ReaderError(message: _prepareError!);
    }

    return _ReaderContent(
      document: _document,
      scrollController: _scrollController,
      topPadding: topPadding,
      settings: settings,
      readingPalette: readingPalette,
      searchController: _searchController,
    );
  }

  Future<void> _prepareDocument() async {
    try {
      final refreshed = await _libraryController.refreshDocument(_document);
      final opened = await _libraryController.markDocumentOpened(refreshed);
      if (mounted) {
        setState(() {
          _document = opened;
          _prepareError = null;
          _isPreparingDocument = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _prepareError = '读取文档失败：$error';
          _isPreparingDocument = false;
        });
      }
    }
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchTextController.clear();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _isSearching = false);
  }

  Future<void> _handleAction(_ReaderMenuAction action) async {
    switch (action) {
      case _ReaderMenuAction.rename:
        final renamed = await showRenameDocumentDialog(context, _document);
        if (renamed != null && mounted) {
          setState(() => _document = renamed);
        }
      case _ReaderMenuAction.remove:
        final removed = await removeDocumentFromLibrary(context, _document);
        if (removed && mounted) {
          Navigator.of(context).pop();
        }
    }
  }
}

Future<_ReaderMenuAction?> _showReaderDocumentMenu(BuildContext context) {
  return showModalBottomSheet<_ReaderMenuAction>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.14),
    builder: (context) {
      return LiquidGlassSheetPanel(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ReaderMenuTile(
              icon: Icons.drive_file_rename_outline_rounded,
              title: '重命名',
              action: _ReaderMenuAction.rename,
            ),
            _ReaderMenuTile(
              icon: Icons.remove_circle_outline_rounded,
              title: '移出',
              action: _ReaderMenuAction.remove,
              destructive: true,
            ),
          ],
        ),
      );
    },
  );
}

class _ReaderMenuTile extends StatelessWidget {
  const _ReaderMenuTile({
    required this.icon,
    required this.title,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final _ReaderMenuAction action;
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

class _ReaderProgressBar extends StatelessWidget {
  const _ReaderProgressBar({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        if (!scrollController.hasClients) {
          return const SizedBox(height: 3);
        }
        final position = scrollController.position;
        final progress = position.maxScrollExtent > 0
            ? (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0)
            : 0.0;
        if (progress <= 0) {
          return const SizedBox(height: 3);
        }
        return LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.transparent,
          color: AppColors.primary.withOpacity(0.70),
          minHeight: 3,
        );
      },
    );
  }
}

class _ReaderSearchField extends StatelessWidget {
  const _ReaderSearchField({
    required this.controller,
    required this.focusNode,
    required this.foreground,
    required this.liquidGlass,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color foreground;
  final bool liquidGlass;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: foreground,
            letterSpacing: 0,
          ),
      decoration: const InputDecoration(
        hintText: '搜索当前文档',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
    if (!liquidGlass) {
      return field;
    }
    return LiquidGlassTextFieldFrame(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: field,
    );
  }
}

class _ReaderSearchCount extends StatelessWidget {
  const _ReaderSearchCount({required this.controller});

  final DocumentSearchController controller;

  @override
  Widget build(BuildContext context) {
    final label = controller.hasQuery
        ? '${controller.hasMatches ? controller.currentIndex + 1 : 0}/${controller.matchCount}'
        : '0/0';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }
}

class _ReaderContent extends StatelessWidget {
  const _ReaderContent({
    required this.document,
    required this.settings,
    required this.readingPalette,
    required this.searchController,
    this.scrollController,
    this.topPadding = 0,
  });

  final DocumentEntry document;
  final AppSettingsController settings;
  final ReadingPalette readingPalette;
  final DocumentSearchController searchController;
  final ScrollController? scrollController;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final file = File(document.path);
    if (!file.existsSync()) {
      return const _ReaderError(message: '文档不存在或已被移出。');
    }

    return switch (document.type) {
      DocumentType.markdown => MarkdownViewer(
          file: file,
          fontSize: settings.readingFontSizeValue,
          lineHeight: settings.readingLineHeightValue,
          readingPalette: readingPalette,
          horizontalPadding: settings.readingHorizontalPaddingValue,
          scrollController: scrollController,
          topPadding: topPadding,
          searchController: searchController,
        ),
      DocumentType.html => HtmlDocumentView(
          file: file,
          fontSize: settings.readingFontSizeValue,
          lineHeight: settings.readingLineHeightValue,
          readingPalette: readingPalette,
          horizontalPadding: settings.readingHorizontalPaddingValue,
          topPadding: topPadding,
          searchController: searchController,
        ),
    };
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showReadingDisplaySheet(BuildContext context) {
  final isLiquidGlass = readLiquidGlassEnabled(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: !isLiquidGlass,
    isScrollControlled: true,
    backgroundColor: isLiquidGlass ? Colors.transparent : context.palette.card,
    barrierColor:
        isLiquidGlass ? Colors.black.withOpacity(0.14) : Colors.black54,
    shape: isLiquidGlass
        ? null
        : const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.md),
            ),
          ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.82,
      expand: false,
      builder: (context, scrollController) => _ReadingDisplaySheet(
        scrollController: scrollController,
        liquidGlass: isLiquidGlass,
      ),
    ),
  );
}

class _ReadingDisplaySheet extends StatelessWidget {
  const _ReadingDisplaySheet({
    required this.liquidGlass,
    this.scrollController,
  });

  final ScrollController? scrollController;
  final bool liquidGlass;

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      controller: scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.12),
                  ),
                ),
                child: const Icon(
                  Icons.text_fields_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '阅读显示',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '这些设置只影响阅读内容，不改变应用整体主题。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.palette.muted,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ReadingSettingsPanel(showPreview: true),
        ],
      ),
    );

    if (liquidGlass) {
      return LiquidGlassSheetPanel(child: content);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: content,
      ),
    );
  }
}
