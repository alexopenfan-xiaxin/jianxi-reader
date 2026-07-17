import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/app_settings_controller.dart';
import 'package:jianxi_reader/features/reader/html_styler.dart';

void main() {
  test('HTML output blocks document scripts while preserving content', () {
    final html = HtmlStyler.buildAssimilatedHtml(
      '<h1>Title</h1><script>alert(1)</script><img src="file:///cover.png">',
      fontSize: 16,
      lineHeight: 1.6,
      readingPalette: const ReadingPalette(
        background: Colors.white,
        foreground: Colors.black,
        muted: Colors.grey,
        surface: Colors.white,
        border: Colors.grey,
        link: Colors.blue,
        codeBackground: Color(0xFFF5F5F5),
      ),
      horizontalPadding: 16,
    );

    expect(html, contains("script-src 'none'"));
    expect(html, contains('<h1>Title</h1>'));
    expect(html, isNot(contains('alert(1)')));
  });
}
