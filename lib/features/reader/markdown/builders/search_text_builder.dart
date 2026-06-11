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

    final spans = _highlightMatches(textNode.content, query, styleSheet);
    if (spans == null) {
      return Text(textNode.content, style: styleSheet.textStyle);
    }
    return Text.rich(TextSpan(style: styleSheet.textStyle, children: spans));
  }

  List<InlineSpan>? _highlightMatches(
    String text,
    String query,
    MarkdownStyleSheet styleSheet,
  ) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <InlineSpan>[];
    final controller = searchController;
    var start = 0;
    var matchStart = lowerText.indexOf(lowerQuery);

    while (matchStart != -1) {
      if (matchStart > start) {
        spans.add(TextSpan(text: text.substring(start, matchStart)));
      }
      final matchEnd = matchStart + query.length;
      final matchText = text.substring(matchStart, matchEnd);
      final matchIndex = controller?.claimBuildMatchIndex() ?? -1;
      if (controller != null &&
          matchIndex == controller.currentIndex &&
          controller.pulseToken > 0) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _PulseSearchMatch(
              key: ValueKey('search-pulse-${controller.pulseToken}-$matchIndex'),
              text: matchText,
              style: styleSheet.textStyle,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(
              backgroundColor: Color(0x55FFCC33),
              color: Colors.black,
            ),
          ),
        );
      }
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

class _PulseSearchMatch extends StatelessWidget {
  const _PulseSearchMatch({
    required this.text,
    required this.style,
    super.key,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFFFCC33),
              const Color(0x55FFCC33),
              1 - value,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: child,
        );
      },
      child: Text(
        text,
        style: style?.copyWith(color: Colors.black) ??
            const TextStyle(color: Colors.black),
      ),
    );
  }
}
