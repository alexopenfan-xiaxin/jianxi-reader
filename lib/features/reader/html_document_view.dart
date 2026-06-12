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
    this.topPadding = 0,
    this.searchController,
    this.onScroll,
    this.onPageReady,
    super.key,
  });

  final File file;
  final double fontSize;
  final double lineHeight;
  final ReadingPalette readingPalette;
  final double horizontalPadding;
  final double topPadding;
  final DocumentSearchController? searchController;

  /// Called with the current scroll ratio (0.0 – 1.0) whenever the
  /// WebView content is scrolled.
  final ValueChanged<double>? onScroll;

  /// Called once after the page finishes loading and scripts are ready.
  final VoidCallback? onPageReady;

  @override
  State<HtmlDocumentView> createState() => HtmlDocumentViewState();
}

class HtmlDocumentViewState extends State<HtmlDocumentView> {
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

  /// Injected after page load to report scroll position to Flutter.
  static const _scrollBridgeScript = r'''
(function() {
  if (window.__jianxiScrollBridge) return;
  window.__jianxiScrollBridge = true;
  let ticking = false;
  window.addEventListener('scroll', function() {
    if (!ticking) {
      ticking = true;
      requestAnimationFrame(function() {
        const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
        const ratio = maxScroll > 0 ? (window.scrollY / maxScroll) : 0;
        FlutterBridge.postMessage(String(ratio));
        ticking = false;
      });
    }
  }, {passive: true});
})();
''';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSearchScriptReady = false;
  bool _isScrollBridgeReady = false;
  bool _isApplyingSearch = false;
  String _lastAppliedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.searchController?.addListener(_handleSearchChanged);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.readingPalette.background)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          final ratio = double.tryParse(message.message);
          if (ratio != null) {
            widget.onScroll?.call(ratio);
          }
        },
      )
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
      _controller.setBackgroundColor(widget.readingPalette.background);
      _loadHtml();
    }
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_handleSearchChanged);
    super.dispose();
  }

  Future<void> _loadHtml() async {
    _isSearchScriptReady = false;
    _isScrollBridgeReady = false;
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

  Future<void> _finishPageLoad() async {
    await _installSearchScript();
    await _installScrollBridge();
    await _runSearch();
    widget.onPageReady?.call();
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

  Future<void> _installScrollBridge() async {
    if (_isScrollBridgeReady) return;
    try {
      await _controller.runJavaScript(_scrollBridgeScript);
      _isScrollBridgeReady = true;
    } catch (error) {
      debugPrint('[HtmlDocumentView] install scroll bridge failed: $error');
    }
  }

  /// Scroll the WebView content to the given ratio (0.0 – 1.0).
  Future<void> jumpToRatio(double ratio) async {
    final clamped = ratio.clamp(0.0, 1.0);
    try {
      await _controller.runJavaScript(
        '(function(){'
        'var m=document.documentElement.scrollHeight-window.innerHeight;'
        'if(m>0){window.scrollTo({top:m*$clamped,behavior:"smooth"});}'
        '})();',
      );
    } catch (error) {
      debugPrint('[HtmlDocumentView] jump to ratio failed: $error');
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
