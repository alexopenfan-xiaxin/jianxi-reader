import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../../../core/file_rules.dart';
import 'builders/mindmap_builder.dart';
import 'markdown_preprocessor.dart';
import 'plugins/bare_url_plugin.dart';
import 'plugins/highlight_plugin.dart';
import 'plugins/indented_ordered_list_plugin.dart';
import 'plugins/subscript_plugin.dart';
import 'plugins/superscript_plugin.dart';
import 'plugins/underline_plugin.dart';

/// Builds the parser plugin registry used by the reader.
///
/// Kept as a shared top-level function so the background isolate and tests
/// construct exactly the same parser configuration.
ParserPluginRegistry buildReaderPluginRegistry(Map<String, String> emojiMap) {
  return ParserPluginRegistry()
    ..registerInline(const UnderlinePlugin())
    ..registerInline(const HighlightPlugin())
    ..registerInline(const SuperscriptPlugin())
    ..registerInline(const SubscriptPlugin())
    ..registerInline(const BareUrlPlugin())
    ..registerInline(
      EmojiPlugin(customEmojis: emojiMap.isNotEmpty ? emojiMap : null),
    )
    ..registerBlock(const IndentedOrderedListPlugin())
    ..registerBlock(const MermaidPlugin())
    ..registerBlock(const MindmapPlugin());
}

/// A lazily-rendered slice of a markdown document.
///
/// The viewer renders sections near the viewport and replaces the remaining
/// ones with height placeholders, so every expensive artifact (TOC entries,
/// search text, jump anchors) is precomputed once per section here.
class MarkdownSection {
  const MarkdownSection({
    required this.nodes,
    required this.searchTextStart,
    required this.searchTextLength,
    required this.headingBase,
    required this.headingCharOffsets,
  });

  final List<MarkdownNode> nodes;

  /// Character offset of this section's text within [MarkdownDocument.searchText].
  final int searchTextStart;

  /// Length of this section's plain-text projection. Only the full document
  /// search text is retained; per-section copies would double memory.
  final int searchTextLength;

  /// Global TOC index of the first TOC-eligible heading in this section.
  final int headingBase;

  /// Character offsets (within this section's search text) of each
  /// TOC-eligible heading, in document order.
  final List<int> headingCharOffsets;
}

/// A fully parsed markdown document, produced once in a background isolate.
///
/// Parsing, section splitting, TOC extraction and search-text building all
/// happen in a single pass off the UI thread; the viewer never re-parses.
class MarkdownDocument {
  const MarkdownDocument({
    required this.sections,
    required this.tocEntries,
    required this.searchText,
    required this.modified,
    required this.size,
  });

  final List<MarkdownSection> sections;
  final List<TocEntry> tocEntries;
  final String searchText;
  final DateTime modified;
  final int size;

  /// Reads, preprocesses and parses [path] in a background isolate.
  static Future<MarkdownDocument> load(
    String path,
    Map<String, String> emojiMap,
  ) {
    return compute(
      _parseMarkdownDocument,
      _MarkdownParseRequest(path: path, emojiMap: emojiMap),
    );
  }

  /// Parses in-memory content synchronously. Test and offline helper.
  static MarkdownDocument parseContent(
    String data,
    Map<String, String> emojiMap, {
    DateTime? modified,
    int size = 0,
  }) {
    final nodes = MarkdownParser(
      plugins: buildReaderPluginRegistry(emojiMap),
    ).parse(data);
    return buildMarkdownDocumentFromNodes(
      nodes,
      modified ?? DateTime.fromMillisecondsSinceEpoch(0),
      size,
    );
  }

  /// Returns the index of the section containing the heading whose global
  /// TOC index is [globalHeadingIndex], or -1 when not found.
  int sectionIndexForHeading(int globalHeadingIndex) {
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (globalHeadingIndex >= section.headingBase &&
          globalHeadingIndex <
              section.headingBase + section.headingCharOffsets.length) {
        return i;
      }
    }
    return -1;
  }
}

class _MarkdownParseRequest {
  const _MarkdownParseRequest({required this.path, required this.emojiMap});

  final String path;
  final Map<String, String> emojiMap;
}

Future<MarkdownDocument> _parseMarkdownDocument(
  _MarkdownParseRequest request,
) async {
  final file = File(request.path);
  final initialSize = await file.length();
  if (initialSize > DocumentFileRules.maxReadableBytes) {
    throw FileSystemException('文档过大', request.path);
  }
  final raw = await file.readAsString();
  final stat = await file.stat();
  final data = preprocessMarkdown(raw);
  final nodes = MarkdownParser(
    plugins: buildReaderPluginRegistry(request.emojiMap),
  ).parse(data);
  return buildMarkdownDocumentFromNodes(nodes, stat.modified, stat.size);
}

/// Section targets: chapter boundaries (h1/h2) close a section once it holds
/// enough content, and any section is force-split before it grows so large
/// that building it in one frame would jank the viewport.
const int _minSectionChars = 800;
const int _maxSectionChars = 6000;
const int _maxSectionNodes = 60;

/// Splits parsed nodes into [MarkdownSection]s, extracts the global TOC and
/// builds the plain-text search projection in one pass.
MarkdownDocument buildMarkdownDocumentFromNodes(
  List<MarkdownNode> nodes,
  DateTime modified,
  int size,
) {
  final tocEntries = <TocEntry>[];
  final sections = <MarkdownSection>[];
  final fullText = StringBuffer();

  var sectionNodes = <MarkdownNode>[];
  var sectionBuffer = StringBuffer();
  var headingBase = 0;
  var headingOffsets = <int>[];

  void flushSection() {
    if (sectionNodes.isEmpty) {
      return;
    }
    final text = sectionBuffer.toString();
    sections.add(
      MarkdownSection(
        nodes: sectionNodes,
        searchTextStart: fullText.length,
        searchTextLength: text.length,
        headingBase: headingBase,
        headingCharOffsets: headingOffsets,
      ),
    );
    fullText.write(text);
    sectionNodes = <MarkdownNode>[];
    sectionBuffer = StringBuffer();
    headingOffsets = <int>[];
  }

  for (final node in nodes) {
    final isChapterBoundary = node is HeaderNode && node.level <= 2;
    final shouldFlush =
        sectionNodes.isNotEmpty &&
        ((isChapterBoundary && sectionBuffer.length >= _minSectionChars) ||
            sectionBuffer.length >= _maxSectionChars ||
            sectionNodes.length >= _maxSectionNodes);
    if (shouldFlush) {
      flushSection();
      headingBase = tocEntries.length;
    }

    if (node is HeaderNode &&
        node.level <= 4 &&
        node.content.trim().isNotEmpty) {
      headingOffsets.add(sectionBuffer.length);
      tocEntries.add(
        TocEntry(
          index: tocEntries.length,
          level: node.level,
          title: node.content.trim(),
        ),
      );
    }

    _appendNodeText(sectionBuffer, node);
    sectionBuffer.write('\n');
    sectionNodes.add(node);
  }
  flushSection();

  return MarkdownDocument(
    sections: sections,
    tocEntries: tocEntries,
    searchText: fullText.toString(),
    modified: modified,
    size: size,
  );
}

/// Flattens a node subtree to plain text (used for height estimation).
String flattenMarkdownNodeText(MarkdownNode node) {
  final buffer = StringBuffer();
  _appendNodeText(buffer, node);
  return buffer.toString();
}

void _appendNodeText(StringBuffer buffer, MarkdownNode node) {
  switch (node) {
    case TextNode():
      buffer.write(node.content);
    case HeaderNode():
      _appendChildrenOrFallback(buffer, node.children, node.content);
      buffer.write('\n');
    case ParagraphNode():
      _appendNodes(buffer, node.children);
      buffer.write('\n');
    case CodeBlockNode():
      buffer.write(node.code);
      buffer.write('\n');
    case InlineCodeNode():
      buffer.write(node.code);
    case ListNode():
      for (final item in node.items) {
        _appendNodeText(buffer, item);
        buffer.write('\n');
      }
    case ListItemNode():
      _appendNodes(buffer, node.children);
    case BlockquoteNode():
      _appendNodes(buffer, node.children);
    case BoldNode():
      _appendNodes(buffer, node.children);
    case ItalicNode():
      _appendNodes(buffer, node.children);
    case StrikethroughNode():
      _appendNodes(buffer, node.children);
    case LinkNode():
      _appendNodes(buffer, node.children);
    case ImageNode():
      buffer.write(node.alt);
      if (node.title != null) {
        buffer.write(' ${node.title}');
      }
    case UnderlineNode():
      buffer.write(node.text);
    case HighlightNode():
      buffer.write(node.text);
    case SuperscriptNode():
      buffer.write(node.text);
    case SubscriptNode():
      buffer.write(node.text);
    case IndentedOrderedListNode():
      for (final item in node.items) {
        _appendIndentedItemText(buffer, item);
        buffer.write('\n');
      }
    case MermaidDiagramNode():
      buffer.write(node.code);
    case MindmapNode():
      buffer.write(node.code);
    default:
      break;
  }
}

void _appendChildrenOrFallback(
  StringBuffer buffer,
  List<MarkdownNode>? children,
  String fallback,
) {
  if (children == null || children.isEmpty) {
    buffer.write(fallback);
    return;
  }
  _appendNodes(buffer, children);
}

void _appendNodes(StringBuffer buffer, List<MarkdownNode> nodes) {
  for (final child in nodes) {
    _appendNodeText(buffer, child);
  }
}

void _appendIndentedItemText(
  StringBuffer buffer,
  IndentedOrderedListItem item,
) {
  buffer.write(item.text);
  for (final child in item.children) {
    buffer.write('\n');
    _appendIndentedItemText(buffer, child);
  }
}
