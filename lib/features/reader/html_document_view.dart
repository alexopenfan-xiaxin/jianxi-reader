import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_settings_controller.dart';
import '../../core/file_rules.dart';
import 'document_search_controller.dart';
import 'html_styler.dart';
import 'toc_service.dart';

/// Top-level function for [compute] to run HTML styling in an isolate.
String _buildHtmlInIsolate(Map<String, dynamic> args) {
  final palette = ReadingPalette(
    background: Color(args['bg'] as int),
    foreground: Color(args['fg'] as int),
    muted: Color(args['muted'] as int),
    surface: Color(args['surface'] as int),
    border: Color(args['border'] as int),
    link: Color(args['link'] as int),
    codeBackground: Color(args['codeBg'] as int),
  );
  return HtmlStyler.buildAssimilatedHtml(
    args['rawHtml'] as String,
    fontSize: args['fontSize'] as double,
    lineHeight: args['lineHeight'] as double,
    readingPalette: palette,
    horizontalPadding: args['hPadding'] as double,
    topPadding: args['topPadding'] as double,
  );
}

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
    this.onTocChanged,
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

  final ValueChanged<List<TocEntry>>? onTocChanged;

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

  function highlightNode(node, query, maxHits) {
    const text = node.nodeValue || '';
    const lowerText = text.toLocaleLowerCase();
    const lowerQuery = query.toLocaleLowerCase();
    let start = 0;
    let match = lowerText.indexOf(lowerQuery);
    if (match === -1) return;

    const fragment = document.createDocumentFragment();
    while (match !== -1) {
      if (hits.length >= maxHits) break;
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

  function search(query, maxHits) {
    clear();
    maxHits = maxHits || 200;
    const cleanQuery = (query || '').trim();
    if (!cleanQuery) return JSON.stringify({count: 0, truncated: false});
    const nodes = collectTextNodes(document.querySelector('.reader-shell') || document.body);
    let truncated = false;
    for (const node of nodes) {
      if (hits.length >= maxHits) { truncated = true; break; }
      highlightNode(node, cleanQuery, maxHits);
    }
    if (hits.length >= maxHits) truncated = true;
    goTo(0);
    return JSON.stringify({count: hits.length, truncated: truncated});
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
  /// Embedded directly in the HTML for maximum reliability.
  static const _scrollBridgeScript = r'''
(function() {
  if (window.__jianxiScrollBridge) return;
  window.__jianxiScrollBridge = true;
  var lastRatio = -1;
  function sendRatio() {
    var maxScroll = document.documentElement.scrollHeight - window.innerHeight;
    var ratio = maxScroll > 0 ? (window.scrollY / maxScroll) : 0;
    ratio = Math.max(0, Math.min(1, ratio));
    if (Math.abs(ratio - lastRatio) > 0.0005) {
      lastRatio = ratio;
      if (typeof FlutterBridge !== 'undefined') {
        FlutterBridge.postMessage(String(ratio));
      }
    }
  }
  window.addEventListener('scroll', sendRatio, {passive: true});
  // Polling fallback: ensures scroll events fire even if the native
  // scroll listener is not triggered by certain WebView implementations.
  setInterval(sendRatio, 300);
  // Send initial position.
  sendRatio();
})();
''';

  static const _tocScript = r'''
(function() {
  const headings = Array.from(document.querySelectorAll('h1,h2,h3,h4'));
  return JSON.stringify(headings.map(function(heading, index) {
    if (!heading.id) {
      heading.id = 'jianxi-heading-' + index;
    }
    return {
      id: heading.id,
      level: Number(heading.tagName.substring(1)),
      title: (heading.innerText || heading.textContent || '').trim()
    };
  }));
})();
''';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSearchScriptReady = false;
  bool _isScrollBridgeReady = false;
  bool _isApplyingSearch = false;
  String _lastAppliedSearchQuery = '';
  Timer? _searchDebounce;

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
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
              _finishPageLoad().catchError((e) {
                debugPrint('[HtmlDocumentView] finish page load error: $e');
              });
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
    _searchDebounce?.cancel();
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
    const isolateThreshold = 50 * 1024; // 50 KB
    var html = rawHtml.length > isolateThreshold
        ? await compute(_buildHtmlInIsolate, {
            'rawHtml': rawHtml,
            'fontSize': widget.fontSize,
            'lineHeight': widget.lineHeight,
            'bg': widget.readingPalette.background.toARGB32(),
            'fg': widget.readingPalette.foreground.toARGB32(),
            'muted': widget.readingPalette.muted.toARGB32(),
            'surface': widget.readingPalette.surface.toARGB32(),
            'border': widget.readingPalette.border.toARGB32(),
            'link': widget.readingPalette.link.toARGB32(),
            'codeBg': widget.readingPalette.codeBackground.toARGB32(),
            'hPadding': widget.horizontalPadding,
            'topPadding': widget.topPadding,
          })
        : HtmlStyler.buildAssimilatedHtml(
            rawHtml,
            fontSize: widget.fontSize,
            lineHeight: widget.lineHeight,
            readingPalette: widget.readingPalette,
            horizontalPadding: widget.horizontalPadding,
            topPadding: widget.topPadding,
          );
    // Embed the scroll bridge script directly into the HTML content
    // so it runs in the same JS context as the loaded page.
    html = html.replaceFirst('</body>', '<script>$_scrollBridgeScript</script></body>');
    final baseUrl = widget.file.parent.uri.toString();
    if (!mounted) {
      return;
    }
    await _controller.loadHtmlString(html, baseUrl: baseUrl);
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) {
      _showNavigationMessage('无法识别的链接');
      return NavigationDecision.prevent;
    }
    if (uri.scheme == 'about' || uri.toString() == widget.file.uri.toString()) {
      return NavigationDecision.navigate;
    }
    if (uri.scheme == 'file') {
      final path = uri.toFilePath();
      if (_isSameDirectoryHtml(path)) {
        return NavigationDecision.navigate;
      }
      if (DocumentFileRules.isSupportedPath(path)) {
        _showNavigationMessage('暂不支持从 HTML 内跳转到其他文档');
      } else {
        _showNavigationMessage('不支持的本地链接');
      }
      return NavigationDecision.prevent;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      unawaited(_confirmOpenExternal(uri));
      return NavigationDecision.prevent;
    }
    if (uri.scheme == 'mailto' || uri.scheme == 'tel') {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      return NavigationDecision.prevent;
    }
    if (uri.scheme.isEmpty) {
      return NavigationDecision.navigate;
    }
    _showNavigationMessage('不支持的链接类型：${uri.scheme}');
    return NavigationDecision.prevent;
  }

  bool _isSameDirectoryHtml(String path) {
    return File(path).parent.path == widget.file.parent.path &&
        (path.toLowerCase().endsWith('.html') ||
            path.toLowerCase().endsWith('.htm'));
  }

  Future<void> _confirmOpenExternal(Uri uri) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开外部链接'),
        content: Text(uri.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showNavigationMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _finishPageLoad() async {
    await _installSearchScript();
    // The scroll bridge script is embedded in the HTML content,
    // so it's already active. Mark as ready and run backup injection.
    _isScrollBridgeReady = true;
    await _loadToc();
    await _runSearch();
    widget.onPageReady?.call();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_isApplyingSearch) return;
      final query = widget.searchController?.normalizedQuery ?? '';
      if (query != _lastAppliedSearchQuery) {
        unawaited(_runSearch());
        return;
      }
      unawaited(_goToCurrentSearchMatch());
    });
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

  /// Scroll the WebView content to the given ratio (0.0 – 1.0).
  Future<void> jumpToRatio(double ratio) async {
    final clamped = ratio.clamp(0.0, 1.0);
    final target = (clamped * 1000).round();
    try {
      await _controller.runJavaScript(
        'var m=document.documentElement.scrollHeight-window.innerHeight;'
        'if(m>0){window.scrollTo(0,m*$target/1000);}',
      );
    } catch (error) {
      debugPrint('[HtmlDocumentView] jump to ratio failed: $error');
    }
  }

  Future<void> jumpToTocEntry(TocEntry entry) async {
    final id = entry.htmlId;
    if (id == null || id.isEmpty) {
      return;
    }
    try {
      await _controller.runJavaScript(
        'var h=document.getElementById(${jsonEncode(id)});'
        'if(h){h.scrollIntoView({block:"start",inline:"nearest"});}',
      );
    } catch (error) {
      debugPrint('[HtmlDocumentView] jump to toc failed: $error');
    }
  }

  Future<void> _loadToc() async {
    final callback = widget.onTocChanged;
    if (callback == null || _isLoading) {
      return;
    }
    try {
      final result = await _controller.runJavaScriptReturningResult(_tocScript);
      callback(TocService.fromHtmlJson(result));
    } catch (error) {
      debugPrint('[HtmlDocumentView] build toc failed: $error');
      callback(const []);
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
        'window.jianxiSearch.search(${jsonEncode(query)}, 200);',
      );
      final parsed = _parseSearchResult(result);
      searchController.updateMatchCount(parsed.count);
      if (parsed.truncated) {
        debugPrint(
          '[HtmlDocumentView] search results truncated at ${parsed.count} matches',
        );
      }
      await _goToCurrentSearchMatch();
    } catch (error) {
      debugPrint('[HtmlDocumentView] run search failed: $error');
    } finally {
      _isApplyingSearch = false;
    }
  }

  _SearchResult _parseSearchResult(Object value) {
    try {
      final raw = value.toString();
      // The JS may return a JSON string wrapped in quotes.
      final unwrapped = raw.startsWith('"') && raw.endsWith('"')
          ? jsonDecode(raw) as String
          : raw;
      final data = jsonDecode(unwrapped) as Map<String, dynamic>;
      return _SearchResult(
        count: (data['count'] as int?) ?? 0,
        truncated: (data['truncated'] as bool?) ?? false,
      );
    } catch (_) {
      // Fallback: treat as plain integer (legacy format).
      return _SearchResult(count: _parseJsInt(value), truncated: false);
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

class _SearchResult {
  const _SearchResult({required this.count, required this.truncated});

  final int count;
  final bool truncated;
}
