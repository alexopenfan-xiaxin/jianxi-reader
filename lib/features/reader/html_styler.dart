import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_settings_controller.dart';

class HtmlStyler {
  const HtmlStyler._();

  static String buildAssimilatedHtml(
    String rawHtml, {
    required double fontSize,
    required double lineHeight,
    required ReadingPalette readingPalette,
    required double horizontalPadding,
    double topPadding = 0,
  }) {
    final topPaddingPx = topPadding.toStringAsFixed(1);
    final horizontalPaddingPx = horizontalPadding.toStringAsFixed(1);
    final ink = _cssColor(readingPalette.foreground);
    final muted = _cssColor(readingPalette.muted);
    final canvas = _cssColor(readingPalette.surface);
    final parchment = _cssColor(readingPalette.background);
    final hairline = _cssColor(readingPalette.border);
    final primary = _cssColor(readingPalette.link);
    final codeBackground = _cssColor(readingPalette.codeBackground);
    final colorScheme =
        readingPalette.background.computeLuminance() < 0.5 ? 'dark' : 'light';

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
  <style>
    :root {
      color-scheme: $colorScheme;
      --primary: $primary;
      --ink: $ink;
      --muted: $muted;
      --canvas: $canvas;
      --parchment: $parchment;
      --hairline: $hairline;
      --code-bg: $codeBackground;
      --radius-sm: 8px;
      --radius-md: 11px;
      --radius-lg: 18px;
    }
    * {
      box-sizing: border-box !important;
    }
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      background: var(--parchment) !important;
      color: var(--ink) !important;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", sans-serif !important;
      font-size: ${fontSize.toStringAsFixed(1)}px !important;
      line-height: ${lineHeight.toStringAsFixed(2)} !important;
      letter-spacing: -0.374px !important;
      overflow-wrap: anywhere;
    }
    body {
      min-height: 100vh;
    }
    .reader-shell {
      width: min(100%, 760px);
      margin: 0 auto;
      padding: ${topPaddingPx}px ${horizontalPaddingPx}px 48px;
      background: var(--parchment);
    }
    h1, h2, h3, h4, h5, h6 {
      color: var(--ink) !important;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif !important;
      font-weight: 600 !important;
      letter-spacing: -0.374px !important;
      margin: 1.35em 0 0.45em !important;
      line-height: 1.16 !important;
    }
    h1 { font-size: ${(fontSize + 16).toStringAsFixed(1)}px !important; }
    h2 { font-size: ${(fontSize + 10).toStringAsFixed(1)}px !important; }
    h3 { font-size: ${(fontSize + 5).toStringAsFixed(1)}px !important; }
    h4, h5, h6 { font-size: ${(fontSize + 2).toStringAsFixed(1)}px !important; }
    p, ul, ol, blockquote, pre, table, figure {
      margin-top: 0 !important;
      margin-bottom: 17px !important;
    }
    a {
      color: var(--primary) !important;
      text-decoration: none !important;
    }
    img, video, iframe, canvas, svg {
      max-width: 100% !important;
      height: auto !important;
      border-radius: var(--radius-md) !important;
    }
    pre {
      overflow-x: auto !important;
      padding: 16px !important;
      background: var(--code-bg) !important;
      border: 1px solid var(--hairline) !important;
      border-radius: var(--radius-md) !important;
      box-shadow: none !important;
      color: var(--ink) !important;
    }
    code, kbd, samp, var {
      font-family: "SF Mono", "Cascadia Code", Consolas, monospace !important;
      font-size: 0.92em !important;
      background: var(--code-bg) !important;
      border-radius: var(--radius-sm) !important;
      padding: 0.12em 0.35em !important;
      color: var(--ink) !important;
    }
    pre code {
      padding: 0 !important;
      background: transparent !important;
      color: inherit !important;
    }
    mark {
      background: rgba(255,204,51,.3) !important;
      color: var(--ink) !important;
      border-radius: 2px !important;
      padding: 0 2px !important;
    }
    blockquote {
      padding: 14px 17px !important;
      background: var(--canvas) !important;
      border-left: 4px solid var(--primary) !important;
      border-radius: var(--radius-md) !important;
      color: var(--muted) !important;
    }
    table {
      width: 100% !important;
      border-collapse: separate !important;
      border-spacing: 0 !important;
      overflow: hidden !important;
      background: var(--canvas) !important;
      border: 1px solid var(--hairline) !important;
      border-radius: var(--radius-md) !important;
      color: var(--ink) !important;
    }
    th, td {
      padding: 12px !important;
      border-bottom: 1px solid var(--hairline) !important;
      text-align: left !important;
      vertical-align: top !important;
      color: var(--ink) !important;
    }
    tr:last-child th, tr:last-child td {
      border-bottom: 0 !important;
    }
    hr {
      border: 0 !important;
      border-top: 1px solid var(--hairline) !important;
      margin: 32px 0 !important;
    }
    dt, dd {
      color: var(--ink) !important;
    }
    figcaption {
      color: var(--muted) !important;
    }
    ::selection {
      background: rgba(0,102,204,.28) !important;
      color: var(--ink) !important;
    }
  </style>
</head>
<body>
  <main class="reader-shell">
    ${_sanitizeHtml(rawHtml)}
  </main>
</body>
</html>
''';
  }

  static String _sanitizeHtml(String rawHtml) {
    var sanitized = rawHtml.replaceAll(
      RegExp(
        r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
        caseSensitive: false,
      ),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r"<meta[^>]*http-equiv=["
        "']?refresh["
        "']?[^>]*>",
        caseSensitive: false,
      ),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'<(iframe|object|embed)\b[^<]*(?:(?!<\/\1>)<[^<]*)*<\/\1>',
        caseSensitive: false,
      ),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\s+on[a-zA-Z]+\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r"\s+on[a-zA-Z]+\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\s+on[a-zA-Z]+\s*=\s*[^\s>]+', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'\s+(href|src)\s*=\s*"javascript:[^"]*"',
        caseSensitive: false,
      ),
      (match) => ' ${match.group(1)}="#"',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r"\s+(href|src)\s*=\s*'javascript:[^']*'",
        caseSensitive: false,
      ),
      (match) => " ${match.group(1)}='#'",
    );
    return sanitized;
  }

  static String escapedTitle(String title) {
    return const HtmlEscape().convert(title);
  }

  static String _cssColor(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
}
