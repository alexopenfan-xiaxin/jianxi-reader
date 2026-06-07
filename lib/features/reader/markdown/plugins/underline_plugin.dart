import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

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
