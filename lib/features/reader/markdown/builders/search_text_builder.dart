import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../../document_search_controller.dart';

class SearchTextBuilder extends MarkdownWidgetBuilder {
  const SearchTextBuilder({required this.searchController});

  final DocumentSearchController? searchController;

  @override
  bool canBuild(MarkdownNode node) => node is TextNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final textNode = node as TextNode;
    final query = searchController?.normalizedQuery ?? '';
    if (query.isEmpty || textNode.content.isEmpty) {
      return Text(textNode.content, style: styleSheet.textStyle);
    }

    final spans = _highlightMatches(textNode.content, query);
    if (spans == null) {
      return Text(textNode.content, style: styleSheet.textStyle);
    }
    return Text.rich(TextSpan(children: spans));
  }

  List<TextSpan>? _highlightMatches(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    var matchStart = lowerText.indexOf(lowerQuery);

    while (matchStart != -1) {
      if (matchStart > start) {
        spans.add(TextSpan(text: text.substring(start, matchStart)));
      }
      final matchEnd = matchStart + query.length;
      spans.add(
        TextSpan(
          text: text.substring(matchStart, matchEnd),
          style: const TextStyle(
            backgroundColor: Color(0x55FFCC33),
            color: Colors.black,
          ),
        ),
      );
      start = matchEnd;
      matchStart = lowerText.indexOf(lowerQuery, start);
    }

    if (start == 0) {
      return null;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }
}
