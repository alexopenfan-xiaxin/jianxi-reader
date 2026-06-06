import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/widgets/reading_settings_panel.dart';
import '../library/document_actions.dart';
import '../library/document_entry.dart';
import '../library/library_controller.dart';
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
  final _scrollController = ScrollController();
  bool _showGlass = false;
  bool _isPreparingDocument = true;
  String? _prepareError;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareDocument());
  }

  @override
  void dispose() {
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: readingPalette.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            _showGlass ? Colors.transparent : readingPalette.background,
        foregroundColor: readingPalette.foreground,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: _showGlass
            ? ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    color: readingPalette.background.withValues(alpha: 0.80),
                  ),
                ),
              )
            : null,
        title: Text(
          _document.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '阅读显示',
            onPressed: () => showReadingDisplaySheet(context),
            icon: const Icon(Icons.text_fields_rounded),
          ),
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
    );
  }

  Future<void> _prepareDocument() async {
    try {
      final controller = context.read<LibraryController>();
      final refreshed = await controller.refreshDocument(_document);
      await controller.markDocumentOpened(refreshed);
      if (mounted) {
        setState(() {
          _document = refreshed;
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

class _ReaderProgressBar extends StatelessWidget {
  const _ReaderProgressBar({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        if (!scrollController.hasClients) {
          return const SizedBox(height: 2);
        }
        final position = scrollController.position;
        final progress = position.maxScrollExtent > 0
            ? (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0)
            : 0.0;
        if (progress <= 0) {
          return const SizedBox(height: 2);
        }
        return LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.transparent,
          color: AppColors.primary.withValues(alpha: 0.75),
          minHeight: 2,
        );
      },
    );
  }
}

class _ReaderContent extends StatelessWidget {
  const _ReaderContent({
    required this.document,
    required this.settings,
    required this.readingPalette,
    this.scrollController,
    this.topPadding = 0,
  });

  final DocumentEntry document;
  final AppSettingsController settings;
  final ReadingPalette readingPalette;
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
        ),
      DocumentType.html => HtmlDocumentView(
          file: file,
          fontSize: settings.readingFontSizeValue,
          lineHeight: settings.readingLineHeightValue,
          readingPalette: readingPalette,
          horizontalPadding: settings.readingHorizontalPaddingValue,
          topPadding: topPadding,
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
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

void showReadingDisplaySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.82,
      expand: false,
      builder: (context, scrollController) => _ReadingDisplaySheet(
        scrollController: scrollController,
      ),
    ),
  );
}

class _ReadingDisplaySheet extends StatelessWidget {
  const _ReadingDisplaySheet({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
        ),
      ),
    );
  }
}
