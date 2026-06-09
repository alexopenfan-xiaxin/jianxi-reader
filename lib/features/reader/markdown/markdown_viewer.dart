import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_settings_controller.dart';
import '../../../core/design_tokens.dart';
import '../../../core/emoji_service.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../document_search_controller.dart';
import 'builders/clickable_link_builder.dart';
import 'builders/emoji_builder.dart';
import 'builders/mindmap_builder.dart';
import 'builders/performance_table_builder.dart';
import 'builders/scroll_safe_mermaid_builder.dart';
import 'builders/search_text_builder.dart';
import 'builders/syntax_highlight_code_block_builder.dart';
import 'builders/tappable_image_builder.dart';
import 'markdown_preprocessor.dart';
import 'markdown_style_factory.dart';
import 'plugins/bare_url_plugin.dart';
import 'plugins/highlight_plugin.dart';
import 'plugins/indented_ordered_list_plugin.dart';
import 'plugins/subscript_plugin.dart';
import 'plugins/superscript_plugin.dart';
import 'plugins/underline_plugin.dart';

class MarkdownViewer extends StatefulWidget {
  final File file;
  final double fontSize;
  final double lineHeight;
  final ReadingPalette readingPalette;
  final double horizontalPadding;
  final ScrollController? scrollController;
  final double topPadding;
  final DocumentSearchController? searchController;

  const MarkdownViewer({
    required this.file,
    required this.fontSize,
    required this.lineHeight,
    required this.readingPalette,
    required this.horizontalPadding,
    this.scrollController,
    this.topPadding = 0,
    this.searchController,
    super.key,
  });

  @override
  State<MarkdownViewer> createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> with WidgetsBindingObserver {
  String? _data;
  String? _error;
  DateTime? _lastModified;
  Map<String, String> _emojiMap = const {};
  late BuilderRegistry _builderRegistry;
  ParserPluginRegistry? _pluginRegistry;
  Map<String, String>? _pluginEmojiMap;
  List<int> _searchMatchOffsets = const [];
  String _searchText = '';
  Timer? _fileWatchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _builderRegistry = _createBuilderRegistry();
    widget.searchController?.addListener(_handleSearchChanged);
    _loadFile();
    EmojiService.load().then((map) {
      if (mounted) {
        setState(() {
          _emojiMap = map;
          _pluginRegistry = null;
        });
      }
    });
    _fileWatchTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkFileChanged(),
    );
  }

  @override
  void dispose() {
    _fileWatchTimer?.cancel();
    widget.searchController?.removeListener(_handleSearchChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkFileChanged();
    }
  }

  @override
  void didUpdateWidget(MarkdownViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_handleSearchChanged);
      widget.searchController?.addListener(_handleSearchChanged);
      _builderRegistry = _createBuilderRegistry();
      _handleSearchChanged();
    }
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight) {
      _loadFile();
    }
  }

  void _checkFileChanged() {
    try {
      if (!widget.file.existsSync()) return;
      final modified = widget.file.lastModifiedSync();
      if (_lastModified != null && modified.isAfter(_lastModified!)) {
        debugPrint('[MarkdownViewer] file changed, reloading (${widget.file.path})');
        _loadFile();
      }
    } catch (e) {
      debugPrint('[MarkdownViewer] checkFileChanged error: $e');
    }
  }

  Future<void> _loadFile() async {
    try {
      final raw = await widget.file.readAsString();
      if (mounted) {
        setState(() {
          _data = preprocessMarkdown(raw);
          _error = null;
        });
      }
      _lastModified = await widget.file.lastModified();
      _updateSearchMatches();
    } catch (e) {
      if (mounted) {
        setState(() => _error = '读取 Markdown 失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    if (_data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final styleSheet = MarkdownStyleFactory.build(
      context,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      readingPalette: widget.readingPalette,
    );

    return ColoredBox(
      color: widget.readingPalette.background,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding,
          widget.topPadding + AppSpacing.md,
          widget.horizontalPadding,
          AppSpacing.xxl + kBottomNavigationBarHeight,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        child: SmoothMarkdown(
          data: _data!,
          styleSheet: styleSheet,
          useEnhancedComponents: false,
          selectable: true,
          plugins: _plugins(),
          builderRegistry: _builderRegistry,
          onTapLink: (url) => _handleLinkTap(context, url),
          onTapImage: (url, alt, title) =>
              _showImagePreview(context, url, alt, title),
        ),
      ),
    );
  }

  BuilderRegistry _createBuilderRegistry() {
    return BuilderRegistry()
      ..register(
        'text',
        SearchTextBuilder(searchController: widget.searchController),
      )
      ..register('underline', const UnderlineBuilder())
      ..register('highlight', const HighlightBuilder())
      ..register('superscript', const SuperscriptBuilder())
      ..register('subscript', const SubscriptBuilder())
      ..register('table', const PerformanceTableBuilder())
      ..register(
        'code_block',
        SyntaxHighlightCodeBlockBuilder(
          showCopyButton: true,
          showLanguageTag: true,
          searchController: widget.searchController,
        ),
      )
      ..register('mermaid', const ScrollSafeMermaidBuilder())
      ..register('mindmap', const MindmapBuilder())
      ..register('indented_ordered_list', const IndentedOrderedListBuilder())
      ..register('link', const ClickableLinkBuilder())
      ..register('image', const TappableImageBuilder())
      ..register('emoji', const EmojiBuilder());
  }

  ParserPluginRegistry _plugins() {
    if (_pluginRegistry != null && identical(_pluginEmojiMap, _emojiMap)) {
      return _pluginRegistry!;
    }
    _pluginEmojiMap = _emojiMap;
    _pluginRegistry = ParserPluginRegistry()
      ..registerInline(const UnderlinePlugin())
      ..registerInline(const HighlightPlugin())
      ..registerInline(const SuperscriptPlugin())
      ..registerInline(const SubscriptPlugin())
      ..registerInline(const BareUrlPlugin())
      ..registerInline(
        EmojiPlugin(customEmojis: _emojiMap.isNotEmpty ? _emojiMap : null),
      )
      ..registerBlock(const IndentedOrderedListPlugin())
      ..registerBlock(const MermaidPlugin())
      ..registerBlock(const MindmapPlugin());
    return _pluginRegistry!;
  }

  void _handleSearchChanged() {
    _updateSearchMatches();
    _scrollToCurrentSearchMatch();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateSearchMatches() {
    final controller = widget.searchController;
    final data = _data;
    if (controller == null || data == null || !controller.hasQuery) {
      _searchText = '';
      _searchMatchOffsets = const [];
      controller?.updateMatchCount(0);
      return;
    }

    _searchText = _buildSearchText(data);
    _searchMatchOffsets = _matchOffsets(
      _searchText,
      controller.normalizedQuery,
    );
    controller.updateMatchCount(_searchMatchOffsets.length);
  }

  void _scrollToCurrentSearchMatch() {
    final controller = widget.searchController;
    final scrollController = widget.scrollController;
    if (controller == null ||
        scrollController == null ||
        !scrollController.hasClients ||
        _searchMatchOffsets.isEmpty ||
        _searchText.isEmpty) {
      return;
    }
    final position = scrollController.position;
    final offset = _searchMatchOffsets[controller.currentIndex];
    final progress = (offset / _searchText.length).clamp(0.0, 1.0);
    final target = position.maxScrollExtent * progress;
    scrollController.animateTo(
      target,
      duration: AppMotion.fast,
      curve: AppMotion.emphasized,
    );
  }

  String _buildSearchText(String data) {
    try {
      final nodes = MarkdownParser(plugins: _plugins()).parse(data);
      final buffer = StringBuffer();
      for (final node in nodes) {
        _appendNodeText(buffer, node);
        buffer.write('\n');
      }
      return buffer.toString();
    } catch (error) {
      debugPrint('[MarkdownViewer] build search text failed: $error');
      return data;
    }
  }

  void _appendNodeText(StringBuffer buffer, MarkdownNode node) {
    switch (node) {
      case TextNode():
        buffer.write(node.content);
      case HeaderNode():
        _appendChildrenOrFallback(buffer, node.children, node.content);
        buffer.write('\n');
      case ParagraphNode():
        _appendNodes(buffer, node.children);
        buffer.write('\n');
      case CodeBlockNode():
        buffer.write(node.code);
        buffer.write('\n');
      case InlineCodeNode():
        buffer.write(node.code);
      case ListNode():
        for (final item in node.items) {
          _appendNodeText(buffer, item);
          buffer.write('\n');
        }
      case ListItemNode():
        _appendNodes(buffer, node.children);
      case BlockquoteNode():
        _appendNodes(buffer, node.children);
      case BoldNode():
        _appendNodes(buffer, node.children);
      case ItalicNode():
        _appendNodes(buffer, node.children);
      case StrikethroughNode():
        _appendNodes(buffer, node.children);
      case LinkNode():
        _appendNodes(buffer, node.children);
      case ImageNode():
        buffer.write(node.alt);
        if (node.title != null) {
          buffer.write(' ${node.title}');
        }
      case UnderlineNode():
        buffer.write(node.text);
      case HighlightNode():
        buffer.write(node.text);
      case SuperscriptNode():
        buffer.write(node.text);
      case SubscriptNode():
        buffer.write(node.text);
      case IndentedOrderedListNode():
        for (final item in node.items) {
          _appendIndentedItemText(buffer, item);
          buffer.write('\n');
        }
      case MermaidDiagramNode():
        buffer.write(node.code);
      case MindmapNode():
        buffer.write(node.code);
      default:
        break;
    }
  }

  void _appendChildrenOrFallback(
    StringBuffer buffer,
    List<MarkdownNode>? children,
    String fallback,
  ) {
    if (children == null || children.isEmpty) {
      buffer.write(fallback);
      return;
    }
    _appendNodes(buffer, children);
  }

  void _appendNodes(StringBuffer buffer, List<MarkdownNode> nodes) {
    for (final child in nodes) {
      _appendNodeText(buffer, child);
    }
  }

  void _appendIndentedItemText(
    StringBuffer buffer,
    IndentedOrderedListItem item,
  ) {
    buffer.write(item.text);
    for (final child in item.children) {
      buffer.write('\n');
      _appendIndentedItemText(buffer, child);
    }
  }

  List<int> _matchOffsets(String text, String query) {
    if (text.isEmpty || query.isEmpty) {
      return const [];
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final offsets = <int>[];
    var index = lowerText.indexOf(lowerQuery);
    while (index != -1) {
      offsets.add(index);
      index = lowerText.indexOf(lowerQuery, index + lowerQuery.length);
    }
    return offsets;
  }

  void _handleLinkTap(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => LiquidGlassDialog(
        title: const Text('打开链接'),
        content: SingleChildScrollView(
          child: Text(url, style: Theme.of(ctx).textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(
      BuildContext context, String url, String? alt, String? title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(alt ?? title ?? ''),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: MarkdownPreviewImage(url: url),
            ),
          ),
        ),
      ),
    );
  }
}
