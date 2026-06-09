import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

import '../../document_search_controller.dart';

class SyntaxHighlightCodeBlockBuilder extends MarkdownWidgetBuilder {
  const SyntaxHighlightCodeBlockBuilder({
    this.showCopyButton = true,
    this.showLanguageTag = true,
    this.searchController,
  });

  final bool showCopyButton;
  final bool showLanguageTag;
  final DocumentSearchController? searchController;

  @override
  bool canBuild(MarkdownNode node) => node is CodeBlockNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final codeBlockNode = node as CodeBlockNode;
    return _SyntaxHighlightCodeBlockWidget(
      code: codeBlockNode.code,
      language: codeBlockNode.language,
      styleSheet: styleSheet,
      showCopyButton: showCopyButton,
      showLanguageTag: showLanguageTag,
      selectable: context.selectable,
      searchController: searchController,
    );
  }
}

class _SyntaxHighlightCodeBlockWidget extends StatefulWidget {
  const _SyntaxHighlightCodeBlockWidget({
    required this.code,
    required this.language,
    required this.styleSheet,
    required this.showCopyButton,
    required this.showLanguageTag,
    this.searchController,
    this.selectable = false,
  });

  final String code;
  final String? language;
  final MarkdownStyleSheet styleSheet;
  final bool showCopyButton;
  final bool showLanguageTag;
  final bool selectable;
  final DocumentSearchController? searchController;

  @override
  State<_SyntaxHighlightCodeBlockWidget> createState() =>
      _SyntaxHighlightCodeBlockWidgetState();
}

class _HighlightCacheKey {
  const _HighlightCacheKey({
    required this.language,
    required this.themeId,
    required this.codeLength,
    required this.codeHash,
  });

  final String language;
  final String themeId;
  final int codeLength;
  final int codeHash;

  @override
  bool operator ==(Object other) {
    return other is _HighlightCacheKey &&
        other.language == language &&
        other.themeId == themeId &&
        other.codeLength == codeLength &&
        other.codeHash == codeHash;
  }

  @override
  int get hashCode => Object.hash(language, themeId, codeLength, codeHash);
}

class _SyntaxHighlightCodeBlockWidgetState
    extends State<_SyntaxHighlightCodeBlockWidget> {
  static bool _initialized = false;
  static bool _initFailed = false;
  static Future<void>? _initFuture;
  static HighlighterTheme? _lightTheme;
  static HighlighterTheme? _darkTheme;
  static final _highlightCache = <_HighlightCacheKey, TextSpan>{};
  static const _highlightCacheLimit = 80;

  bool _highlightReady = false;
  bool _copied = false;
  Timer? _copyResetTimer;

  /// Only languages that have actual grammar files in syntax_highlight 0.5.0.
  /// If a grammar is missing, Highlighter.initialize() throws and kills ALL
  /// highlighting.  Keep this list in sync with the package's grammars/ dir.
  static final List<String> _supportedLanguages = [
    'dart', 'python', 'javascript', 'typescript', 'java', 'kotlin',
    'swift', 'rust', 'go', 'sql', 'yaml', 'json', 'html', 'css',
    // Not available in 0.5.0: cpp, c, ruby, php, shell, xml
  ];

  @override
  void initState() {
    super.initState();
    if (_initialized) {
      _highlightReady = true;
      return;
    }
    _initFuture ??= _doInitialize().then((ok) {
      if (!ok) {
        debugPrint('[SyntaxHighlight] init failed — falling back to plain code');
      }
      if (mounted) setState(() => _highlightReady = true);
    });
  }

  /// Returns true if initialization succeeded.
  static Future<bool> _doInitialize() async {
    try {
      await Highlighter.initialize(_supportedLanguages);
      _lightTheme = await HighlighterTheme.loadLightTheme();
      _darkTheme = await HighlighterTheme.loadDarkTheme();
      debugPrint('[SyntaxHighlight] init OK (${_supportedLanguages.length} grammars)');
      _initialized = true;
      _initFailed = false;
      return true;
    } catch (e) {
      debugPrint('[SyntaxHighlight] init error: $e');
      // themes remain null → plain code fallback
      _initialized = true;
      _initFailed = true;
      return false;
    }
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  bool get _canHighlight =>
      widget.language != null &&
      _supportedLanguages.contains(widget.language!.toLowerCase());

  TextStyle _codeTextStyle() {
    final bgColor = widget.styleSheet.codeBlockDecoration?.color;
    final isDarkBg = bgColor != null && bgColor.computeLuminance() < 0.5;
    return (widget.styleSheet.codeBlockStyle ?? const TextStyle()).copyWith(
      color: widget.styleSheet.codeBlockStyle?.color ??
          (isDarkBg ? const Color(0xFFE0E0E0) : const Color(0xFF1E1E1E)),
    );
  }

  Widget _buildCodeContent(
    BuildContext context,
    HighlighterTheme? theme,
    String themeId,
  ) {
    if (widget.searchController?.hasQuery ?? false) {
      return _buildPlainCode();
    }
    if (theme != null && _canHighlight) {
      try {
        final lang = widget.language!.toLowerCase();
        final highlighted = _highlightCode(
          language: lang,
          theme: theme,
          themeId: themeId,
        );
        if (widget.selectable) return Text.rich(highlighted);
        return RichText(text: highlighted);
      } catch (e) {
        debugPrint('[SyntaxHighlight] highlight error (lang=${widget.language}, code=${widget.code.length} chars): $e');
        // fall through to plain code
      }
    }
    return _buildPlainCode();
  }

  Widget _buildPlainCode() {
    final style = _codeTextStyle();
    final highlighted = _searchHighlightedCodeSpan(style);
    if (highlighted != null) {
      if (widget.selectable) {
        return Text.rich(highlighted);
      }
      return RichText(text: highlighted);
    }
    if (widget.selectable) {
      return Text.rich(TextSpan(text: widget.code, style: style));
    }
    return Text(widget.code, style: style);
  }

  TextSpan? _searchHighlightedCodeSpan(TextStyle style) {
    final query = widget.searchController?.normalizedQuery ?? '';
    if (query.isEmpty || widget.code.isEmpty) {
      return null;
    }
    final lowerCode = widget.code.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    var matchStart = lowerCode.indexOf(lowerQuery);
    while (matchStart != -1) {
      if (matchStart > start) {
        spans.add(TextSpan(text: widget.code.substring(start, matchStart)));
      }
      final matchEnd = matchStart + query.length;
      spans.add(
        TextSpan(
          text: widget.code.substring(matchStart, matchEnd),
          style: const TextStyle(
            backgroundColor: Color(0x55FFCC33),
            color: Colors.black,
          ),
        ),
      );
      start = matchEnd;
      matchStart = lowerCode.indexOf(lowerQuery, start);
    }
    if (start == 0) {
      return null;
    }
    if (start < widget.code.length) {
      spans.add(TextSpan(text: widget.code.substring(start)));
    }
    return TextSpan(style: style, children: spans);
  }

  TextSpan _highlightCode({
    required String language,
    required HighlighterTheme theme,
    required String themeId,
  }) {
    final key = _HighlightCacheKey(
      language: language,
      themeId: themeId,
      codeLength: widget.code.length,
      codeHash: _stableCodeHash(widget.code),
    );
    final cached = _highlightCache.remove(key);
    if (cached != null) {
      _highlightCache[key] = cached;
      return cached;
    }

    final highlighter = Highlighter(language: language, theme: theme);
    final highlighted = highlighter.highlight(widget.code);
    _highlightCache[key] = highlighted;
    while (_highlightCache.length > _highlightCacheLimit) {
      _highlightCache.remove(_highlightCache.keys.first);
    }
    return highlighted;
  }

  int _stableCodeHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final theme = brightness == Brightness.dark ? _darkTheme : _lightTheme;
    final themeId = brightness == Brightness.dark ? 'dark' : 'light';

    return RepaintBoundary(
      child: Container(
        decoration: widget.styleSheet.codeBlockDecoration?.copyWith(
          boxShadow: null,
        ),
        child: Stack(
          children: [
          Container(
            padding: widget.styleSheet.codeBlockPadding,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _highlightReady
                  ? _buildCodeContent(context, theme, themeId)
                  : _buildPlainCode(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLanguageTag && widget.language != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.language!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_initFailed && _canHighlight)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Tooltip(
                            message: '代码高亮失败，请查看调试日志',
                            child: Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                if (widget.showLanguageTag && widget.language != null)
                  const SizedBox(width: 8),
                if (widget.showCopyButton)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: _copyToClipboard,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _copied
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied ? Icons.check : Icons.content_copy,
                              size: 16,
                              color: _copied
                                  ? Colors.green[700]
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                            ),
                            if (_copied) ...[
                              const SizedBox(width: 4),
                              Text(
                                '已复制',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// ── Mindmap Plugin (```mindmap) ──────────────────────────────────────────
