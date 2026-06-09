import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

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
        color: const Color(0xFFFFEB3B).withOpacity(0.35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(highlightNode.text, style: baseStyle),
    );
  }
}

// ── Superscript Plugin (^text^) ─────────────────────────────────────────
