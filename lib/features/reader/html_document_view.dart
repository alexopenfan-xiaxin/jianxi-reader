import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_settings_controller.dart';
import 'document_search_controller.dart';
import 'html_styler.dart';

class HtmlDocumentView extends StatefulWidget {
  const HtmlDocumentView({
    required this.file,
    required this.fontSize,
    required this.lineHeight,
    required this.readingPalette,
    required this.horizontalPadding,
    required this.initialScrollOffset,
    required this.onScrollOffsetChanged,
    this.topPadding = 0,
    this.searchController,
    super.key,
  });

  final File file;
  final double fontSize;
  final double lineHeight;
  final ReadingPalette readingPalette;
  final double horizontalPadding;
  final double initialScrollOffset;
  final ValueChanged<double> onScrollOffsetChanged;
  final double topPadding;
  final DocumentSearchController? searchController;

  @override
  State<HtmlDocumentView> createState() => _HtmlDocumentViewState();
}

class _HtmlDocumentViewState extends State<HtmlDocumentView>
    with WidgetsBindingObserver {
  static const _searchScript = r'''
(function() {
  if (window.jianxiSearch) return;
  const hitClass = 'jianxi-search-hit';
  const currentClass = 'jianxi-search-current';
  let hits = [];
  let index = 0;

  const style = document.createElement('style');
  style.textContent =
    '.' + hitClass + '{background:rgba(255,204,51,.46);color:#111;border-radius:3px;padding:0 1px;}' +
    '.' + currentClass + '{background:rgba(255,159,10,.72);box-shadow:0 0 0 2px rgba(255,159,10,.18);}';
  document.head.appendChild(style);

  function clear() {
    for (const mark of Array.from(document.querySelectorAll('mark.' + hitClass))) {
      const parent = mark.parentNode;
      if (!parent) continue;
      parent.replaceChild(document.createTextNode(mark.textContent || ''), mark);
      parent.normalize();
    }
    hits = [];
    index = 0;
  }

  function collectTextNodes(root) {
    const nodes = [];
    const walker = document.createTreeWalker(
      root,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node) {
          const parent = node.parentElement;
          if (!parent) return NodeFilter.FILTER_REJECT;
          const tag = parent.tagName;
          if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT') {
            return NodeFilter.FILTER_REJECT;
          }
          if (!node.nodeValue || !node.nodeValue.trim()) {
            return NodeFilter.FILTER_REJECT;
          }
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );
    let node = walker.nextNode();
    while (node) {
      nodes.push(node);
      node = walker.nextNode();
    }
    return nodes;
  }

  function highlightNode(node, query) {
    const text = node.nodeValue || '';
    const lowerText = text.toLocaleLowerCase();
    const lowerQuery = query.toLocaleLowerCase();
    let start = 0;
    let match = lowerText.indexOf(lowerQuery);
    if (match === -1) return;

    const fragment = document.createDocumentFragment();
    while (match !== -1) {
      if (match > start) {
        fragment.appendChild(document.createTextNode(text.slice(start, match)));
      }
      const end = match + query.length;
      const mark = document.createElement('mark');
      mark.className = hitClass;
      mark.textContent = text.slice(match, end);
      fragment.appendChild(mark);
      hits.push(mark);
      start = end;
      match = lowerText.indexOf(lowerQuery, start);
    }
    if (start < text.length) {
      fragment.appendChild(document.createTextNode(text.slice(start)));
    }
    node.parentNode.replaceChild(fragment, node);
  }

  function search(query) {
    clear();
    const cleanQuery = (query || '').trim();
    if (!cleanQuery) return 0;
    for (const node of collectTextNodes(document.querySelector('.reader-shell') || document.body)) {
      highlightNode(node, cleanQuery);
    }
    goTo(0);
    return hits.length;
  }

  function goTo(nextIndex) {
    if (!hits.length) return 0;
    index = Math.max(0, Math.min(nextIndex, hits.length - 1));
    for (const hit of hits) hit.classList.remove(currentClass);
    hits[index].classList.add(currentClass);
    hits[index].scrollIntoView({block: 'center', inline: 'nearest'});
    return index + 1;
  }

  window.jianxiSearch = { clear, search, goTo };
})();
''';

  late final WebViewController _controller;
  Timer? _scrollOffsetTimer;
  bool _isLoading = true;
  bool _hasRestoredScrollOffset = false;
  bool _isSearchScriptReady = false;
  bool _isApplyingSearch = false;
  bool _isAppActive = true;
  String _lastAppliedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.searchController?.addListener(_handleSearchChanged);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.readingPalette.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
              unawaited(_finishPageLoad());
            }
          },
        ),
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant HtmlDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_handleSearchChanged);
      widget.searchController?.addListener(_handleSearchChanged);
      _handleSearchChanged();
    }
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.readingPalette != widget.readingPalette ||
        oldWidget.horizontalPadding != widget.horizontalPadding) {
      _hasRestoredScrollOffset = false;
      _controller.setBackgroundColor(widget.readingPalette.background);
      _loadHtml();
    }
  }

  @override
  void dispose() {
    _scrollOffsetTimer?.cancel();
    widget.searchController?.removeListener(_handleSearchChanged);
    unawaited(_reportScrollOffset());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (_isAppActive && !_isLoading) {
      _startScrollOffsetTimer();
      unawaited(_reportScrollOffset());
    } else {
      _scrollOffsetTimer?.cancel();
    }
  }

  Future<void> _loadHtml() async {
    _scrollOffsetTimer?.cancel();
    _isSearchScriptReady = false;
    _lastAppliedSearchQuery = '';
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final rawHtml = await widget.file.readAsString();
    final html = HtmlStyler.buildAssimilatedHtml(
      rawHtml,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      readingPalette: widget.readingPalette,
      horizontalPadding: widget.horizontalPadding,
      topPadding: widget.topPadding,
    );
    final baseUrl = widget.file.parent.uri.toString();
    if (!mounted) {
      return;
    }
    await _controller.loadHtmlString(html, baseUrl: baseUrl);
  }

  void _startScrollOffsetTimer() {
    if (_isLoading || !_isAppActive) {
      return;
    }
    _scrollOffsetTimer?.cancel();
    _scrollOffsetTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _reportScrollOffset(),
    );
  }

  Future<void> _finishPageLoad() async {
    await _restoreScrollOffset();
    await _installSearchScript();
    await _runSearch();
    _startScrollOffsetTimer();
  }

  Future<void> _restoreScrollOffset() async {
    if (_hasRestoredScrollOffset || widget.initialScrollOffset <= 0) {
      _hasRestoredScrollOffset = true;
      return;
    }
    try {
      await _controller.scrollTo(0, widget.initialScrollOffset.round());
      _hasRestoredScrollOffset = true;
    } catch (error) {
      debugPrint('[HtmlDocumentView] restore scroll offset failed: $error');
    }
  }

  Future<void> _reportScrollOffset() async {
    if (_isLoading) {
      return;
    }
    try {
      final position = await _controller.getScrollPosition();
      widget.onScrollOffsetChanged(position.dy);
    } catch (error) {
      debugPrint('[HtmlDocumentView] read scroll offset failed: $error');
    }
  }

  void _handleSearchChanged() {
    if (_isApplyingSearch) {
      return;
    }
    final query = widget.searchController?.normalizedQuery ?? '';
    if (query != _lastAppliedSearchQuery) {
      unawaited(_runSearch());
      return;
    }
    unawaited(_goToCurrentSearchMatch());
  }

  Future<void> _installSearchScript() async {
    if (_isSearchScriptReady) {
      return;
    }
    try {
      await _controller.runJavaScript(_searchScript);
      _isSearchScriptReady = true;
    } catch (error) {
      debugPrint('[HtmlDocumentView] install search script failed: $error');
    }
  }

  Future<void> _runSearch() async {
    final searchController = widget.searchController;
    if (_isLoading || searchController == null) {
      return;
    }
    await _installSearchScript();
    if (!_isSearchScriptReady) {
      return;
    }

    final query = searchController.normalizedQuery;
    _lastAppliedSearchQuery = query;
    _isApplyingSearch = true;
    try {
      if (query.isEmpty) {
        await _controller.runJavaScript('window.jianxiSearch.clear();');
        searchController.updateMatchCount(0);
        return;
      }
      final result = await _controller.runJavaScriptReturningResult(
        'window.jianxiSearch.search(${jsonEncode(query)});',
      );
      searchController.updateMatchCount(_parseJsInt(result));
      await _goToCurrentSearchMatch();
    } catch (error) {
      debugPrint('[HtmlDocumentView] run search failed: $error');
    } finally {
      _isApplyingSearch = false;
    }
  }

  Future<void> _goToCurrentSearchMatch() async {
    final searchController = widget.searchController;
    if (_isLoading ||
        !_isSearchScriptReady ||
        searchController == null ||
        !searchController.hasMatches) {
      return;
    }
    try {
      await _controller.runJavaScript(
        'window.jianxiSearch.goTo(${searchController.currentIndex});',
      );
    } catch (error) {
      debugPrint('[HtmlDocumentView] go to search match failed: $error');
    }
  }

  int _parseJsInt(Object value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
