import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jianxi_reader/features/reader/markdown/builders/syntax_highlight_code_block_builder.dart';

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
  'ini': '[reader]\nenabled=true',
  'nginx': 'server { listen 80; }',
  'gradle': 'plugins { id "java" }',
  'makefile': 'build:\n\techo ok',
  'protobuf': 'message User { string name = 1; }',
  'r': 'value <- c(1, 2)',
  'scala': 'val value: Int = 1',
  'shell': 'if true; then echo "\$HOME"; fi',
  'postgresql': 'SELECT now();',
  'serverpod_protocol': 'class: User\nfields:\n  name: String',
  'c': '#include <stdio.h>\nint main() { return 0; }',
  'lua': 'local value = 1\nprint(value)',
  'perl': 'my \$value = 1;\nprint \$value;',
  'objective-c': '@interface Reader : NSObject\n@end',
  'haskell': 'main = putStrLn "hello"',
  'elixir': 'def greet(name), do: "Hello #{name}"',
  'clojure': '(defn greet [name] (println name))',
  'groovy': 'def greet(name) { println "Hello \$name" }',
  'solidity': 'contract Reader { bool public enabled = true; }',
  'matlab': 'function y = square(x)\n  y = x^2;\nend',
  'julia': 'function square(x)\n  return x^2\nend',
  'latex': r'\section{Reader} \textbf{Hello}',
  'diff': '-old value\n+new value',
  'asm': 'mov eax, 1\nret',
  'verilog': 'module reader; reg enabled; endmodule',
  'toml': '[reader]\nenabled = true',
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
            selectable: true,
            useEnhancedComponents: false,
            builderRegistry: registry,
          ),
        ),
      );
      await tester.pump();

      final firstLine = entry.value.split('\n').first;
      final code = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.textSpan)
          .whereType<TextSpan>()
          .firstWhere((span) => span.toPlainText().contains(firstLine));
      expect(_tokenColors(code), isNotEmpty, reason: entry.key);
    }
  });

  testWidgets('keeps Python highlighting when a block contains illegal lines', (
    tester,
  ) async {
    const code = '''def greet(name):
    print(f"Hello, {name}!")
greet("Markdown")
const sum = (a, b) => a + b;
console.log(sum(2, 4));''';
    final span = await _renderCode(tester, 'python', code);
    expect(_tokenColors(span).length, greaterThanOrEqualTo(2));
  });

  testWidgets('highlights HTTP requests without a protocol version', (
    tester,
  ) async {
    const code = '''GET /oauth/authorize
  ?response_type=code
  &client_id=<client_id>
  &redirect_uri=<url_encoded_callback>
  &scope=<custom_marker>
  &state=<csrf_random_value>
  &code_challenge=<challenge>
  &code_challenge_method=S256''';
    final span = await _renderCode(tester, 'http', code);
    expect(_tokenColors(span).length, greaterThanOrEqualTo(2));
  });
}

Future<TextSpan> _renderCode(
  WidgetTester tester,
  String language,
  String code,
) async {
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
        data: '```$language\n$code\n```',
        selectable: true,
        useEnhancedComponents: false,
        builderRegistry: registry,
      ),
    ),
  );
  await tester.pump();
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.textSpan)
      .whereType<TextSpan>()
      .firstWhere(
        (span) => span.toPlainText().contains(code.split('\n').first),
      );
}

Set<Color> _tokenColors(TextSpan span) {
  final colors = <Color>{};
  for (final child
      in span.children?.whereType<TextSpan>() ?? const <TextSpan>[]) {
    final color = child.style?.color;
    if (color != null) colors.add(color);
    final backgroundColor = child.style?.backgroundColor;
    if (backgroundColor != null) colors.add(backgroundColor);
    colors.addAll(_tokenColors(child));
  }
  return colors;
}
