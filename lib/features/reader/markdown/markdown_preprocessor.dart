String preprocessMarkdown(String raw) {
  // 1. Collect reference link definitions [id]: url
  final refLinks = <String, String>{};
  final refRegex = RegExp(r'^\[([^\]]+)\]:\s*(\S+)\s*$', multiLine: true);
  var processed = raw.replaceAllMapped(refRegex, (match) {
    refLinks[match.group(1)!] = match.group(2)!;
    return '';
  });

  // 2. Replace [text][id] references
  processed = processed.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\[([^\]]+)\]'),
    (match) {
      final id = match.group(2)!;
      final url = refLinks[id];
      if (url != null) {
        return '[${match.group(1)}]($url)';
      }
      return match.group(0)!;
    },
  );

  // 3. Autolinks <url> and <email>
  processed = processed.replaceAllMapped(
    RegExp(r'<([^\s<>]+@[^\s<>]+\.[^\s<>]+)>'),
    (match) => '[${match.group(1)}](mailto:${match.group(1)})',
  );
  processed = processed.replaceAllMapped(
    RegExp(r'<(https?://[^\s<>]+)>'),
    (match) => '[${match.group(1)}](${match.group(1)})',
  );

  // 4. Strip trailing ; inside mermaid code blocks
  processed = processed.replaceAllMapped(
    RegExp(r'```mermaid[\s\S]*?```', multiLine: true),
    (match) {
      var block = match.group(0)!;
      return block.replaceAllMapped(
        RegExp(r'^(.*?);$', multiLine: true),
        (m) => m.group(1)!,
      );
    },
  );

  // 5. Convert <u>text</u> to ++text++ for underline rendering
  processed = processed.replaceAllMapped(
    RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true),
    (match) => '++${match.group(1)}++',
  );

  // 6. Keep indented ordered lists nested for parsers that flatten 2-3 spaces.
  return _normalizeNestedOrderedLists(processed);
}

String _normalizeNestedOrderedLists(String markdown) {
  final lines = markdown.split('\n');
  var inFence = false;
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
    }
    if (inFence) {
      continue;
    }
    lines[i] = lines[i].replaceFirstMapped(
      RegExp(r'^( {2,3})(\d+[.)]\s+)'),
      (match) => '    ${match.group(2)!}',
    );
  }
  return lines.join('\n');
}
