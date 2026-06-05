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
  double _scrollOffset = 0;
  double _maxScrollExtent = 0;
  bool _isPreparingDocument = true;
  String? _prepareError;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
        _maxScrollExtent = _scrollController.position.maxScrollExtent;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareDocument());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showGlass = _scrollOffset > 20;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final progress = _maxScrollExtent > 0
        ? (_scrollOffset / _maxScrollExtent).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: showGlass ? Colors.transparent : palette.parchment,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: showGlass
            ? ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    color: (isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7))
                        .withValues(alpha: 0.80),
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
              final items = <PopupMenuEntry<_ReaderMenuAction>>[];
              if (!_document.isReferenced) {
                items.add(const PopupMenuItem(
                  value: _ReaderMenuAction.rename,
                  child: Text('重命名'),
                ));
              }
              items.add(const PopupMenuItem(
                value: _ReaderMenuAction.remove,
                child: Text('移出'),
              ));
              return items;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (progress > 0)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: AppColors.primary,
              minHeight: 2,
            ),
          Expanded(
            child: _buildBody(topPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double topPadding) {
    if (_isPreparingDocument) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_prepareError != null) {
      return _ReaderError(message: _prepareError!);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          setState(() {});
        }
        return false;
      },
      child: _ReaderContent(
        document: _document,
        scrollController: _scrollController,
        topPadding: topPadding,
      ),
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
          _prepareError = '璇诲彇鏂囨。澶辫触锛?error';
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

class _ReaderContent extends StatelessWidget {
  const _ReaderContent({
    required this.document,
    this.scrollController,
    this.topPadding = 0,
  });

  final DocumentEntry document;
  final ScrollController? scrollController;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final file = File(document.path);
    if (!file.existsSync()) {
      return const _ReaderError(message: '文档不存在或已被移出。');
    }

    final settings = context.watch<AppSettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return switch (document.type) {
      DocumentType.markdown => MarkdownViewer(
        file: file,
        fontSize: settings.readingFontSizeValue,
        lineHeight: settings.readingLineHeightValue,
        scrollController: scrollController,
        topPadding: topPadding,
      ),
      DocumentType.html => HtmlDocumentView(
        file: file,
        fontSize: settings.readingFontSizeValue,
        lineHeight: settings.readingLineHeightValue,
        isDark: isDark,
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
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.65,
      expand: false,
      builder: (context, scrollController) => _ReadingDisplaySheet(
        scrollController: scrollController,
      ),
    ),
  );
}

class _ReadingDisplaySheet extends StatelessWidget {
  final ScrollController? scrollController;

  const _ReadingDisplaySheet({this.scrollController});

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
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(Icons.text_fields_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('阅读显示', style: Theme.of(context).textTheme.titleLarge),
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
