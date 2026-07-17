import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

class BareUrlPlugin extends InlineParserPlugin {
  const BareUrlPlugin();

  @override
  String get id => 'bare_url';
  @override
  String get name => 'Bare URL Plugin';
  @override
  String get triggerCharacter => 'h';
  @override
  int get priority => 10;

  static final _urlBody = RegExp(
    r'^(?:https?|ftp)://[^\s<>\[\]"`]+',
    caseSensitive: false,
  );
  static const _trailingPunct = '?!.,:*_~';

  @override
  bool canParse(String text, int index) {
    if (index >= text.length) return false;
    final c = text[index];
    if (c != 'h' && c != 'H') return false;
    return _urlBody.matchAsPrefix(text.substring(index)) != null;
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex >= text.length) return null;
    final c = text[startIndex];
    if (c != 'h' && c != 'H') return null;
    final m = _urlBody.matchAsPrefix(text.substring(startIndex));
    if (m == null) return null;
    var url = m.group(0)!;
    while (url.isNotEmpty && _trailingPunct.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return null;
    return InlineParseResult(
      node: LinkNode(url: url, children: [TextNode(url)]),
      consumed: url.length,
    );
  }
}
