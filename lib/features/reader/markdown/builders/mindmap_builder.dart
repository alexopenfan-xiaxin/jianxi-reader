import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../../../../core/design_tokens.dart';

class MindmapNode extends MarkdownNode {
  const MindmapNode(this.code);
  final String code;

  @override
  String get type => 'mindmap';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'code': code};

  @override
  MindmapNode copyWith({String? code}) => MindmapNode(code ?? this.code);

  @override
  String toString() => 'MindmapNode(code: ${code.length > 40 ? code.substring(0, 40) : code})';
}

class MindmapPlugin extends BlockParserPlugin {
  const MindmapPlugin();

  @override
  String get id => 'mindmap';
  @override
  String get name => 'Mindmap Plugin';
  @override
  int get priority => 10;

  @override
  bool canParse(String line, List<String> lines, int index) {
    final trimmed = line.trim();
    return trimmed.startsWith('```mindmap') || trimmed.startsWith('~~~mindmap');
  }

  @override
  BlockParseResult? parse(List<String> lines, int startIndex) {
    final startLine = lines[startIndex].trim();
    final fenceChar = startLine.startsWith('```') ? '```' : '~~~';

    final codeLines = <String>[];
    var consumed = 1;
    for (var i = startIndex + 1; i < lines.length; i++) {
      consumed++;
      if (lines[i].trim().startsWith(fenceChar)) break;
      codeLines.add(lines[i]);
    }
    if (codeLines.isEmpty) return null;

    return BlockParseResult(
      node: MindmapNode(codeLines.join('\n').trim()),
      linesConsumed: consumed,
    );
  }
}

class MindmapBuilder extends MarkdownWidgetBuilder {
  const MindmapBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is MindmapNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final code = (node as MindmapNode).code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: MindmapDiagram(code: code),
    );
  }
}

// ── Mindmap Diagram Widget ───────────────────────────────────────────────

class MindmapDiagram extends StatelessWidget {
  final String code;
  const MindmapDiagram({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final tree = _parseMindmap(code);
    if (tree == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: context.palette.hairline),
        ),
        child: Text('无法解析 mindmap', style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          width: width,
          child: _MindmapTree(tree: tree, availableWidth: width),
        );
      },
    );
  }

  _MindmapNodeData? _parseMindmap(String source) {
    final lines = source.split('\n').map((l) => l.trimRight()).toList();
    if (lines.isEmpty) return null;

    var firstLine = lines.first.trim();
    if (!firstLine.startsWith('mindmap')) return null;

    final children = <_MindmapNodeData>[];
    _parseChildren(lines, 1, 0, children);
    if (children.isEmpty) return null;

    return _MindmapNodeData(
      text: '',
      children: children,
      isRoot: true,
    );
  }

  int _parseChildren(List<String> lines, int start, int parentIndent, List<_MindmapNodeData> out) {
    var i = start;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trimLeft().startsWith('%')) {
        i++;
        continue;
      }

      final indent = line.length - line.trimLeft().length;
      if (indent <= parentIndent && i > start) break;

      final content = line.trim();
      var text = content;

      if (text.startsWith('mindmap')) { i++; continue; }

      var shape = _MindmapShape.none;
      if (text.startsWith('[') && text.endsWith(']')) {
        shape = _MindmapShape.rounded;
        text = text.substring(1, text.length - 1);
      } else if (text.startsWith('((') && text.endsWith('))')) {
        shape = _MindmapShape.circle;
        text = text.substring(2, text.length - 2);
      } else if (text.startsWith('(') && text.endsWith(')')) {
        shape = _MindmapShape.bubble;
        text = text.substring(1, text.length - 1);
      } else if (text.startsWith('[') && text.endsWith(']')) {
        shape = _MindmapShape.rounded;
        text = text.substring(1, text.length - 1);
      }

      final children = <_MindmapNodeData>[];
      i = _parseChildren(lines, i + 1, indent, children);

      out.add(_MindmapNodeData(text: text, children: children, shape: shape));
    }
    return i;
  }
}

enum _MindmapShape { none, rounded, bubble, circle }

class _MindmapNodeData {
  final String text;
  final List<_MindmapNodeData> children;
  final _MindmapShape shape;
  final bool isRoot;

  _MindmapNodeData({
    required this.text,
    this.children = const [],
    this.shape = _MindmapShape.none,
    this.isRoot = false,
  });
}

class _MindmapTree extends StatelessWidget {
  final _MindmapNodeData tree;
  final double availableWidth;

  const _MindmapTree({required this.tree, required this.availableWidth});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (tree.isRoot && tree.children.isEmpty) {
      return const SizedBox.shrink();
    }

    if (tree.isRoot) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: tree.children.map((child) => _buildNode(context, child, isDark, 0)).toList(),
      );
    }

    return _buildNode(context, tree, isDark, 0);
  }

  Widget _buildNode(BuildContext context, _MindmapNodeData node, bool isDark, int depth) {
    final hasChildren = node.children.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : AppSpacing.lg + depth * 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.text.isNotEmpty)
            _MindmapNodeWidget(
              text: node.text,
              shape: node.shape,
              isDark: isDark,
              depth: depth,
            ),
          if (hasChildren)
            Padding(
              padding: EdgeInsets.only(
                left: node.text.isNotEmpty ? AppSpacing.sm : 0,
                top: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in node.children)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MindmapConnector(isDark: isDark),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: _buildNode(context, child, isDark, depth + 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MindmapNodeWidget extends StatelessWidget {
  final String text;
  final _MindmapShape shape;
  final bool isDark;
  final int depth;

  const _MindmapNodeWidget({
    required this.text,
    required this.shape,
    required this.isDark,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bgColor = isDark
        ? palette.card
        : Color.lerp(
            palette.canvas,
            AppColors.primary,
            depth == 0 ? 0.06 : 0.03,
          )!;
    final borderColor = depth == 0
        ? AppColors.primary.withValues(alpha: 0.3)
        : palette.hairline;

    Widget label = Container(
      padding: EdgeInsets.symmetric(
        horizontal: shape == _MindmapShape.none ? 0 : AppSpacing.sm + 4,
        vertical: shape == _MindmapShape.none ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: shape == _MindmapShape.none
          ? null
          : BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(
                shape == _MindmapShape.circle ? 999 : AppRadii.sm,
              ),
              border: shape != _MindmapShape.bubble
                  ? Border.all(color: borderColor)
                  : null,
            ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w400,
          color: palette.ink,
          height: 1.3,
        ),
      ),
    );

    if (shape == _MindmapShape.circle) {
      label = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: label,
        ),
      );
    }

    return label;
  }
}

class _MindmapConnector extends StatelessWidget {
  final bool isDark;
  const _MindmapConnector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: 12,
        height: 1.5,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── Markdown Pre-processing ─────────────────────────────────────────────
