import 'dart:convert';

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

  static List<TocEntry> fromHtmlJson(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    Object? decoded;
    try {
      decoded = jsonDecode(_unwrapJsString(raw));
    } catch (_) {
      return const [];
    }
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
