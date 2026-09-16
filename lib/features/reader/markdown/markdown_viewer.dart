import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_settings_controller.dart';
import '../../../core/design_tokens.dart';
import '../../../core/emoji_service.dart';
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
import 'markdown_document.dart';
import 'markdown_style_factory.dart';
import 'plugins/highlight_plugin.dart';
import 'plugins/indented_ordered_list_plugin.dart';
import 'plugins/subscript_plugin.dart';
import 'plugins/superscript_plugin.dart';
import 'plugins/underline_plugin.dart';
import 'section_height_estimator.dart';

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

class MarkdownViewerState extends State<MarkdownViewer>
    with WidgetsBindingObserver {
  MarkdownDocument? _document;
  String? _error;
  DateTime? _lastModified;
  int? _lastKnownSize;

  List<int> _searchMatchOffsets = const [];
  List<int>? _sectionMatchBases;
  int _docVersion = 0;

  Timer? _fileWatchTimer;
  Timer? _searchDebounce;
  Timer? _debounceReloadTimer;
  StreamSubscription<FileSystemEvent>? _fileWatchSub;

  final Map<int, GlobalKey> _headingKeys = {};
  final Map<int, GlobalKey> _sectionSlotKeys = {};
  final Map<int, Widget> _sectionWidgets = {};
  final Set<int> _builtSections = <int>{};
  final Map<int, double> _measuredHeights = {};
  final Map<int, double> _estimatedHeights = {};
  List<double> _tops = const [];
  bool _topsDirty = true;

  String _styleKey = '';
  String _searchGeneration = '';
  ReadingPalette? _lastPalette;
  double _contentWidth = 0;
  MarkdownStyleSheet? _activeStyleSheet;
  SectionHeightEstimator? _estimator;

  bool _isReloading = false;
  bool _pendingReload = false;
  bool _forceReload = false;

  bool _jumpActive = false;
  bool _measureScheduled = false;

  // Sections within this distance of the viewport are rendered; rendered
  // sections farther than the recycle distance fall back to height
  // placeholders (keeping their measured height so scrolling never jumps).
  static const double _buildAheadPx = 2000;
  static const double _recycleDistancePx = 6000;
  static const double _fallbackViewportPx = 1200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.searchController?.addListener(_handleSearchChanged);
    widget.scrollController?.addListener(_onScroll);
    _guardedLoadFile();
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
      _updateSearchMatches();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
    if (oldWidget.onTocChanged != widget.onTocChanged && _document != null) {
      widget.onTocChanged?.call(_document!.tocEntries);
    }
    if (oldWidget.file.path != widget.file.path) {
      _lastModified = null;
      _lastKnownSize = null;
      _forceReload = true;
      _startFileMonitoring();
      _guardedLoadFile();
    } else if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.fontFamily != widget.fontFamily ||
        oldWidget.readingPalette != widget.readingPalette ||
        oldWidget.horizontalPadding != widget.horizontalPadding) {
      // Display settings changed: cached section widgets and heights are stale.
      // _prepareCaches rebuilds the estimator and clears placeholders on build.
      _sectionWidgets.clear();
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
      if (!forceReload &&
          _lastModified != null &&
          _lastKnownSize != null &&
          stat.modified == _lastModified! &&
          stat.size == _lastKnownSize!) {
        debugPrint('[MarkdownViewer] file unchanged, skipping reload');
        return;
      }
      final emojiMap = await EmojiService.load();
      final document = await MarkdownDocument.load(filePath, emojiMap);
      if (!mounted || widget.file.path != filePath) {
        return;
      }
      setState(() {
        _document = document;
        _error = null;
        _docVersion++;
        _sectionWidgets.clear();
        _measuredHeights.clear();
        _estimatedHeights.clear();
        _estimator = null;
        _builtSections.clear();
        _headingKeys.clear();
        _sectionSlotKeys.clear();
        _searchMatchOffsets = const [];
        _sectionMatchBases = null;
        _topsDirty = true;
      });
      _lastModified = document.modified;
      _lastKnownSize = document.size;
      _ensureEstimatorForReload();
      widget.onTocChanged?.call(document.tocEntries);
      _updateSearchMatches();
    } catch (e) {
      if (mounted && widget.file.path == filePath) {
        setState(() => _error = '读取 Markdown 失败：$e');
      }
    }
  }

  // --- Virtualized section rendering ---

  /// The single scroll position attached to [MarkdownViewer.scrollController].
  ///
  /// Returns null while an AnimatedSwitcher transition keeps two scroll views
  /// attached (reloads) or none is attached yet; position-dependent work must
  /// wait because `ScrollController.position` asserts on multi-attachment.
  ScrollPosition? _attachedPosition() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      return null;
    }
    if (controller.positions.length != 1) {
      return null;
    }
    return controller.positions.first;
  }

  void _onScroll() {
    if (_jumpActive) {
      return;
    }
    _maybeUpdateBuiltWindow();
  }

  void _maybeUpdateBuiltWindow() {
    final doc = _document;
    if (doc == null || doc.sections.isEmpty) {
      return;
    }
    final position = _attachedPosition();
    if (position == null) {
      return;
    }
    final viewTop = position.pixels;
    final viewBottom = position.pixels + position.viewportDimension;
    final first = _sectionIndexAt(viewTop - _buildAheadPx);
    final last = _sectionIndexAt(viewBottom + _buildAheadPx);
    var changed = false;
    final keepLow = viewTop - _recycleDistancePx;
    final keepHigh = viewBottom + _recycleDistancePx;
    final next = <int>{};
    for (final index in _builtSections) {
      final top = _sectionTop(index);
      final bottom = top + _heightFor(index);
      if (bottom >= keepLow && top <= keepHigh) {
        next.add(index);
      } else {
        _sectionWidgets.remove(index);
        changed = true;
      }
    }
    for (var index = first; index <= last; index++) {
      if (index >= 0 && index < doc.sections.length && next.add(index)) {
        changed = true;
      }
    }
    if (!changed && next.length == _builtSections.length) {
      return;
    }
    _builtSections
      ..clear()
      ..addAll(next);
    if (mounted) {
      setState(() {});
    }
  }

  void _buildSectionsAroundOffset(double offset) {
    final doc = _document;
    if (doc == null || doc.sections.isEmpty) {
      return;
    }
    final first = _sectionIndexAt(offset - _buildAheadPx);
    final last = _sectionIndexAt(offset + _fallbackViewportPx + _buildAheadPx);
    var changed = false;
    for (var index = first; index <= last; index++) {
      if (index >= 0 &&
          index < doc.sections.length &&
          _builtSections.add(index)) {
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      final position = _attachedPosition();
      if (position == null) {
        // A view transition is swapping scroll views; retry next frame.
        if (_document != null) {
          _scheduleMeasure();
        }
        return;
      }
      _measureBuiltSections(position);
      if (!_jumpActive) {
        _maybeUpdateBuiltWindow();
      }
    });
  }

  void _measureBuiltSections(ScrollPosition position) {
    if (_builtSections.isEmpty) {
      return;
    }
    var correction = 0.0;
    var heightsChanged = false;
    for (final index in _builtSections) {
      final context = _sectionSlotKeys[index]?.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final height = renderObject.size.height;
        final previous = _measuredHeights[index] ?? _estimatedHeights[index];
        if (previous == null) {
          // First render of a directly-built section: nothing to anchor.
          _measuredHeights[index] = height;
          heightsChanged = true;
        } else if ((height - previous).abs() > 0.5) {
          // Anchor the viewport when content above it changes height.
          if (!_jumpActive) {
            final top = _sectionTop(index);
            if (top + previous <= position.pixels + 1) {
              correction += height - previous;
            }
          }
          _measuredHeights[index] = height;
          heightsChanged = true;
        }
      }
    }
    if (!heightsChanged) {
      return;
    }
    _topsDirty = true;
    if (correction != 0 && !_jumpActive) {
      final target = (position.pixels + correction).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if ((target - position.pixels).abs() > 0.5) {
        position.jumpTo(target);
      }
    }
  }

  // --- Heights ---

  /// Rebuilds the estimator after a reload using the last known content width
  /// so the first frame has sensible placeholder heights; the true width from
  /// [LayoutBuilder] refines it in [_prepareCaches] on the following build.
  void _ensureEstimatorForReload() {
    if (_estimator != null || _document == null) {
      return;
    }
    final styleSheet = _activeStyleSheet;
    if (styleSheet == null) {
      return;
    }
    _estimator = SectionHeightEstimator(
      styleSheet: styleSheet,
      contentWidth: _contentWidth > 0 ? _contentWidth : 360,
    );
    _topsDirty = true;
  }

  double _heightFor(int index) {
    return _measuredHeights[index] ?? _estimateFor(index);
  }

  double _estimateFor(int index) {
    final estimator = _estimator;
    if (estimator == null) {
      return 100;
    }
    return _estimatedHeights.putIfAbsent(index, () {
      return estimator.estimateSection(_document!.sections[index]);
    });
  }

  void _ensureTops() {
    if (!_topsDirty) {
      return;
    }
    final doc = _document;
    if (doc == null || doc.sections.isEmpty) {
      _tops = const [];
      _topsDirty = false;
      return;
    }
    final spacing = _activeStyleSheet?.blockSpacing ?? 16.0;
    final contentTop = widget.topPadding + AppSpacing.md;
    final tops = List<double>.filled(doc.sections.length + 1, 0);
    var y = contentTop;
    for (var i = 0; i < doc.sections.length; i++) {
      tops[i] = y;
      y += _heightFor(i) + spacing;
    }
    tops[doc.sections.length] = y - spacing;
    _tops = tops;
    _topsDirty = false;
  }

  double _sectionTop(int index) {
    _ensureTops();
    if (index < 0 || _document == null || index >= _document!.sections.length) {
      return 0;
    }
    return _tops[index];
  }

  int _sectionIndexAt(double pixel) {
    _ensureTops();
    final count = _document?.sections.length ?? 0;
    if (count == 0) {
      return 0;
    }
    var low = 0;
    var high = count - 1;
    var answer = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_tops[mid] <= pixel) {
        answer = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return answer;
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    if (_document == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return ColoredBox(
      color: widget.readingPalette.background,
      child: AnimatedSwitcher(
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
          key: ValueKey(_docVersion),
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            widget.topPadding + AppSpacing.md,
            widget.horizontalPadding,
            AppSpacing.xxl + kBottomNavigationBarHeight,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final styleSheet = MarkdownStyleFactory.build(
                context,
                fontSize: widget.fontSize,
                lineHeight: widget.lineHeight,
                readingPalette: widget.readingPalette,
                fontFamily: widget.fontFamily,
              );
              _prepareCaches(styleSheet, constraints.maxWidth);
              return _SelectionCopyFilter(
                child: SelectionArea(
                  contextMenuBuilder: _buildSelectionContextMenu,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _sectionSlots(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _prepareCaches(MarkdownStyleSheet styleSheet, double contentWidth) {
    final width = contentWidth.isFinite && contentWidth > 0
        ? contentWidth
        : 360.0;
    final styleKey =
        '${widget.fontSize}|${widget.lineHeight}|${widget.fontFamily ?? ''}';
    final styleChanged =
        styleKey != _styleKey ||
        _lastPalette != widget.readingPalette ||
        (_contentWidth - width).abs() > 0.5 ||
        _activeStyleSheet == null;
    if (styleChanged) {
      _styleKey = styleKey;
      _lastPalette = widget.readingPalette;
      _contentWidth = width;
      _activeStyleSheet = styleSheet;
      _sectionWidgets.clear();
      _measuredHeights.clear();
      _estimatedHeights.clear();
      _estimator = SectionHeightEstimator(
        styleSheet: styleSheet,
        contentWidth: width,
      );
      _topsDirty = true;
    } else {
      _activeStyleSheet = styleSheet;
    }
    final controller = widget.searchController;
    final searchKey =
        '$_docVersion|${identityHashCode(controller)}|'
        '${controller?.normalizedQuery ?? ''}|'
        '${controller?.currentIndex ?? 0}|${controller?.pulseToken ?? 0}';
    if (searchKey != _searchGeneration) {
      _searchGeneration = searchKey;
      _sectionWidgets.clear();
    }
  }

  List<Widget> _sectionSlots() {
    final doc = _document!;
    final spacing = _activeStyleSheet?.blockSpacing ?? 16.0;
    final children = <Widget>[];
    for (var index = 0; index < doc.sections.length; index++) {
      if (index > 0) {
        children.add(SizedBox(height: spacing));
      }
      children.add(_sectionSlot(index));
    }
    return children;
  }

  Widget _sectionSlot(int index) {
    final key = _sectionSlotKeys.putIfAbsent(index, () => GlobalKey());
    if (_builtSections.contains(index)) {
      final child = _sectionWidgets.putIfAbsent(
        index,
        () => _buildSectionWidget(index),
      );
      return KeyedSubtree(key: key, child: child);
    }
    return KeyedSubtree(
      key: key,
      child: SizedBox(height: _heightFor(index)),
    );
  }

  Widget _buildSectionWidget(int index) {
    final section = _document!.sections[index];
    widget.searchController?.beginSectionPass(_sectionMatchBaseFor(index));
    final renderer = MarkdownRenderer(styleSheet: _activeStyleSheet!);
    final registry = _createBuilderRegistry(index);
    for (final entry in registry.entries) {
      renderer.registerBuilder(entry.key, entry.value);
    }
    final renderContext = MarkdownRenderContext(
      onTapLink: (url) => _handleLinkTap(context, url),
      onTapImage: (url, alt, title) =>
          _showImagePreview(context, url, alt, title),
      selectable: true,
    );
    final rendered = renderer.render(section.nodes, context: renderContext);
    return RepaintBoundary(child: rendered);
  }

  BuilderRegistry _createBuilderRegistry(int sectionIndex) {
    final section = _document!.sections[sectionIndex];
    var headingOrdinal = 0;
    return BuilderRegistry()
      ..register(
        'header',
        TocHeaderBuilder(keyForHeading: (node) {
          if (node.level > 4 || node.content.trim().isEmpty) {
            return null;
          }
          final globalIndex = section.headingBase + headingOrdinal;
          headingOrdinal++;
          return _headingKeys.putIfAbsent(globalIndex, () => GlobalKey());
        }),
      )
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

  // --- TOC navigation ---

  Future<void> jumpToTocEntry(TocEntry entry) async {
    final doc = _document;
    final controller = widget.scrollController;
    final position = _attachedPosition();
    if (doc == null || controller == null || position == null || _jumpActive) {
      return;
    }
    final sectionIndex = doc.sectionIndexForHeading(entry.index);
    if (sectionIndex < 0 || sectionIndex >= doc.sections.length) {
      return;
    }

    _jumpActive = true;
    try {
      final estimated = _estimateHeadingOffset(entry, sectionIndex, position);
      // Build the destination area so it can measure before the flight ends.
      _buildSectionsAroundOffset(estimated);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
      var target = estimated;
      final sectionContext = _sectionSlotKeys[sectionIndex]?.currentContext;
      final renderObject = sectionContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        _measuredHeights[sectionIndex] = renderObject.size.height;
        _topsDirty = true;
        target = _estimateHeadingOffset(entry, sectionIndex, position);
      }
      await controller.animateTo(
        target,
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
      );
      if (!mounted) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
      // Precise correction once the heading itself is laid out.
      final headingContext = _headingKeys[entry.index]?.currentContext;
      if (headingContext != null && headingContext.mounted) {
        await Scrollable.ensureVisible(
          headingContext,
          duration: AppMotion.fast,
          curve: AppMotion.emphasized,
          alignment: 0.08,
        );
      }
    } finally {
      _jumpActive = false;
      if (mounted) {
        _maybeUpdateBuiltWindow();
      }
    }
  }

  double _estimateHeadingOffset(
    TocEntry entry,
    int sectionIndex,
    ScrollPosition position,
  ) {
    final doc = _document!;
    final section = doc.sections[sectionIndex];
    final localOrdinal = entry.index - section.headingBase;
    var charOffset = 0;
    if (localOrdinal >= 0 && localOrdinal < section.headingCharOffsets.length) {
      charOffset = section.headingCharOffsets[localOrdinal];
    }
    final sectionHeight = _heightFor(sectionIndex);
    final fraction = section.searchTextLength == 0
        ? 0.0
        : (charOffset / section.searchTextLength).clamp(0.0, 1.0);
    final headingTop = _sectionTop(sectionIndex) + fraction * sectionHeight;
    return (headingTop - position.viewportDimension * 0.08).clamp(
      0.0,
      position.maxScrollExtent,
    );
  }

  // --- Search ---

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      _updateSearchMatches();
      _scrollToCurrentSearchMatch();
      setState(() {});
    });
  }

  void _updateSearchMatches() {
    final controller = widget.searchController;
    final doc = _document;
    if (controller == null || doc == null || !controller.hasQuery) {
      _searchMatchOffsets = const [];
      _sectionMatchBases = null;
      controller?.updateMatchCount(0);
      return;
    }
    _searchMatchOffsets = _matchOffsets(
      doc.searchText,
      controller.normalizedQuery,
    );
    controller.updateMatchCount(_searchMatchOffsets.length);
    _computeSectionMatchBases();
  }

  void _computeSectionMatchBases() {
    final doc = _document;
    if (doc == null) {
      _sectionMatchBases = null;
      return;
    }
    final sections = doc.sections;
    final bases = List<int>.filled(sections.length, 0);
    var offsetIndex = 0;
    var running = 0;
    for (var i = 0; i < sections.length; i++) {
      final start = sections[i].searchTextStart;
      while (offsetIndex < _searchMatchOffsets.length &&
          _searchMatchOffsets[offsetIndex] < start) {
        running++;
        offsetIndex++;
      }
      bases[i] = running;
    }
    _sectionMatchBases = bases;
  }

  int _sectionMatchBaseFor(int sectionIndex) {
    final bases = _sectionMatchBases;
    if (bases == null || sectionIndex < 0 || sectionIndex >= bases.length) {
      return 0;
    }
    return bases[sectionIndex];
  }

  void _scrollToCurrentSearchMatch() {
    final controller = widget.searchController;
    final position = _attachedPosition();
    final doc = _document;
    if (controller == null ||
        position == null ||
        _searchMatchOffsets.isEmpty ||
        doc == null) {
      return;
    }
    final matchIndex = controller.currentIndex.clamp(
      0,
      _searchMatchOffsets.length - 1,
    );
    final targetChar = _searchMatchOffsets[matchIndex];
    var low = 0;
    var high = doc.sections.length - 1;
    var sectionIndex = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (doc.sections[mid].searchTextStart <= targetChar) {
        sectionIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    final section = doc.sections[sectionIndex];
    final local = (targetChar - section.searchTextStart).clamp(
      0,
      section.searchTextLength,
    );
    final fraction = section.searchTextLength == 0
        ? 0.0
        : local / section.searchTextLength;
    final matchTop =
        _sectionTop(sectionIndex) + fraction * _heightFor(sectionIndex);
    final target = (matchTop - position.viewportDimension * 0.25).clamp(
      0.0,
      position.maxScrollExtent,
    );
    position.animateTo(
      target,
      duration: AppMotion.fast,
      curve: AppMotion.emphasized,
    );
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

  // --- Selection support (mirrors the package's selectable behavior) ---

  Widget _buildSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: selectableRegionState.contextMenuButtonItems.map((item) {
        if (item.type == ContextMenuButtonType.copy) {
          final originalOnPressed = item.onPressed;
          return ContextMenuButtonItem(
            label: item.label,
            type: ContextMenuButtonType.copy,
            onPressed: () {
              originalOnPressed?.call();
              _scheduleClipboardFilter();
            },
          );
        }
        return item;
      }).toList(),
    );
  }

  /// Schedules a post-frame clipboard filter to remove the invisible
  /// non-breaking-space overlay lines produced by selectable non-text blocks.
  static void _scheduleClipboardFilter() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        final filtered = _removeOverlayLines(data!.text!);
        await Clipboard.setData(ClipboardData(text: filtered));
      }
    });
  }

  static String _removeOverlayLines(String text) {
    return text
        .split('\n')
        .where((line) => !RegExp(r'^\u00A0+$').hasMatch(line))
        .join('\n');
  }

  // --- Links, images ---

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

  // --- File monitoring ---

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

/// Detects Cmd/Ctrl+C and filters overlay content from the clipboard after
/// the default copy action has run (mirrors the package's copy filter).
class _SelectionCopyFilter extends StatelessWidget {
  const _SelectionCopyFilter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyC &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          MarkdownViewerState._scheduleClipboardFilter();
        }
        return KeyEventResult.ignored;
      },
      child: child,
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
