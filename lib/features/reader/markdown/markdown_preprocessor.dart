final _referenceDefinition = RegExp(
  r'^\[([^\]]+)\]:\s*(\S+)\s*$',
  multiLine: true,
);
final _referenceLink = RegExp(r'\[([^\]]+)\]\[([^\]]+)\]');
final _angleEmail = RegExp(r'<([^\s<>]+@[^\s<>]+\.[^\s<>]+)>');
final _angleUrl = RegExp(r'<(https?://[^\s<>]+)>');
final _mermaidFence = RegExp(r'```mermaid[\s\S]*?```', multiLine: true);
final _mermaidTrailingSemicolon = RegExp(r'^(.*?);$', multiLine: true);
final _htmlUnderline = RegExp(
  r'<u>(.*?)</u>',
  caseSensitive: false,
  dotAll: true,
);
final _orderedIndent = RegExp(r'^( {2,3})(\d+[.)]\s+)');

String preprocessMarkdown(String raw) {
  raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // 1. Collect reference link definitions [id]: url
  final refLinks = <String, String>{};
  final refRegex = _referenceDefinition;
  var processed = raw.replaceAllMapped(refRegex, (match) {
    refLinks[match.group(1)!] = match.group(2)!;
    return '';
  });

  // 2. Replace [text][id] references
  processed = processed.replaceAllMapped(_referenceLink, (match) {
    final id = match.group(2)!;
    final url = refLinks[id];
    if (url != null) {
      return '[${match.group(1)}]($url)';
    }
    return match.group(0)!;
  });

  // 3. Autolinks <url> and <email>
  processed = processed.replaceAllMapped(
    _angleEmail,
    (match) => '[${match.group(1)}](mailto:${match.group(1)})',
  );
  processed = processed.replaceAllMapped(
    _angleUrl,
    (match) => '[${match.group(1)}](${match.group(1)})',
  );

  // 4. Strip trailing ; inside mermaid code blocks
  processed = processed.replaceAllMapped(_mermaidFence, (match) {
    var block = match.group(0)!;
    return block.replaceAllMapped(
      _mermaidTrailingSemicolon,
      (m) => m.group(1)!,
    );
  });

  // 5. Convert <u>text</u> to ++text++ for underline rendering
  processed = processed.replaceAllMapped(
    _htmlUnderline,
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
      _orderedIndent,
      (match) => '    ${match.group(2)!}',
    );
  }
  return lines.join('\n');
}
