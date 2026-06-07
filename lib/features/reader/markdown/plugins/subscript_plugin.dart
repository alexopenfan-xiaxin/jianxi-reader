import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

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
