import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/markdown/builders/syntax_highlight_code_block_builder.dart';

const _languageSamples = {
  'bash': 'if true; then echo "\$HOME"; fi',
  'http': 'GET /api HTTP/1.1\nContent-Type: application/json',
  'json': '{"enabled": true, "count": 3}',
  'sql': 'SELECT name FROM users WHERE id = 1;',
  'dart': 'final count = 1;',
  'python': 'def greet():\n    return "hi"',
  'javascript': 'const enabled = true;',
  'typescript': 'const name: string = "Codex";',
  'java': 'public class App { private int count = 1; }',
  'kotlin': 'fun main() = println("hi")',
  'swift': 'let enabled = true',
  'rust': 'fn main() { let enabled = true; }',
  'go': 'func main() { var enabled = true }',
  'yaml': 'enabled: true',
  'html': '<div class="reader">Hello</div>',
  'css': '.reader { color: red; }',
  'cpp': 'int main() { return 0; }',
  'csharp': 'public class App { bool enabled = true; }',
  'php': '<?php echo "hello"; ?>',
  'ruby': 'def greet\n  puts "hi"\nend',
  'markdown': '# Heading\n\n**bold**',
  'dockerfile': 'FROM alpine\nRUN echo ok',
  'powershell': '\$name = "Codex"\nWrite-Host \$name',
  'graphql': 'query User { user { id name } }',
  'vue': '<template><div>{{ message }}</div></template>',
  'ini': 'enabled=true',
  'nginx': 'server { listen 80; }',
  'gradle': 'plugins { id "java" }',
  'makefile': 'build:\n\techo ok',
  'protobuf': 'message User { string name = 1; }',
  'r': 'value <- c(1, 2)',
  'scala': 'val value: Int = 1',
  'shell': 'echo "\$HOME"',
  'postgresql': 'SELECT now();',
  'serverpod_protocol': 'class: User\nfields:\n  name: String',
};

void main() {
  testWidgets('high-frequency code languages produce visible highlighting', (
    tester,
  ) async {
    for (final entry in _languageSamples.entries) {
      final registry = BuilderRegistry()
        ..register(
          'code_block',
          const SyntaxHighlightCodeBlockBuilder(
            showCopyButton: false,
            showLanguageTag: false,
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: SmoothMarkdown(
            data: '```${entry.key}\n${entry.value}\n```',
            useEnhancedComponents: false,
            builderRegistry: registry,
          ),
        ),
      );
      await tester.pump();

      final firstLine = entry.value.split('\n').first;
      final code = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text)
          .whereType<TextSpan>()
          .firstWhere((span) => span.toPlainText().contains(firstLine));
      expect(_hasColoredToken(code), isTrue, reason: entry.key);
    }
  });
}

bool _hasColoredToken(TextSpan span) {
  return span.children
          ?.whereType<TextSpan>()
          .any(
            (child) => child.style?.color != null || _hasColoredToken(child),
          ) ??
      false;
}
