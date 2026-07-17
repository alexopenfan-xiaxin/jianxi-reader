import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/markdown/markdown_preprocessor.dart';

void main() {
  test('normalizes Windows and legacy line endings before parsing', () {
    final markdown = preprocessMarkdown(
      '# API Relay Security Audit Report\r\nBody\rNext',
    );

    expect(markdown, '# API Relay Security Audit Report\nBody\nNext');
    expect(MarkdownParser().parse(markdown).first, isA<HeaderNode>());
  });
}
