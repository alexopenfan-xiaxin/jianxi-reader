import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight.dart' show Node, highlight;

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

class _SyntaxHighlightCodeBlockWidgetState
    extends State<_SyntaxHighlightCodeBlockWidget> {
  bool _copied = false;
  Timer? _copyResetTimer;

  static const _languageAliases = {
    'sh': 'shell',
    'zsh': 'bash',
    'console': 'bash',
    'rest': 'http',
    'http-request': 'http',
    'js': 'javascript',
    'jsx': 'javascript',
    'node': 'javascript',
    'nodejs': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'kt': 'kotlin',
    'rs': 'rust',
    'golang': 'go',
    'yml': 'yaml',
    'jsonc': 'json',
    'json5': 'json',
    'mysql': 'sql',
    'postgres': 'pgsql',
    'postgresql': 'pgsql',
    'psql': 'pgsql',
    'sqlite': 'sql',
    'html': 'xml',
    'htm': 'xml',
    'c': 'cpp',
    'c++': 'cpp',
    'cc': 'cpp',
    'cxx': 'cpp',
    'csharp': 'cs',
    'cs': 'cs',
    'md': 'markdown',
    'docker': 'dockerfile',
    'ps1': 'powershell',
    'proto': 'protobuf',
    'rb': 'ruby',
    'serverpod': 'yaml',
    'serverpod_protocol': 'yaml',
  };

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  String? get _highlightLanguage {
    final language = widget.language?.toLowerCase();
    if (language == null) return null;
    return _languageAliases[language] ?? language;
  }

  TextStyle _codeTextStyle() {
    final bgColor = widget.styleSheet.codeBlockDecoration?.color;
    final isDarkBg = bgColor != null && bgColor.computeLuminance() < 0.5;
    return (widget.styleSheet.codeBlockStyle ?? const TextStyle()).copyWith(
      color: widget.styleSheet.codeBlockStyle?.color ??
          (isDarkBg ? const Color(0xFFE0E0E0) : const Color(0xFF1E1E1E)),
    );
  }

  Widget _buildCodeContent(BuildContext context) {
    if (widget.searchController?.hasQuery ?? false) {
      return _buildPlainCode();
    }
    if (_highlightLanguage != null) {
      try {
        final theme = Theme.of(context).brightness == Brightness.dark
            ? atomOneDarkTheme
            : githubTheme;
        if (_highlightLanguage == 'http') {
          final highlighted = _highlightHttpCode(theme);
          if (widget.selectable) return Text.rich(highlighted);
          return RichText(text: highlighted);
        }
        final result = highlight.parse(
          widget.code,
          language: _highlightLanguage!,
        );
        final nodes = result.nodes ?? const <Node>[];
        final highlighted = TextSpan(
          style: _codeTextStyle(),
          children: _hasStyledNode(nodes, theme)
              ? _convertNodes(nodes, theme)
              : _highlightLines(_highlightLanguage!, theme),
        );
        if (widget.selectable) return Text.rich(highlighted);
        return RichText(text: highlighted);
      } catch (e) {
        debugPrint(
          '[SyntaxHighlight] highlight error '
          '(lang=${widget.language}, code=${widget.code.length} chars): $e',
        );
      }
    }
    return _buildPlainCode();
  }

  bool _hasStyledNode(List<Node> nodes, Map<String, TextStyle> theme) {
    for (final node in nodes) {
      if (theme[node.className] != null ||
          node.children != null && _hasStyledNode(node.children!, theme)) {
        return true;
      }
    }
    return false;
  }

  List<TextSpan> _highlightLines(
    String language,
    Map<String, TextStyle> theme,
  ) {
    final spans = <TextSpan>[];
    final lines = widget.code.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final result = highlight.parse(lines[i], language: language);
      spans.addAll(_convertNodes(result.nodes ?? const <Node>[], theme));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  TextSpan _highlightHttpCode(Map<String, TextStyle> theme) {
    final spans = <TextSpan>[];
    final request = RegExp(
      r'^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(.+)$',
    );
    final response = RegExp(r'^(HTTP/\d(?:\.\d)?\s+)(\d{3})(.*)$');
    final query = RegExp(r'^(\s*[?&])([A-Za-z0-9_.-]+)(=)(.*)$');
    final header = RegExp(r'^([A-Za-z0-9-]+)(:)(.*)$');
    final lines = widget.code.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final requestMatch = request.firstMatch(line);
      final responseMatch = response.firstMatch(line);
      final queryMatch = query.firstMatch(line);
      final headerMatch = header.firstMatch(line);
      if (requestMatch != null) {
        spans.add(
          TextSpan(text: requestMatch.group(1), style: theme['keyword']),
        );
        spans.add(
          TextSpan(
            text: ' ${requestMatch.group(2)}',
            style: theme['string'],
          ),
        );
      } else if (responseMatch != null) {
        spans.add(TextSpan(text: responseMatch.group(1)));
        spans.add(
          TextSpan(text: responseMatch.group(2), style: theme['number']),
        );
        spans.add(TextSpan(text: responseMatch.group(3)));
      } else if (queryMatch != null) {
        spans.add(TextSpan(text: queryMatch.group(1)));
        spans.add(
          TextSpan(text: queryMatch.group(2), style: theme['attribute']),
        );
        spans.add(TextSpan(text: queryMatch.group(3)));
        spans.add(TextSpan(text: queryMatch.group(4), style: theme['string']));
      } else if (headerMatch != null) {
        spans.add(
          TextSpan(text: headerMatch.group(1), style: theme['attribute']),
        );
        spans.add(
          TextSpan(
            text: '${headerMatch.group(2)}${headerMatch.group(3)}',
          ),
        );
      } else {
        spans.add(TextSpan(text: line));
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return TextSpan(style: _codeTextStyle(), children: spans);
  }

  List<TextSpan> _convertNodes(
    List<Node> nodes,
    Map<String, TextStyle> theme,
  ) {
    return [
      for (final node in nodes)
        if (node.value != null)
          TextSpan(text: node.value, style: theme[node.className])
        else if (node.children != null)
          TextSpan(
            style: theme[node.className],
            children: _convertNodes(node.children!, theme),
          ),
    ];
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
    var matches = 0;
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
      matches++;
      start = matchEnd;
      if (matches >= DocumentSearchController.maxMatches) {
        spans.add(TextSpan(text: widget.code.substring(start)));
        break;
      }
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
    final hasToolbar = widget.showLanguageTag && widget.language != null ||
        widget.showCopyButton;

    return RepaintBoundary(
      child: Container(
        decoration: widget.styleSheet.codeBlockDecoration?.copyWith(
          boxShadow: null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasToolbar)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
            Container(
              padding: widget.styleSheet.codeBlockPadding,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildCodeContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mindmap Plugin (```mindmap) ──────────────────────────────────────────
