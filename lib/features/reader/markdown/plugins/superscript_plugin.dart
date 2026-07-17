import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

class SuperscriptNode extends MarkdownNode {
  const SuperscriptNode(this.text);
  final String text;

  @override
  String get type => 'superscript';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  SuperscriptNode copyWith({String? text}) =>
      SuperscriptNode(text ?? this.text);

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
