import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

class PerformanceTableBuilder extends MarkdownWidgetBuilder {
  const PerformanceTableBuilder();

  static const _minColumnWidth = 136.0;

  @override
  bool canBuild(MarkdownNode node) => node is TableNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final tableNode = node as TableNode;
    final columnCount = _columnCount(tableNode);
    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    final rows = <TableRow>[
      _buildRow(
        tableNode.headers,
        tableNode.alignments,
        columnCount,
        styleSheet,
        context,
        isHeader: true,
      ),
      for (final row in tableNode.rows)
        _buildRow(
          row.cells,
          tableNode.alignments,
          columnCount,
          styleSheet,
          context,
          isHeader: false,
        ),
    ];

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (buildContext, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 0.0;
          final tableWidth = columnCount * _minColumnWidth;
          final minWidth = tableWidth > availableWidth
              ? tableWidth
              : availableWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: Table(
                border: styleSheet.tableBorder,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
          );
        },
      ),
    );
  }

  static int _columnCount(TableNode tableNode) {
    var columnCount = tableNode.alignments.length;
    if (tableNode.headers.length > columnCount) {
      columnCount = tableNode.headers.length;
    }
    for (final row in tableNode.rows) {
      if (row.cells.length > columnCount) {
        columnCount = row.cells.length;
      }
    }
    return columnCount;
  }

  TableRow _buildRow(
    List<List<MarkdownNode>> cells,
    List<TableAlignment?> alignments,
    int columnCount,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context, {
    required bool isHeader,
  }) {
    return TableRow(
      decoration: isHeader ? styleSheet.tableHeaderDecoration : null,
      children: [
        for (var index = 0; index < columnCount; index++)
          _buildCell(
            index < cells.length ? cells[index] : const <MarkdownNode>[],
            index < alignments.length ? alignments[index] : null,
            styleSheet,
            context,
            isHeader: isHeader,
          ),
      ],
    );
  }

  Widget _buildCell(
    List<MarkdownNode> content,
    TableAlignment? alignment,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context, {
    required bool isHeader,
  }) {
    final textStyle = isHeader
        ? styleSheet.tableHeaderStyle ?? styleSheet.textStyle
        : styleSheet.tableCellStyle ?? styleSheet.textStyle;
    final inlineRenderer = context.inlineRenderer;
    final child = inlineRenderer != null
        ? inlineRenderer(content, textStyle)
        : Text(
            content.whereType<TextNode>().map((node) => node.content).join(),
            style: textStyle,
          );

    return Container(
      constraints: const BoxConstraints(minWidth: _minColumnWidth),
      padding:
          styleSheet.tableCellPadding ??
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: _alignmentFor(alignment),
      color: isHeader ? styleSheet.tableHeaderDecoration?.color : null,
      child: DefaultTextStyle.merge(style: textStyle, child: child),
    );
  }

  static Alignment _alignmentFor(TableAlignment? alignment) {
    return switch (alignment) {
      TableAlignment.center => Alignment.center,
      TableAlignment.right => Alignment.centerRight,
      TableAlignment.left || null => Alignment.centerLeft,
    };
  }
}
