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
    final linkStyle =
        (styleSheet.linkStyle ?? styleSheet.textStyle ?? const TextStyle())
            .copyWith(decoration: TextDecoration.underline);
    final inlineRenderer = context.inlineRenderer;
    final child = inlineRenderer != null
        ? inlineRenderer(linkNode.children, linkStyle)
        : Text(linkNode.url, style: linkStyle);

    return Semantics(
      link: true,
      label: linkNode.title ?? linkNode.url,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.onTapLink?.call(linkNode.url),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

// ── Image Builder (tappable + preview + SVG support) ──────────────────────
