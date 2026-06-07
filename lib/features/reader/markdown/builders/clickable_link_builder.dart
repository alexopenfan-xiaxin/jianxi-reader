import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

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

    final text = linkNode.children
        .whereType<TextNode>()
        .map((n) => n.content)
        .join();

    return Semantics(
      link: true,
      label: linkNode.title ?? linkNode.url,
      child: GestureDetector(
        onTap: () => context.onTapLink?.call(linkNode.url),
        behavior: HitTestBehavior.opaque,
        child: Text(text, style: linkStyle),
      ),
    );
  }
}

// ── Image Builder (tappable + preview + SVG support) ──────────────────────
