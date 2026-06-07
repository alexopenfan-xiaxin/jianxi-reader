import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../../../../core/design_tokens.dart';

class IndentedOrderedListNode extends MarkdownNode {
  const IndentedOrderedListNode({required this.items});

  final List<IndentedOrderedListItem> items;

  @override
  String get type => 'indented_ordered_list';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'items': items.map((item) => item.toJson()).toList(),
      };

  @override
  IndentedOrderedListNode copyWith({List<IndentedOrderedListItem>? items}) {
    return IndentedOrderedListNode(items: items ?? this.items);
  }
}
class IndentedOrderedListItem {
  const IndentedOrderedListItem({
    required this.number,
    required this.text,
    this.children = const [],
  });

  final int number;
  final String text;
  final List<IndentedOrderedListItem> children;

  Map<String, dynamic> toJson() => {
        'number': number,
        'text': text,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

class IndentedOrderedListPlugin extends BlockParserPlugin {
  const IndentedOrderedListPlugin();

  static final _orderedLine = RegExp(r'^( *)(\d+)[.)]\s+(.+)$');

  @override
  String get id => 'indented_ordered_list';

  @override
  String get name => 'Indented Ordered List Plugin';

  @override
  int get priority => 10;

  @override
  bool canParse(String line, List<String> lines, int index) {
    final first = _orderedLine.firstMatch(line);
    if (first == null || first.group(1)!.isNotEmpty) {
      return false;
    }
    for (var i = index + 1; i < lines.length; i++) {
      final match = _orderedLine.firstMatch(lines[i]);
      if (match == null) {
        return false;
      }
      if (match.group(1)!.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  BlockParseResult? parse(List<String> lines, int startIndex) {
    final rootItems = <_MutableOrderedListItem>[];
    final stack = <_OrderedListStackEntry>[];
    var consumed = 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        consumed++;
        continue;
      }
      final match = _orderedLine.firstMatch(line);
      if (match == null) {
        break;
      }

      final indent = match.group(1)!.length;
      final number = int.tryParse(match.group(2)!) ?? 1;
      final text = match.group(3)!.trim();
      final item = _MutableOrderedListItem(number: number, text: text);

      while (stack.isNotEmpty && indent <= stack.last.indent) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        if (indent > 0) {
          break;
        }
        rootItems.add(item);
      } else {
        stack.last.item.children.add(item);
      }
      stack.add(_OrderedListStackEntry(indent: indent, item: item));
      consumed++;
    }

    if (rootItems.isEmpty || consumed == 0) {
      return null;
    }
    return BlockParseResult(
      node: IndentedOrderedListNode(
        items: rootItems.map((item) => item.freeze()).toList(),
      ),
      linesConsumed: consumed,
    );
  }
}

class _MutableOrderedListItem {
  _MutableOrderedListItem({required this.number, required this.text});

  final int number;
  final String text;
  final List<_MutableOrderedListItem> children = [];

  IndentedOrderedListItem freeze() {
    return IndentedOrderedListItem(
      number: number,
      text: text,
      children: children.map((child) => child.freeze()).toList(),
    );
  }
}

class _OrderedListStackEntry {
  const _OrderedListStackEntry({required this.indent, required this.item});

  final int indent;
  final _MutableOrderedListItem item;
}

class IndentedOrderedListBuilder extends MarkdownWidgetBuilder {
  const IndentedOrderedListBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is IndentedOrderedListNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final listNode = node as IndentedOrderedListNode;
    final textStyle = styleSheet.paragraphStyle ??
        styleSheet.textStyle ??
        const TextStyle(fontSize: 16);
    final markerStyle = styleSheet.listBulletStyle ?? textStyle;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in listNode.items)
            _IndentedOrderedListItemWidget(
              item: item,
              depth: 0,
              textStyle: textStyle,
              markerStyle: markerStyle,
            ),
        ],
      ),
    );
  }
}

class _IndentedOrderedListItemWidget extends StatelessWidget {
  const _IndentedOrderedListItemWidget({
    required this.item,
    required this.depth,
    required this.textStyle,
    required this.markerStyle,
  });

  final IndentedOrderedListItem item;
  final int depth;
  final TextStyle textStyle;
  final TextStyle markerStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: depth == 0 ? 0 : 22,
        top: depth == 0 ? 4 : 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Text('${item.number}.', style: markerStyle),
              ),
              Expanded(child: Text(item.text, style: textStyle)),
            ],
          ),
          if (item.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in item.children)
                    _IndentedOrderedListItemWidget(
                      item: child,
                      depth: depth + 1,
                      textStyle: textStyle,
                      markerStyle: markerStyle,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
