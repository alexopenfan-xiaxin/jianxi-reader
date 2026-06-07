import 'package:flutter/widgets.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

class EmojiBuilder extends MarkdownWidgetBuilder {
  const EmojiBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is EmojiNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final emojiNode = node as EmojiNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Text(emojiNode.emoji, style: baseStyle);
  }
}

// ── Syntax Highlight Code Block Builder (via syntax_highlight) ─────────────
