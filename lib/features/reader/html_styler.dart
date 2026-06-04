import 'dart:convert';

class HtmlStyler {
  const HtmlStyler._();

  static String buildAssimilatedHtml(
    String rawHtml, {
    required double fontSize,
    required double lineHeight,
    required bool isDark,
    double topPadding = 0,
  }) {
    final colors = isDark ? _darkColors : _lightColors;

    final topPaddingPx = topPadding.toStringAsFixed(1);

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
  <style>
    :root {
      color-scheme: ${isDark ? 'dark' : 'light'};
      --primary: #0066cc;
      --ink: ${colors.ink};
      --muted: ${colors.muted};
      --canvas: ${colors.canvas};
      --parchment: ${colors.parchment};
      --hairline: ${colors.hairline};
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
      padding: ${topPaddingPx}px 20px 48px;
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
      background: var(--canvas) !important;
      border: 1px solid var(--hairline) !important;
      border-radius: var(--radius-md) !important;
      box-shadow: none !important;
    }
    code, kbd, samp {
      font-family: "SF Mono", "Cascadia Code", Consolas, monospace !important;
      font-size: 0.92em !important;
      background: var(--canvas) !important;
      border-radius: var(--radius-sm) !important;
      padding: 0.12em 0.35em !important;
    }
    pre code {
      padding: 0 !important;
      background: transparent !important;
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
    }
    th, td {
      padding: 12px !important;
      border-bottom: 1px solid var(--hairline) !important;
      text-align: left !important;
      vertical-align: top !important;
    }
    tr:last-child th, tr:last-child td {
      border-bottom: 0 !important;
    }
    hr {
      border: 0 !important;
      border-top: 1px solid var(--hairline) !important;
      margin: 32px 0 !important;
    }
  </style>
</head>
<body>
  <main class="reader-shell">
    ${_stripUnsafeShell(rawHtml)}
  </main>
</body>
</html>
''';
  }

  static String _stripUnsafeShell(String rawHtml) {
    final withoutScripts = rawHtml.replaceAll(
      RegExp(
        r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
        caseSensitive: false,
      ),
      '',
    );
    return withoutScripts.replaceAll(
      RegExp(
        r"<meta[^>]*http-equiv=["
        "']?refresh["
        "']?[^>]*>",
        caseSensitive: false,
      ),
      '',
    );
  }

  static String escapedTitle(String title) {
    return const HtmlEscape().convert(title);
  }
}

class _HtmlColors {
  const _HtmlColors({
    required this.ink,
    required this.muted,
    required this.canvas,
    required this.parchment,
    required this.hairline,
  });

  final String ink;
  final String muted;
  final String canvas;
  final String parchment;
  final String hairline;
}

const _lightColors = _HtmlColors(
  ink: '#1d1d1f',
  muted: '#7a7a7a',
  canvas: '#ffffff',
  parchment: '#f5f5f7',
  hairline: '#e0e0e0',
);

const _darkColors = _HtmlColors(
  ink: '#ffffff',
  muted: '#cccccc',
  canvas: '#272729',
  parchment: '#000000',
  hairline: '#3a3a3c',
);
