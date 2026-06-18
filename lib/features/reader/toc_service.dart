import 'dart:convert';

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

class TocEntry {
  const TocEntry({
    required this.index,
    required this.level,
    required this.title,
    this.htmlId,
  });

  final int index;
  final int level;
  final String title;
  final String? htmlId;
}

class TocService {
  const TocService._();

  static List<TocEntry> fromMarkdown(
    String data, {
    ParserPluginRegistry? plugins,
  }) {
    final nodes = MarkdownParser(plugins: plugins).parse(data);
    final entries = <TocEntry>[];
    for (final node in nodes) {
      if (node is! HeaderNode || node.level > 4) {
        continue;
      }
      final title = node.content.trim();
      if (title.isEmpty) {
        continue;
      }
      entries.add(
        TocEntry(index: entries.length, level: node.level, title: title),
      );
    }
    return entries;
  }

  static List<TocEntry> fromHtmlJson(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(_unwrapJsString(raw));
    if (decoded is! List) {
      return const [];
    }
    final entries = <TocEntry>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final title = item['title']?.toString().trim() ?? '';
      final id = item['id']?.toString() ?? '';
      final level = int.tryParse(item['level']?.toString() ?? '') ?? 1;
      if (title.isEmpty || id.isEmpty || level > 4) {
        continue;
      }
      entries.add(
        TocEntry(
          index: entries.length,
          level: level.clamp(1, 4).toInt(),
          title: title,
          htmlId: id,
        ),
      );
    }
    return entries;
  }

  static String _unwrapJsString(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return jsonDecode(trimmed) as String;
    }
    return trimmed;
  }
}
