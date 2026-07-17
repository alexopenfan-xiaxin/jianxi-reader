import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_settings_controller.dart';
import '../../../core/design_tokens.dart';
import '../../../core/emoji_service.dart';
import '../../../core/file_rules.dart';
import '../../../core/widgets/app_page_route.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../document_search_controller.dart';
import '../toc_service.dart';
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

class _DocumentSection {
  const _DocumentSection({
    required this.title,
    required this.headingLevel,
    required this.content,
    required this.startIndex,
  });

  final String title;
  final int headingLevel;
  final String content;
  final int startIndex;
}

List<_DocumentSection> _splitIntoSections(String data) {
  final lines = data.split('\n');
  final sections = <_DocumentSection>[];
  final buffer = StringBuffer();
  var currentTitle = '';
  var currentLevel = 0;
  var sectionStart = 0;
  var charIndex = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final headingMatch = RegExp(r'^(#{1,6})\s+(.+)').firstMatch(line);

    if (headingMatch != null && i > 0) {
      // Flush current section.
      sections.add(
        _DocumentSection(
          title: currentTitle,
          headingLevel: currentLevel,
          content: buffer.toString(),
          startIndex: sectionStart,
        ),
      );
      buffer.clear();
      currentTitle = headingMatch.group(2) ?? '';
      currentLevel = headingMatch.group(1)!.length;
      sectionStart = charIndex;
    }

    buffer.writeln(line);
    charIndex += line.length + 1; // +1 for newline
  }

  // Flush last section.
  if (buffer.isNotEmpty) {
    sections.add(
      _DocumentSection(
        title: currentTitle,
        headingLevel: currentLevel,
        content: buffer.toString(),
        startIndex: sectionStart,
      ),
    );
  }

  return sections;
}

class MarkdownViewer extends StatefulWidget {
  final File file;
  final double fontSize;
  final double lineHeight;
  final ReadingPalette readingPalette;
  final double horizontalPadding;
  final ScrollController? scrollController;
  final double topPadding;
  final DocumentSearchController? searchController;
  final String? fontFamily;
  final ValueChanged<List<TocEntry>>? onTocChanged;

  const MarkdownViewer({
    required this.file,
    required this.fontSize,
    required this.lineHeight,
    required this.readingPalette,
    required this.horizontalPadding,
    this.scrollController,
    this.topPadding = 0,
    this.searchController,
    this.fontFamily,
    this.onTocChanged,
    super.key,
  });

  @override
  State<MarkdownViewer> createState() => MarkdownViewerState();
}

Future<Map<String, Object>> _readMarkdownSnapshot(String path) async {
  final file = File(path);
  final initialSize = await file.length();
  if (initialSize > DocumentFileRules.maxReadableBytes) {
    throw FileSystemException('文档过大', path);
  }
  final raw = await file.readAsString();
  final stat = await file.stat();
  return {
    'data': preprocessMarkdown(raw),
    'modified': stat.modified.millisecondsSinceEpoch,
    'size': stat.size,
  };
}

class MarkdownViewerState extends State<MarkdownViewer>
    with WidgetsBindingObserver {
  String? _data;
  String? _error;
  DateTime? _lastModified;
  Map<String, String> _emojiMap = const {};
  late BuilderRegistry _builderRegistry;
  ParserPluginRegistry? _pluginRegistry;
  Map<String, String>? _pluginEmojiMap;
  List<int> _searchMatchOffsets = const [];
  String _searchText = '';
  String? _cachedSearchText;
  int _contentVersion = 0;
  Timer? _fileWatchTimer;
  Timer? _searchDebounce;
  Timer? _debounceReloadTimer;
  StreamSubscription<FileSystemEvent>? _fileWatchSub;
  int _headingBuildIndex = 0;
  final Map<int, GlobalKey> _headingKeys = {};
  bool _isReloading = false;
  bool _pendingReload = false;
  bool _forceReload = false;
  int? _lastKnownSize;

  List<_DocumentSection> _sections = const [];
  int _visibleSectionCount = 0;
  bool _allSectionsVisible = true;
  String? _fullData;

  static const int _initialSectionCount = 3;
  static const int _sectionIncrement = 2;
  static const double _loadMoreThreshold = 0.8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _builderRegistry = _createBuilderRegistry();
    widget.searchController?.addListener(_handleSearchChanged);
    widget.scrollController?.addListener(_onScroll);
    _guardedLoadFile();
    EmojiService.load().then((map) {
      if (mounted) {
        setState(() {
          _emojiMap = map;
          _pluginRegistry = null;
        });
      }
    });
    _startFileMonitoring();
  }

  @override
  void dispose() {
    _stopFileMonitoring();
    _searchDebounce?.cancel();
    _debounceReloadTimer?.cancel();
    widget.scrollController?.removeListener(_onScroll);
    widget.searchController?.removeListener(_handleSearchChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startFileWatch() {
    final previousSubscription = _fileWatchSub;
    _fileWatchSub = null;
    previousSubscription?.cancel();
    try {
      late final StreamSubscription<FileSystemEvent> subscription;
      subscription = widget.file.watch().listen(
        (event) {
          debugPrint('[MarkdownViewer] file watch event, scheduling reload');
          try {
            _scheduleReload(force: true);
          } catch (e) {
            debugPrint('[MarkdownViewer] error in _scheduleReload: $e');
          }
        },
        onError: (e) {
          debugPrint('[MarkdownViewer] file watch error: $e');
          if (identical(_fileWatchSub, subscription)) {
            _fileWatchSub = null;
          }
        },
        onDone: () {
          if (identical(_fileWatchSub, subscription)) {
            _fileWatchSub = null;
          }
        },
      );
      _fileWatchSub = subscription;
    } catch (e) {
      debugPrint('[MarkdownViewer] file watch not supported: $e');
    }
  }

  void _scheduleReload({bool force = false}) {
    if (force) {
      _forceReload = true;
    }
    _debounceReloadTimer?.cancel();
    _debounceReloadTimer = Timer(
      const Duration(milliseconds: 500),
      _guardedLoadFile,
    );
  }

  Future<void> _guardedLoadFile() async {
    if (_isReloading) {
      _pendingReload = true;
      return;
    }
    _isReloading = true;
    try {
      await _loadFile();
    } finally {
      _isReloading = false;
      if (_pendingReload) {
        _pendingReload = false;
        _guardedLoadFile();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkFileChanged();
      _startFileMonitoring();
    } else {
      _stopFileMonitoring();
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
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
    if (oldWidget.onTocChanged != widget.onTocChanged && _data != null) {
      _notifyTocChanged(_fullData ?? _data!);
    }
    if (oldWidget.file.path != widget.file.path) {
      _lastModified = null;
      _lastKnownSize = null;
      _forceReload = true;
      _startFileMonitoring();
      _guardedLoadFile();
    }
  }

  Future<void> _checkFileChanged() async {
    try {
      final stat = await widget.file.stat();
      if (stat.type == FileSystemEntityType.notFound) {
        if (_error == null) {
          _scheduleReload();
        }
        return;
      }
      if (_lastModified != null &&
          (stat.modified != _lastModified || stat.size != _lastKnownSize)) {
        debugPrint(
          '[MarkdownViewer] file changed, scheduling reload '
          '(${widget.file.path})',
        );
        _scheduleReload();
      }
    } catch (e) {
      debugPrint('[MarkdownViewer] checkFileChanged error: $e');
    }
  }

  Future<void> _loadFile() async {
    final file = widget.file;
    final filePath = file.path;
    final forceReload = _forceReload;
    _forceReload = false;
    try {
      // Check file fingerprint before doing expensive work.
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.notFound) {
        throw FileSystemException('文档不存在', filePath);
      }
      final fileModified = stat.modified;
      final fileSize = stat.size;
      if (fileSize > DocumentFileRules.maxReadableBytes) {
        throw FileSystemException('文档过大', filePath);
      }
      if (!forceReload &&
          _lastModified != null &&
          _lastKnownSize != null &&
          fileModified == _lastModified! &&
          fileSize == _lastKnownSize!) {
        debugPrint('[MarkdownViewer] file unchanged, skipping reload');
        return;
      }
      final snapshot = await compute(_readMarkdownSnapshot, filePath);
      final data = snapshot['data']! as String;
      final modified = DateTime.fromMillisecondsSinceEpoch(
        snapshot['modified']! as int,
      );
      final snapshotSize = snapshot['size']! as int;

      if (!mounted || widget.file.path != filePath) {
        return;
      }

      // Split into sections for progressive rendering (only for large files > 1MB).
      final useSectionRendering = snapshotSize > 1048576; // 1 MB
      final sections = useSectionRendering
          ? _splitIntoSections(data)
          : <_DocumentSection>[];
      final initialCount = sections.length <= _initialSectionCount
          ? sections.length
          : _initialSectionCount;
      final allVisible = sections.isEmpty || sections.length <= initialCount;
      final displayData = allVisible
          ? data
          : sections.sublist(0, initialCount).map((s) => s.content).join();

      setState(() {
        _fullData = data;
        _sections = sections;
        _visibleSectionCount = initialCount;
        _allSectionsVisible = allVisible;
        _data = displayData;
        _error = null;
        _contentVersion++;
        _cachedSearchText = null;
      });
      _lastModified = modified;
      _lastKnownSize = snapshotSize;
      // Always generate TOC from full text for complete navigation.
      _notifyTocChanged(data);
      _rebuildSearchTextCache();
      _updateSearchMatches();
    } catch (e) {
      if (mounted && widget.file.path == filePath) {
        setState(() => _error = '读取 Markdown 失败：$e');
      }
    }
  }

  void _loadMoreSections() {
    if (_allSectionsVisible) return;
    final newCount = (_visibleSectionCount + _sectionIncrement).clamp(
      0,
      _sections.length,
    );
    if (newCount == _visibleSectionCount) return;
    final allVisible = newCount >= _sections.length;
    if (allVisible && _fullData == null) {
      debugPrint(
        '[MarkdownViewer] error: _fullData is null when allVisible is true',
      );
      return;
    }
    final displayData = allVisible
        ? _fullData!
        : _sections.sublist(0, newCount).map((s) => s.content).join();
    setState(() {
      _visibleSectionCount = newCount;
      _allSectionsVisible = allVisible;
      _data = displayData;
      _contentVersion++;
      _cachedSearchText = null;
    });
    _rebuildSearchTextCache();
    _updateSearchMatches();
  }

  void _onScroll() {
    if (_allSectionsVisible) return;
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.maxScrollExtent <= 0) return;
    final ratio = position.pixels / position.maxScrollExtent;
    if (ratio >= _loadMoreThreshold) {
      _loadMoreSections();
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
      fontFamily: widget.fontFamily,
    );
    widget.searchController?.beginBuildPass();
    _headingBuildIndex = 0;

    return ColoredBox(
      color: widget.readingPalette.background,
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: AppMotion.normal,
            reverseDuration: AppMotion.fast,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: AppMotion.enter),
                  ),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey(_contentVersion),
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                widget.horizontalPadding,
                widget.topPadding + AppSpacing.md,
                widget.horizontalPadding,
                AppSpacing.xxl + kBottomNavigationBarHeight,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SmoothMarkdown(
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
                    if (!_allSectionsVisible)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          '下滑加载更多…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.readingPalette.muted.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AnimatedOpacity(
              opacity: _data == null ? 1.0 : 0.0,
              duration: AppMotion.fast,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: widget.readingPalette.background,
                valueColor: AlwaysStoppedAnimation(
                  widget.readingPalette.link.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BuilderRegistry _createBuilderRegistry() {
    return BuilderRegistry()
      ..register('header', TocHeaderBuilder(keyForHeading: _keyForHeading))
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

  GlobalKey? _keyForHeading(HeaderNode node) {
    if (node.level > 4 || node.content.trim().isEmpty) {
      return null;
    }
    final index = _headingBuildIndex++;
    return _headingKeys.putIfAbsent(index, () => GlobalKey());
  }

  Future<void> jumpToTocEntry(TocEntry entry) async {
    // If the target heading is not yet rendered, expand sections until it is.
    var context = _headingKeys[entry.index]?.currentContext;
    if (context == null && !_allSectionsVisible) {
      // Expand all sections to ensure the target is visible.
      _loadAllSections();
      // Wait for the frame to be built.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      context = _headingKeys[entry.index]?.currentContext;
    }
    if (context == null) return;
    if (!context.mounted) return;
    await Scrollable.ensureVisible(
      context,
      duration: AppMotion.normal,
      curve: AppMotion.emphasized,
      alignment: 0.08,
    );
  }

  void _loadAllSections() {
    if (_allSectionsVisible || _fullData == null) return;
    setState(() {
      _visibleSectionCount = _sections.length;
      _allSectionsVisible = true;
      _data = _fullData!;
      _contentVersion++;
      _cachedSearchText = null;
    });
    _rebuildSearchTextCache();
    _updateSearchMatches();
  }

  void _notifyTocChanged(String data) {
    try {
      final entries = TocService.fromMarkdown(data, plugins: _plugins());
      _headingKeys.removeWhere((index, _) => index >= entries.length);
      widget.onTocChanged?.call(entries);
    } catch (error) {
      debugPrint('[MarkdownViewer] build toc failed: $error');
      widget.onTocChanged?.call(const []);
    }
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _updateSearchMatches();
      _scrollToCurrentSearchMatch();
      if (mounted) {
        setState(() {});
      }
    });
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

    if (_cachedSearchText == null) {
      _rebuildSearchTextCache();
    }
    _searchText = _cachedSearchText ?? '';
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

  void _rebuildSearchTextCache() {
    final data = _data;
    if (data == null) {
      _cachedSearchText = null;
      return;
    }
    _cachedSearchText = _buildSearchText(data);
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
      if (offsets.length >= DocumentSearchController.maxMatches) {
        break;
      }
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
              unawaited(_openMarkdownLink(url));
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMarkdownLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showLinkMessage('无法识别的链接');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showLinkMessage('无法打开链接');
      }
    } catch (error) {
      debugPrint('[MarkdownViewer] open link failed: $error');
      _showLinkMessage('无法打开链接');
    }
  }

  void _startFileMonitoring() {
    _fileWatchTimer?.cancel();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      _fileWatchTimer = null;
      _fileWatchSub?.cancel();
      _fileWatchSub = null;
      return;
    }
    _fileWatchTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkFileChanged(),
    );
    _startFileWatch();
  }

  void _stopFileMonitoring() {
    _fileWatchTimer?.cancel();
    _fileWatchTimer = null;
    _fileWatchSub?.cancel();
    _fileWatchSub = null;
  }

  void _showLinkMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showImagePreview(
    BuildContext context,
    String url,
    String? alt,
    String? title,
  ) {
    final caption = [
      if (alt != null && alt.trim().isNotEmpty) alt.trim(),
      if (title != null && title.trim().isNotEmpty) title.trim(),
    ].join(' · ');
    Navigator.of(context).push(
      appPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(caption.isEmpty ? '图片预览' : caption),
            actions: [
              IconButton(
                tooltip: '复制图片路径',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('已复制图片路径')));
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: MarkdownPreviewImage(url: url),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: _ImagePreviewInfo(url: url, caption: caption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewInfo extends StatelessWidget {
  const _ImagePreviewInfo({required this.url, required this.caption});

  final String url;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final text = caption.isEmpty ? url : '$caption\n$url';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class TocHeaderBuilder extends MarkdownWidgetBuilder {
  const TocHeaderBuilder({required this.keyForHeading});

  final GlobalKey? Function(HeaderNode node) keyForHeading;

  @override
  bool canBuild(MarkdownNode node) => node is HeaderNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final headerNode = node as HeaderNode;
    final style = _styleForLevel(headerNode.level, styleSheet);
    final inlineRenderer = context.inlineRenderer;
    final content =
        headerNode.children != null &&
            headerNode.children!.isNotEmpty &&
            inlineRenderer != null
        ? inlineRenderer(headerNode.children!, style)
        : Text(headerNode.content, style: style);
    final key = keyForHeading(headerNode);
    if (key == null) {
      return content;
    }
    return KeyedSubtree(key: key, child: content);
  }

  TextStyle? _styleForLevel(int level, MarkdownStyleSheet styleSheet) {
    return switch (level) {
      1 => styleSheet.h1Style,
      2 => styleSheet.h2Style,
      3 => styleSheet.h3Style,
      4 => styleSheet.h4Style,
      5 => styleSheet.h5Style,
      6 => styleSheet.h6Style,
      _ => styleSheet.textStyle,
    };
  }
}
