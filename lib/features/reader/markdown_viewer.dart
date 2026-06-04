import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design_tokens.dart';

// ── Underline Plugin (++text++) ───────────────────────────────────────────

class UnderlineNode extends MarkdownNode {
  const UnderlineNode(this.text);
  final String text;

  @override
  String get type => 'underline';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  UnderlineNode copyWith({String? text}) => UnderlineNode(text ?? this.text);

  @override
  String toString() => 'UnderlineNode(text: $text)';
}

class UnderlinePlugin extends InlineParserPlugin {
  const UnderlinePlugin();

  @override
  String get id => 'underline';
  @override
  String get name => 'Underline Plugin';
  @override
  String get triggerCharacter => '+';
  @override
  int get priority => 15;

  @override
  bool canParse(String text, int index) {
    if (index + 1 >= text.length) return false;
    return text[index] == '+' && text[index + 1] == '+';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex + 1 >= text.length) return null;
    if (text[startIndex] != '+' || text[startIndex + 1] != '+') return null;

    var i = startIndex + 2;
    while (i + 1 < text.length) {
      if (text[i] == '+' && text[i + 1] == '+') {
        final content = text.substring(startIndex + 2, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: UnderlineNode(content),
          consumed: i - startIndex + 2,
        );
      }
      i++;
    }
    return null;
  }
}

class UnderlineBuilder extends MarkdownWidgetBuilder {
  const UnderlineBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is UnderlineNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final underlineNode = node as UnderlineNode;
    final style = (styleSheet.textStyle ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
    );
    return Text(underlineNode.text, style: style);
  }
}

// ── Highlight Plugin (==text==) ─────────────────────────────────────────

class HighlightNode extends MarkdownNode {
  const HighlightNode(this.text);
  final String text;

  @override
  String get type => 'highlight';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  HighlightNode copyWith({String? text}) => HighlightNode(text ?? this.text);

  @override
  String toString() => 'HighlightNode(text: $text)';
}

class HighlightPlugin extends InlineParserPlugin {
  const HighlightPlugin();

  @override
  String get id => 'highlight';
  @override
  String get name => 'Highlight Plugin';
  @override
  String get triggerCharacter => '=';
  @override
  int get priority => 14;

  @override
  bool canParse(String text, int index) {
    if (index + 1 >= text.length) return false;
    return text[index] == '=' && text[index + 1] == '=';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex + 1 >= text.length) return null;
    if (text[startIndex] != '=' || text[startIndex + 1] != '=') return null;

    var i = startIndex + 2;
    while (i + 1 < text.length) {
      if (text[i] == '=' && text[i + 1] == '=') {
        final content = text.substring(startIndex + 2, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: HighlightNode(content),
          consumed: i - startIndex + 2,
        );
      }
      i++;
    }
    return null;
  }
}

class HighlightBuilder extends MarkdownWidgetBuilder {
  const HighlightBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is HighlightNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final highlightNode = node as HighlightNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEB3B).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(highlightNode.text, style: baseStyle),
    );
  }
}

// ── Superscript Plugin (^text^) ─────────────────────────────────────────

class SuperscriptNode extends MarkdownNode {
  const SuperscriptNode(this.text);
  final String text;

  @override
  String get type => 'superscript';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  SuperscriptNode copyWith({String? text}) => SuperscriptNode(text ?? this.text);

  @override
  String toString() => 'SuperscriptNode(text: $text)';
}

class SuperscriptPlugin extends InlineParserPlugin {
  const SuperscriptPlugin();

  @override
  String get id => 'superscript';
  @override
  String get name => 'Superscript Plugin';
  @override
  String get triggerCharacter => '^';
  @override
  int get priority => 14;

  @override
  bool canParse(String text, int index) {
    if (index >= text.length) return false;
    return text[index] == '^';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex >= text.length) return null;
    if (text[startIndex] != '^') return null;

    var i = startIndex + 1;
    while (i < text.length) {
      if (text[i] == '^') {
        final content = text.substring(startIndex + 1, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: SuperscriptNode(content),
          consumed: i - startIndex + 1,
        );
      }
      i++;
    }
    return null;
  }
}

class SuperscriptBuilder extends MarkdownWidgetBuilder {
  const SuperscriptBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is SuperscriptNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final supNode = node as SuperscriptNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Text(
      supNode.text,
      style: baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 14) * 0.72,
        textBaseline: TextBaseline.alphabetic,
      ),
      textScaler: const TextScaler.linear(1),
    );
  }
}

// ── Subscript Plugin (~text~) ───────────────────────────────────────────

class SubscriptNode extends MarkdownNode {
  const SubscriptNode(this.text);
  final String text;

  @override
  String get type => 'subscript';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  SubscriptNode copyWith({String? text}) => SubscriptNode(text ?? this.text);

  @override
  String toString() => 'SubscriptNode(text: $text)';
}

class SubscriptPlugin extends InlineParserPlugin {
  const SubscriptPlugin();

  @override
  String get id => 'subscript';
  @override
  String get name => 'Subscript Plugin';
  @override
  String get triggerCharacter => '~';
  @override
  int get priority => 14;

  @override
  bool canParse(String text, int index) {
    if (index + 1 >= text.length) return false;
    // Single ~ (not ~~) to avoid conflict with strikethrough
    return text[index] == '~' && text[index + 1] != '~';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex + 1 >= text.length) return null;
    if (text[startIndex] != '~') return null;
    if (text[startIndex + 1] == '~') return null;

    var i = startIndex + 1;
    while (i < text.length) {
      if (text[i] == '~') {
        final content = text.substring(startIndex + 1, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: SubscriptNode(content),
          consumed: i - startIndex + 1,
        );
      }
      i++;
    }
    return null;
  }
}

class SubscriptBuilder extends MarkdownWidgetBuilder {
  const SubscriptBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is SubscriptNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final subNode = node as SubscriptNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Text(
      subNode.text,
      style: baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 14) * 0.72,
        textBaseline: TextBaseline.alphabetic,
      ),
      textScaler: const TextScaler.linear(1),
    );
  }
}

// ── Link Builder (clickable + styled) ─────────────────────────────────────

class ClickableLinkBuilder extends MarkdownWidgetBuilder {
  const ClickableLinkBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is LinkNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final linkNode = node as LinkNode;
    final linkStyle = (styleSheet.linkStyle ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
      color: AppColors.primary,
    );

    final inner = context.inlineRenderer?.call(linkNode.children, linkStyle);
    final innerSpan = _extractSpan(inner) ??
        TextSpan(
          text: linkNode.children
              .whereType<TextNode>()
              .map((n) => n.content)
              .join(),
          style: linkStyle,
        );

    final tapSpan = TextSpan(
      text: innerSpan.text,
      style: innerSpan.style ?? linkStyle,
      children: innerSpan.children,
      recognizer: TapGestureRecognizer()
        ..onTap = () => context.onTapLink?.call(linkNode.url),
    );

    return Text.rich(
      TextSpan(children: [tapSpan]),
      style: linkStyle,
    );
  }

  TextSpan? _extractSpan(Widget? widget) {
    if (widget == null) return null;
    if (widget is Text) {
      return widget.textSpan ?? TextSpan(text: widget.data);
    }
    if (widget is RichText) {
      return widget.text;
    }
    if (widget is SelectableText) {
      return widget.textSpan ?? TextSpan(text: widget.data);
    }
    return null;
  }
}

// ── Mindmap Plugin (```mindmap) ──────────────────────────────────────────

class MindmapNode extends MarkdownNode {
  const MindmapNode(this.code);
  final String code;

  @override
  String get type => 'mindmap';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'code': code};

  @override
  MindmapNode copyWith({String? code}) => MindmapNode(code ?? this.code);

  @override
  String toString() => 'MindmapNode(code: ${code.length > 40 ? code.substring(0, 40) : code})';
}

class MindmapPlugin extends BlockParserPlugin {
  const MindmapPlugin();

  @override
  String get id => 'mindmap';
  @override
  String get name => 'Mindmap Plugin';
  @override
  int get priority => 10;

  @override
  bool canParse(String line, List<String> lines, int index) {
    final trimmed = line.trim();
    return trimmed.startsWith('```mindmap') || trimmed.startsWith('~~~mindmap');
  }

  @override
  BlockParseResult? parse(List<String> lines, int startIndex) {
    final startLine = lines[startIndex].trim();
    final fenceChar = startLine.startsWith('```') ? '```' : '~~~';

    final codeLines = <String>[];
    var consumed = 1;
    for (var i = startIndex + 1; i < lines.length; i++) {
      consumed++;
      if (lines[i].trim().startsWith(fenceChar)) break;
      codeLines.add(lines[i]);
    }
    if (codeLines.isEmpty) return null;

    return BlockParseResult(
      node: MindmapNode(codeLines.join('\n').trim()),
      linesConsumed: consumed,
    );
  }
}

class MindmapBuilder extends MarkdownWidgetBuilder {
  const MindmapBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is MindmapNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final code = (node as MindmapNode).code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: MindmapDiagram(code: code),
    );
  }
}

// ── Mindmap Diagram Widget ───────────────────────────────────────────────

class MindmapDiagram extends StatelessWidget {
  final String code;
  const MindmapDiagram({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final tree = _parseMindmap(code);
    if (tree == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: context.palette.hairline),
        ),
        child: Text('无法解析 mindmap', style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          width: width,
          child: _MindmapTree(tree: tree, availableWidth: width),
        );
      },
    );
  }

  _MindmapNodeData? _parseMindmap(String source) {
    final lines = source.split('\n').map((l) => l.trimRight()).toList();
    if (lines.isEmpty) return null;

    var firstLine = lines.first.trim();
    if (!firstLine.startsWith('mindmap')) return null;

    final children = <_MindmapNodeData>[];
    _parseChildren(lines, 1, 0, children);
    if (children.isEmpty) return null;

    return _MindmapNodeData(
      text: '',
      children: children,
      isRoot: true,
    );
  }

  int _parseChildren(List<String> lines, int start, int parentIndent, List<_MindmapNodeData> out) {
    var i = start;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trimLeft().startsWith('%')) {
        i++;
        continue;
      }

      final indent = line.length - line.trimLeft().length;
      if (indent <= parentIndent && i > start) break;

      final content = line.trim();
      var text = content;

      if (text.startsWith('mindmap')) { i++; continue; }

      var shape = _MindmapShape.none;
      if (text.startsWith('[') && text.endsWith(']')) {
        shape = _MindmapShape.rounded;
        text = text.substring(1, text.length - 1);
      } else if (text.startsWith('((') && text.endsWith('))')) {
        shape = _MindmapShape.circle;
        text = text.substring(2, text.length - 2);
      } else if (text.startsWith('(') && text.endsWith(')')) {
        shape = _MindmapShape.bubble;
        text = text.substring(1, text.length - 1);
      } else if (text.startsWith('[') && text.endsWith(']')) {
        shape = _MindmapShape.rounded;
        text = text.substring(1, text.length - 1);
      }

      final children = <_MindmapNodeData>[];
      i = _parseChildren(lines, i + 1, indent, children);

      out.add(_MindmapNodeData(text: text, children: children, shape: shape));
    }
    return i;
  }
}

enum _MindmapShape { none, rounded, bubble, circle }

class _MindmapNodeData {
  final String text;
  final List<_MindmapNodeData> children;
  final _MindmapShape shape;
  final bool isRoot;

  _MindmapNodeData({
    required this.text,
    this.children = const [],
    this.shape = _MindmapShape.none,
    this.isRoot = false,
  });
}

class _MindmapTree extends StatelessWidget {
  final _MindmapNodeData tree;
  final double availableWidth;

  const _MindmapTree({required this.tree, required this.availableWidth});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (tree.isRoot && tree.children.isEmpty) {
      return const SizedBox.shrink();
    }

    if (tree.isRoot) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: tree.children.map((child) => _buildNode(context, child, isDark, 0)).toList(),
      );
    }

    return _buildNode(context, tree, isDark, 0);
  }

  Widget _buildNode(BuildContext context, _MindmapNodeData node, bool isDark, int depth) {
    final palette = context.palette;
    final hasChildren = node.children.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : AppSpacing.lg + depth * 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.text.isNotEmpty)
            _MindmapNodeWidget(
              text: node.text,
              shape: node.shape,
              isDark: isDark,
              depth: depth,
            ),
          if (hasChildren)
            Padding(
              padding: EdgeInsets.only(
                left: node.text.isNotEmpty ? AppSpacing.sm : 0,
                top: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in node.children)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MindmapConnector(isDark: isDark),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: _buildNode(context, child, isDark, depth + 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MindmapNodeWidget extends StatelessWidget {
  final String text;
  final _MindmapShape shape;
  final bool isDark;
  final int depth;

  const _MindmapNodeWidget({
    required this.text,
    required this.shape,
    required this.isDark,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bgColor = isDark ? palette.card : Color.lerp(palette.canvas, AppColors.primary, depth == 0 ? 0.06 : 0.03)!;
    final borderColor = depth == 0 ? AppColors.primary.withValues(alpha: 0.3) : palette.hairline;

    Widget label = Container(
      padding: EdgeInsets.symmetric(
        horizontal: shape == _MindmapShape.none ? 0 : AppSpacing.sm + 4,
        vertical: shape == _MindmapShape.none ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: shape == _MindmapShape.none
          ? null
          : BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(
                shape == _MindmapShape.circle ? 999 : AppRadii.sm,
              ),
              border: shape != _MindmapShape.bubble
                  ? Border.all(color: borderColor)
                  : null,
            ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w400,
          color: palette.ink,
          height: 1.3,
        ),
      ),
    );

    if (shape == _MindmapShape.circle) {
      label = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: label,
        ),
      );
    }

    return label;
  }
}

class _MindmapConnector extends StatelessWidget {
  final bool isDark;
  const _MindmapConnector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: 12,
        height: 1.5,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── Markdown Pre-processing ─────────────────────────────────────────────

String _preprocessMarkdown(String raw) {
  // 1. Collect reference link definitions [id]: url
  final refLinks = <String, String>{};
  final refRegex = RegExp(r'^\[([^\]]+)\]:\s*(\S+)\s*$', multiLine: true);
  var processed = raw.replaceAllMapped(refRegex, (match) {
    refLinks[match.group(1)!] = match.group(2)!;
    return '';
  });

  // 2. Replace [text][id] references
  processed = processed.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\[([^\]]+)\]'),
    (match) {
      final id = match.group(2)!;
      final url = refLinks[id];
      if (url != null) {
        return '[${match.group(1)}]($url)';
      }
      return match.group(0)!;
    },
  );

  // 3. Autolinks <url> and <email>
  processed = processed.replaceAllMapped(
    RegExp(r'<([^\s<>]+@[^\s<>]+\.[^\s<>]+)>'),
    (match) => '[${match.group(1)}](mailto:${match.group(1)})',
  );
  processed = processed.replaceAllMapped(
    RegExp(r'<(https?://[^\s<>]+)>'),
    (match) => '[${match.group(1)}](${match.group(1)})',
  );

  // 4. Strip trailing ; inside mermaid code blocks
  processed = processed.replaceAllMapped(
    RegExp(r'```mermaid[\s\S]*?```', multiLine: true),
    (match) {
      var block = match.group(0)!;
      return block.replaceAllMapped(
        RegExp(r'^(.*?);$', multiLine: true),
        (m) => m.group(1)!,
      );
    },
  );

  return processed;
}

// ── Markdown Viewer Widget ───────────────────────────────────────────────

class MarkdownViewer extends StatefulWidget {
  final File file;
  final double fontSize;
  final double lineHeight;
  final ScrollController? scrollController;
  final double topPadding;

  const MarkdownViewer({
    required this.file,
    required this.fontSize,
    required this.lineHeight,
    this.scrollController,
    this.topPadding = 0,
    super.key,
  });

  @override
  State<MarkdownViewer> createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> {
  String? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(MarkdownViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight) {
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    try {
      final raw = await widget.file.readAsString();
      if (mounted) {
        setState(() {
          _data = _preprocessMarkdown(raw);
          _error = null;
        });
      }
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

    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final bodyStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: palette.ink,
      fontSize: widget.fontSize,
      height: widget.lineHeight,
    );

    final base = brightness == Brightness.dark
        ? MarkdownStyleSheet.dark()
        : MarkdownStyleSheet.light();

    final styleSheet = base.copyWith(
      textStyle: bodyStyle,
      h1Style: textTheme.headlineLarge?.copyWith(
        fontSize: widget.fontSize + 16,
        color: palette.ink,
      ),
      h2Style: textTheme.headlineLarge?.copyWith(
        fontSize: widget.fontSize + 10,
        color: palette.ink,
      ),
      h3Style: textTheme.titleLarge?.copyWith(
        fontSize: widget.fontSize + 5,
        color: palette.ink,
      ),
      h4Style: textTheme.titleMedium?.copyWith(
        fontSize: widget.fontSize + 2,
        color: palette.ink,
      ),
      h5Style: textTheme.titleMedium?.copyWith(color: palette.ink),
      h6Style: textTheme.titleMedium?.copyWith(color: palette.muted),
      paragraphStyle: bodyStyle,
      blockquoteStyle: bodyStyle.copyWith(color: palette.muted),
      blockquoteDecoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(AppSpacing.md),
      inlineCodeStyle: TextStyle(
        color: palette.ink,
        backgroundColor:
            brightness == Brightness.dark ? palette.card : const Color(0xFFE8E8ED),
        fontFamily: 'monospace',
        fontSize: 15,
        height: 1.45,
      ),
      codeBlockDecoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: palette.hairline),
      ),
      codeBlockPadding: const EdgeInsets.all(AppSpacing.md),
      tableBorder: TableBorder.all(color: palette.hairline),
      tableHeaderStyle: textTheme.titleMedium ?? const TextStyle(),
      tableCellStyle: bodyStyle.copyWith(fontSize: 15),
      horizontalRuleColor: palette.hairline,
      horizontalRuleThickness: 1,
      linkStyle: bodyStyle.copyWith(color: AppColors.primary),
      listBulletStyle: bodyStyle,
    );

    final plugins = ParserPluginRegistry()
      ..registerInline(const UnderlinePlugin())
      ..registerInline(const HighlightPlugin())
      ..registerInline(const SuperscriptPlugin())
      ..registerInline(const SubscriptPlugin())
      ..registerBlock(const MermaidPlugin())
      ..registerBlock(const MindmapPlugin());

    final builders = BuilderRegistry()
      ..register('underline', const UnderlineBuilder())
      ..register('highlight', const HighlightBuilder())
      ..register('superscript', const SuperscriptBuilder())
      ..register('subscript', const SubscriptBuilder())
      ..register('code_block', const EnhancedCodeBlockBuilder(
        showCopyButton: true,
        showLanguageTag: true,
        enableSyntaxHighlighting: true,
      ))
      ..register('mermaid', const MermaidBuilder())
      ..register('mindmap', const MindmapBuilder())
      ..register('link', const ClickableLinkBuilder());

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        widget.topPadding + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl + kBottomNavigationBarHeight,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      child: SmoothMarkdown(
        data: _data!,
        styleSheet: styleSheet,
        useEnhancedComponents: false,
        selectable: true,
        plugins: plugins,
        builderRegistry: builders,
        onTapLink: (url) => _handleLinkTap(context, url),
        onTapImage: (url, alt, title) =>
            _showImagePreview(context, url, alt, title),
      ),
    );
  }

  void _handleLinkTap(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }
}
