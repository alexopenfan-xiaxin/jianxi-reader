import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'builders/mindmap_builder.dart';
import 'markdown_document.dart';

/// Estimates the rendered height of a markdown section from its node tree.
///
/// Unbuilt sections occupy placeholder space sized by these estimates, which
/// keeps the scroll extent (and therefore the progress bar, scrollbar and
/// ratio-based progress restore) meaningful before content is built. Estimates
/// are replaced by measured heights as sections render, and anchored scroll
/// corrections absorb the difference, so accuracy only affects how much a
/// far jump needs to correct after landing.
class SectionHeightEstimator {
  SectionHeightEstimator({
    required this.styleSheet,
    required double contentWidth,
  }) : contentWidth = contentWidth <= 0 ? 360 : contentWidth;

  final MarkdownStyleSheet styleSheet;
  final double contentWidth;

  static final Map<String, double> _charWidthCache = {};

  static const String _calibrationText = '简兮阅读器中文文本宽度标定示例';

  double estimateSection(MarkdownSection section) {
    var total = 0.0;
    var blocks = 0;
    for (final node in section.nodes) {
      final height = _estimateNode(node);
      if (height <= 0) {
        continue;
      }
      total += height;
      blocks++;
    }
    if (blocks == 0) {
      return 24;
    }
    return total + (blocks - 1) * (styleSheet.blockSpacing ?? 16.0);
  }

  double _estimateNode(MarkdownNode node) {
    switch (node) {
      case HeaderNode():
        return _estimateHeading(node);
      case ParagraphNode():
        return _estimateText(
          flattenMarkdownNodeText(node),
          styleSheet.paragraphStyle ?? styleSheet.textStyle,
        );
      case CodeBlockNode():
        return _estimateCodeBlock(node);
      case ListNode():
        return _estimateList(node);
      case BlockquoteNode():
        var inner = 0.0;
        for (final child in node.children) {
          inner += _estimateNode(child);
        }
        return inner > 0 ? inner + 24 : 24;
      case TableNode():
        return (node.rows.length + 1) * 46.0;
      case HorizontalRuleNode():
        return 24;
      case MermaidDiagramNode():
      case MindmapNode():
        return 400;
      case BlockMathNode():
        return 80;
      case DetailsNode():
        var inner = 0.0;
        for (final child in node.children) {
          inner += _estimateNode(child);
        }
        return inner > 0 ? inner + 40 : 40;
      default:
        final text = flattenMarkdownNodeText(node);
        if (text.trim().isEmpty) {
          return 0;
        }
        return _estimateText(text, styleSheet.textStyle);
    }
  }

  double _estimateHeading(HeaderNode node) {
    final style = switch (node.level) {
      1 => styleSheet.h1Style,
      2 => styleSheet.h2Style,
      3 => styleSheet.h3Style,
      4 => styleSheet.h4Style,
      5 => styleSheet.h5Style,
      _ => styleSheet.h6Style,
    };
    final fontSize = style?.fontSize ?? 18;
    final textHeight = _estimateText(
      flattenMarkdownNodeText(node),
      style ?? styleSheet.textStyle,
    );
    // Headings carry visual breathing room above them.
    return textHeight + fontSize * 0.6;
  }

  double _estimateCodeBlock(CodeBlockNode node) {
    final lineCount = '\n'.allMatches(node.code).length + 1;
    const codeLineHeight = 22.0;
    // codeBlockPadding (16 all sides) + language tag / copy toolbar row.
    return lineCount * codeLineHeight + 34 + 36;
  }

  double _estimateList(ListNode node) {
    final style = styleSheet.textStyle;
    var total = 0.0;
    for (final item in node.items) {
      total += _estimateText(flattenMarkdownNodeText(item), style) + 6;
    }
    return total > 0 ? total : 24;
  }

  double _estimateText(String text, TextStyle? style) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final fontSize = style?.fontSize ?? 16;
    final lineHeight = (style?.height ?? 1.5) * fontSize;
    final charWidth = _averageCharWidth(style);
    final charsPerLine = (contentWidth / charWidth).clamp(8.0, double.infinity);
    final lines = (trimmed.length / charsPerLine).ceil();
    return lines * lineHeight;
  }

  /// Measures the average character width for [style] with a CJK-weighted
  /// sample; CJK glyphs are the widest common case, so the estimate errs on
  /// the tall side and anchored corrections tighten it after real layout.
  double _averageCharWidth(TextStyle? style) {
    final effective = style ?? const TextStyle(fontSize: 16, height: 1.5);
    final key =
        '${effective.fontSize}_${effective.fontFamily}_'
        '${effective.fontWeight}_${effective.letterSpacing}';
    return _charWidthCache.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: _calibrationText, style: effective),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return painter.width / _calibrationText.length;
    });
  }
}
