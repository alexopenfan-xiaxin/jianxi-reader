import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/emoji_service.dart';

// ── Underline Plugin (++text++) ───────────────────────────────────────────

class UnderlineNode extends MarkdownNode {
  const UnderlineNode(this.text);
  final String text;

  @override
  String get type => 'underline';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  UnderlineNode copyWith({String? text}) => UnderlineNode(text ?? this.text);

  @override
  String toString() => 'UnderlineNode(text: $text)';
}

class UnderlinePlugin extends InlineParserPlugin {
  const UnderlinePlugin();

  @override
  String get id => 'underline';
  @override
  String get name => 'Underline Plugin';
  @override
  String get triggerCharacter => '+';
  @override
  int get priority => 15;

  @override
  bool canParse(String text, int index) {
    if (index + 1 >= text.length) return false;
    return text[index] == '+' && text[index + 1] == '+';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex + 1 >= text.length) return null;
    if (text[startIndex] != '+' || text[startIndex + 1] != '+') return null;

    var i = startIndex + 2;
    while (i + 1 < text.length) {
      if (text[i] == '+' && text[i + 1] == '+') {
        final content = text.substring(startIndex + 2, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: UnderlineNode(content),
          consumed: i - startIndex + 2,
        );
      }
      i++;
    }
    return null;
  }
}

// ── Bare URL Plugin (autolink http(s):// / ftp://) ───────────────────────

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
      node: LinkNode(
        url: url,
        children: [TextNode(url)],
      ),
      consumed: url.length,
    );
  }
}

class UnderlineBuilder extends MarkdownWidgetBuilder {
  const UnderlineBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is UnderlineNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final underlineNode = node as UnderlineNode;
    final style = (styleSheet.textStyle ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
    );
    return Text(underlineNode.text, style: style);
  }
}

// ── Highlight Plugin (==text==) ─────────────────────────────────────────

class HighlightNode extends MarkdownNode {
  const HighlightNode(this.text);
  final String text;

  @override
  String get type => 'highlight';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  HighlightNode copyWith({String? text}) => HighlightNode(text ?? this.text);

  @override
  String toString() => 'HighlightNode(text: $text)';
}

class HighlightPlugin extends InlineParserPlugin {
  const HighlightPlugin();

  @override
  String get id => 'highlight';
  @override
  String get name => 'Highlight Plugin';
  @override
  String get triggerCharacter => '=';
  @override
  int get priority => 14;

  @override
  bool canParse(String text, int index) {
    if (index + 1 >= text.length) return false;
    return text[index] == '=' && text[index + 1] == '=';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex + 1 >= text.length) return null;
    if (text[startIndex] != '=' || text[startIndex + 1] != '=') return null;

    var i = startIndex + 2;
    while (i + 1 < text.length) {
      if (text[i] == '=' && text[i + 1] == '=') {
        final content = text.substring(startIndex + 2, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: HighlightNode(content),
          consumed: i - startIndex + 2,
        );
      }
      i++;
    }
    return null;
  }
}

class HighlightBuilder extends MarkdownWidgetBuilder {
  const HighlightBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is HighlightNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final highlightNode = node as HighlightNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEB3B).withOpacity(0.35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(highlightNode.text, style: baseStyle),
    );
  }
}

// ── Superscript Plugin (^text^) ─────────────────────────────────────────

class SuperscriptNode extends MarkdownNode {
  const SuperscriptNode(this.text);
  final String text;

  @override
  String get type => 'superscript';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  SuperscriptNode copyWith({String? text}) => SuperscriptNode(text ?? this.text);

  @override
  String toString() => 'SuperscriptNode(text: $text)';
}

class SuperscriptPlugin extends InlineParserPlugin {
  const SuperscriptPlugin();

  @override
  String get id => 'superscript';
  @override
  String get name => 'Superscript Plugin';
  @override
  String get triggerCharacter => '^';
  @override
  int get priority => 14;

  @override
  bool canParse(String text, int index) {
    if (index >= text.length) return false;
    return text[index] == '^';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex >= text.length) return null;
    if (text[startIndex] != '^') return null;

    var i = startIndex + 1;
    while (i < text.length) {
      if (text[i] == '^') {
        final content = text.substring(startIndex + 1, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: SuperscriptNode(content),
          consumed: i - startIndex + 1,
        );
      }
      i++;
    }
    return null;
  }
}

class SuperscriptBuilder extends MarkdownWidgetBuilder {
  const SuperscriptBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is SuperscriptNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final supNode = node as SuperscriptNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Text(
      supNode.text,
      style: baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 14) * 0.72,
        textBaseline: TextBaseline.alphabetic,
      ),
      textScaler: const TextScaler.linear(1),
    );
  }
}

// ── Subscript Plugin (~text~) ───────────────────────────────────────────

class SubscriptNode extends MarkdownNode {
  const SubscriptNode(this.text);
  final String text;

  @override
  String get type => 'subscript';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};

  @override
  SubscriptNode copyWith({String? text}) => SubscriptNode(text ?? this.text);

  @override
  String toString() => 'SubscriptNode(text: $text)';
}

class SubscriptPlugin extends InlineParserPlugin {
  const SubscriptPlugin();

  @override
  String get id => 'subscript';
  @override
  String get name => 'Subscript Plugin';
  @override
  String get triggerCharacter => '~';
  @override
  int get priority => 14;

  @override
  bool canParse(String text, int index) {
    if (index + 1 >= text.length) return false;
    return text[index] == '~' && text[index + 1] != '~';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (startIndex + 1 >= text.length) return null;
    if (text[startIndex] != '~') return null;
    if (text[startIndex + 1] == '~') return null;

    var i = startIndex + 1;
    while (i < text.length) {
      if (text[i] == '~') {
        final content = text.substring(startIndex + 1, i);
        if (content.isEmpty) return null;
        return InlineParseResult(
          node: SubscriptNode(content),
          consumed: i - startIndex + 1,
        );
      }
      i++;
    }
    return null;
  }
}

class SubscriptBuilder extends MarkdownWidgetBuilder {
  const SubscriptBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is SubscriptNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final subNode = node as SubscriptNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Text(
      subNode.text,
      style: baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 14) * 0.72,
        textBaseline: TextBaseline.alphabetic,
      ),
      textScaler: const TextScaler.linear(1),
    );
  }
}

// ── Link Builder (clickable + styled) ─────────────────────────────────────

class ClickableLinkBuilder extends MarkdownWidgetBuilder {
  const ClickableLinkBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is LinkNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final linkNode = node as LinkNode;
    final linkStyle = (styleSheet.linkStyle ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
      color: AppColors.primary,
    );

    final text = linkNode.children
        .whereType<TextNode>()
        .map((n) => n.content)
        .join();

    return Semantics(
      link: true,
      label: linkNode.title ?? linkNode.url,
      child: GestureDetector(
        onTap: () => context.onTapLink?.call(linkNode.url),
        behavior: HitTestBehavior.opaque,
        child: Text(text, style: linkStyle),
      ),
    );
  }
}

// ── Image Builder (tappable + preview + SVG support) ──────────────────────

class TappableImageBuilder extends MarkdownWidgetBuilder {
  const TappableImageBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is ImageNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final imageNode = node as ImageNode;
    final isSvg = imageNode.url.toLowerCase().endsWith('.svg');
    final isNetwork = imageNode.url.startsWith('http://') ||
        imageNode.url.startsWith('https://');

    Widget imageWidget;
    if (isNetwork) {
      imageWidget = _CachedMarkdownImage(url: imageNode.url, isSvg: isSvg);
    } else if (isSvg) {
      imageWidget = SvgPicture.asset(imageNode.url);
    } else {
      imageWidget = Image.asset(
        imageNode.url,
        errorBuilder: (ctx, error, stackTrace) => const Icon(Icons.broken_image),
      );
    }

    final caption = imageNode.alt.isNotEmpty
        ? imageNode.alt
        : (imageNode.title ?? '');

    return Semantics(
      image: true,
      label: caption.isNotEmpty ? caption : '图片',
      button: true,
      child: GestureDetector(
        onTap: () => context.onTapImage?.call(
          imageNode.url,
          imageNode.alt,
          imageNode.title,
        ),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageWidget,
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  caption,
                  style: (styleSheet.paragraphStyle ?? const TextStyle()).copyWith(
                    fontSize: 12,
                    color: AppColors.bodyMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CachedMarkdownImage extends StatefulWidget {
  const _CachedMarkdownImage({required this.url, required this.isSvg});

  final String url;
  final bool isSvg;

  @override
  State<_CachedMarkdownImage> createState() => _CachedMarkdownImageState();
}

class _CachedMarkdownImageState extends State<_CachedMarkdownImage> {
  static const _timeout = Duration(seconds: 15);

  Future<File>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant _CachedMarkdownImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.isSvg != widget.isSvg) {
      _fileFuture = _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _fileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _ImageLoadingState(
            message: '图片加载中',
            showRetry: false,
            onRetry: _retry,
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ImageLoadingState(
            message: '图片加载超时',
            showRetry: true,
            onRetry: _retry,
          );
        }
        final file = snapshot.data!;
        if (widget.isSvg) {
          return SvgPicture.file(file);
        }
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (ctx, error, stackTrace) {
            return _ImageLoadingState(
              message: '图片渲染失败',
              showRetry: true,
              onRetry: _retry,
            );
          },
        );
      },
    );
  }

  void _retry() {
    setState(() {
      _fileFuture = _loadImage(forceRefresh: true);
    });
  }

  Future<File> _loadImage({bool forceRefresh = false}) async {
    final file = await _cacheFileForUrl(widget.url, widget.isSvg);
    if (!forceRefresh && file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    return _downloadImage(file);
  }

  Future<File> _downloadImage(File destination) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(widget.url)).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('图片请求失败：${response.statusCode}', uri: Uri.parse(widget.url));
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk))
          .timeout(_timeout);
      if (bytes.isEmpty) {
        throw const FileSystemException('图片内容为空');
      }
      await destination.parent.create(recursive: true);
      return destination.writeAsBytes(bytes, flush: true);
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _cacheFileForUrl(String url, bool isSvg) async {
    final directory = await getTemporaryDirectory();
    final cacheDirectory = Directory('${directory.path}/jianxi_image_cache');
    final extension = isSvg ? 'svg' : 'img';
    final key = _stableCacheKey(url);
    return File('${cacheDirectory.path}/$key.$extension');
  }

  String _stableCacheKey(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _ImageLoadingState extends StatelessWidget {
  const _ImageLoadingState({
    required this.message,
    required this.showRetry,
    required this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!showRetry)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.image_not_supported_outlined, color: palette.muted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                  letterSpacing: 0,
                ),
          ),
          if (showRetry) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Indented Ordered List Plugin ─────────────────────────────────────────

class IndentedOrderedListNode extends MarkdownNode {
  const IndentedOrderedListNode({required this.items});

  final List<IndentedOrderedListItem> items;

  @override
  String get type => 'indented_ordered_list';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'items': items.map((item) => item.toJson()).toList(),
      };

  @override
  IndentedOrderedListNode copyWith({List<IndentedOrderedListItem>? items}) {
    return IndentedOrderedListNode(items: items ?? this.items);
  }
}

class IndentedOrderedListItem {
  const IndentedOrderedListItem({
    required this.number,
    required this.text,
    this.children = const [],
  });

  final int number;
  final String text;
  final List<IndentedOrderedListItem> children;

  Map<String, dynamic> toJson() => {
        'number': number,
        'text': text,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

class IndentedOrderedListPlugin extends BlockParserPlugin {
  const IndentedOrderedListPlugin();

  static final _orderedLine = RegExp(r'^( *)(\d+)[.)]\s+(.+)$');

  @override
  String get id => 'indented_ordered_list';

  @override
  String get name => 'Indented Ordered List Plugin';

  @override
  int get priority => 10;

  @override
  bool canParse(String line, List<String> lines, int index) {
    final first = _orderedLine.firstMatch(line);
    if (first == null || first.group(1)!.isNotEmpty) {
      return false;
    }
    for (var i = index + 1; i < lines.length; i++) {
      final match = _orderedLine.firstMatch(lines[i]);
      if (match == null) {
        return false;
      }
      if (match.group(1)!.length > 0) {
        return true;
      }
    }
    return false;
  }

  @override
  BlockParseResult? parse(List<String> lines, int startIndex) {
    final rootItems = <_MutableOrderedListItem>[];
    final stack = <_OrderedListStackEntry>[];
    var consumed = 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        consumed++;
        continue;
      }
      final match = _orderedLine.firstMatch(line);
      if (match == null) {
        break;
      }

      final indent = match.group(1)!.length;
      final number = int.tryParse(match.group(2)!) ?? 1;
      final text = match.group(3)!.trim();
      final item = _MutableOrderedListItem(number: number, text: text);

      while (stack.isNotEmpty && indent <= stack.last.indent) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        if (indent > 0) {
          break;
        }
        rootItems.add(item);
      } else {
        stack.last.item.children.add(item);
      }
      stack.add(_OrderedListStackEntry(indent: indent, item: item));
      consumed++;
    }

    if (rootItems.isEmpty || consumed == 0) {
      return null;
    }
    return BlockParseResult(
      node: IndentedOrderedListNode(
        items: rootItems.map((item) => item.freeze()).toList(),
      ),
      linesConsumed: consumed,
    );
  }
}

class _MutableOrderedListItem {
  _MutableOrderedListItem({required this.number, required this.text});

  final int number;
  final String text;
  final List<_MutableOrderedListItem> children = [];

  IndentedOrderedListItem freeze() {
    return IndentedOrderedListItem(
      number: number,
      text: text,
      children: children.map((child) => child.freeze()).toList(),
    );
  }
}

class _OrderedListStackEntry {
  const _OrderedListStackEntry({required this.indent, required this.item});

  final int indent;
  final _MutableOrderedListItem item;
}

class IndentedOrderedListBuilder extends MarkdownWidgetBuilder {
  const IndentedOrderedListBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is IndentedOrderedListNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final listNode = node as IndentedOrderedListNode;
    final textStyle = styleSheet.paragraphStyle ??
        styleSheet.textStyle ??
        const TextStyle(fontSize: 16);
    final markerStyle = styleSheet.listBulletStyle ?? textStyle;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in listNode.items)
            _IndentedOrderedListItemWidget(
              item: item,
              depth: 0,
              textStyle: textStyle,
              markerStyle: markerStyle,
            ),
        ],
      ),
    );
  }
}

class _IndentedOrderedListItemWidget extends StatelessWidget {
  const _IndentedOrderedListItemWidget({
    required this.item,
    required this.depth,
    required this.textStyle,
    required this.markerStyle,
  });

  final IndentedOrderedListItem item;
  final int depth;
  final TextStyle textStyle;
  final TextStyle markerStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: depth == 0 ? 0 : 22,
        top: depth == 0 ? 4 : 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Text('${item.number}.', style: markerStyle),
              ),
              Expanded(child: Text(item.text, style: textStyle)),
            ],
          ),
          if (item.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in item.children)
                    _IndentedOrderedListItemWidget(
                      item: child,
                      depth: depth + 1,
                      textStyle: textStyle,
                      markerStyle: markerStyle,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Emoji Builder (renders :emoji: shortcodes) ────────────────────────────

class EmojiBuilder extends MarkdownWidgetBuilder {
  const EmojiBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is EmojiNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final emojiNode = node as EmojiNode;
    final baseStyle = styleSheet.textStyle ?? const TextStyle();
    return Text(emojiNode.emoji, style: baseStyle);
  }
}

// ── Syntax Highlight Code Block Builder (via syntax_highlight) ─────────────

class PerformanceTableBuilder extends MarkdownWidgetBuilder {
  const PerformanceTableBuilder();

  static const _minColumnWidth = 136.0;

  @override
  bool canBuild(MarkdownNode node) => node is TableNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final tableNode = node as TableNode;
    final columnCount = _columnCount(tableNode);
    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    final rows = <TableRow>[
      _buildRow(
        tableNode.headers,
        tableNode.alignments,
        columnCount,
        styleSheet,
        context,
        isHeader: true,
      ),
      for (final row in tableNode.rows)
        _buildRow(
          row.cells,
          tableNode.alignments,
          columnCount,
          styleSheet,
          context,
          isHeader: false,
        ),
    ];

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (buildContext, constraints) {
          final availableWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
          final tableWidth = columnCount * _minColumnWidth;
          final minWidth =
              tableWidth > availableWidth ? tableWidth : availableWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: Table(
                border: styleSheet.tableBorder,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
          );
        },
      ),
    );
  }

  static int _columnCount(TableNode tableNode) {
    var columnCount = tableNode.alignments.length;
    if (tableNode.headers.length > columnCount) {
      columnCount = tableNode.headers.length;
    }
    for (final row in tableNode.rows) {
      if (row.cells.length > columnCount) {
        columnCount = row.cells.length;
      }
    }
    return columnCount;
  }

  TableRow _buildRow(
    List<List<MarkdownNode>> cells,
    List<TableAlignment?> alignments,
    int columnCount,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context, {
    required bool isHeader,
  }) {
    return TableRow(
      decoration: isHeader ? styleSheet.tableHeaderDecoration : null,
      children: [
        for (var index = 0; index < columnCount; index++)
          _buildCell(
            index < cells.length ? cells[index] : const <MarkdownNode>[],
            index < alignments.length ? alignments[index] : null,
            styleSheet,
            context,
            isHeader: isHeader,
          ),
      ],
    );
  }

  Widget _buildCell(
    List<MarkdownNode> content,
    TableAlignment? alignment,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context, {
    required bool isHeader,
  }) {
    final textStyle = isHeader
        ? styleSheet.tableHeaderStyle ?? styleSheet.textStyle
        : styleSheet.tableCellStyle ?? styleSheet.textStyle;
    final inlineRenderer = context.inlineRenderer;
    final child = inlineRenderer != null
        ? inlineRenderer(content, textStyle)
        : Text(
            content.whereType<TextNode>().map((node) => node.content).join(),
            style: textStyle,
          );

    return Container(
      constraints: const BoxConstraints(minWidth: _minColumnWidth),
      padding: styleSheet.tableCellPadding ??
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: _alignmentFor(alignment),
      color: isHeader ? styleSheet.tableHeaderDecoration?.color : null,
      child: DefaultTextStyle.merge(
        style: textStyle,
        child: child,
      ),
    );
  }

  static Alignment _alignmentFor(TableAlignment? alignment) {
    return switch (alignment) {
      TableAlignment.center => Alignment.center,
      TableAlignment.right => Alignment.centerRight,
      TableAlignment.left || null => Alignment.centerLeft,
    };
  }
}

class SyntaxHighlightCodeBlockBuilder extends MarkdownWidgetBuilder {
  const SyntaxHighlightCodeBlockBuilder({
    this.showCopyButton = true,
    this.showLanguageTag = true,
  });

  final bool showCopyButton;
  final bool showLanguageTag;

  @override
  bool canBuild(MarkdownNode node) => node is CodeBlockNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final codeBlockNode = node as CodeBlockNode;
    return _SyntaxHighlightCodeBlockWidget(
      code: codeBlockNode.code,
      language: codeBlockNode.language,
      styleSheet: styleSheet,
      showCopyButton: showCopyButton,
      showLanguageTag: showLanguageTag,
      selectable: context.selectable,
    );
  }
}

class _SyntaxHighlightCodeBlockWidget extends StatefulWidget {
  const _SyntaxHighlightCodeBlockWidget({
    required this.code,
    required this.language,
    required this.styleSheet,
    required this.showCopyButton,
    required this.showLanguageTag,
    this.selectable = false,
  });

  final String code;
  final String? language;
  final MarkdownStyleSheet styleSheet;
  final bool showCopyButton;
  final bool showLanguageTag;
  final bool selectable;

  @override
  State<_SyntaxHighlightCodeBlockWidget> createState() =>
      _SyntaxHighlightCodeBlockWidgetState();
}

class _HighlightCacheKey {
  const _HighlightCacheKey({
    required this.language,
    required this.themeId,
    required this.code,
  });

  final String language;
  final String themeId;
  final String code;

  @override
  bool operator ==(Object other) {
    return other is _HighlightCacheKey &&
        other.language == language &&
        other.themeId == themeId &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(language, themeId, code);
}

class _SyntaxHighlightCodeBlockWidgetState
    extends State<_SyntaxHighlightCodeBlockWidget> {
  static bool _initialized = false;
  static bool _initFailed = false;
  static Future<void>? _initFuture;
  static HighlighterTheme? _lightTheme;
  static HighlighterTheme? _darkTheme;
  static final _highlightCache = LinkedHashMap<_HighlightCacheKey, TextSpan>();
  static const _highlightCacheLimit = 80;

  bool _highlightReady = false;
  bool _copied = false;
  Timer? _copyResetTimer;

  /// Only languages that have actual grammar files in syntax_highlight 0.5.0.
  /// If a grammar is missing, Highlighter.initialize() throws and kills ALL
  /// highlighting.  Keep this list in sync with the package's grammars/ dir.
  static final List<String> _supportedLanguages = [
    'dart', 'python', 'javascript', 'typescript', 'java', 'kotlin',
    'swift', 'rust', 'go', 'sql', 'yaml', 'json', 'html', 'css',
    // Not available in 0.5.0: cpp, c, ruby, php, shell, xml
  ];

  @override
  void initState() {
    super.initState();
    if (_initialized) {
      _highlightReady = true;
      return;
    }
    _initFuture ??= _doInitialize().then((ok) {
      if (!ok) {
        debugPrint('[SyntaxHighlight] init failed — falling back to plain code');
      }
      if (mounted) setState(() => _highlightReady = true);
    });
  }

  /// Returns true if initialization succeeded.
  static Future<bool> _doInitialize() async {
    try {
      await Highlighter.initialize(_supportedLanguages);
      _lightTheme = await HighlighterTheme.loadLightTheme();
      _darkTheme = await HighlighterTheme.loadDarkTheme();
      debugPrint('[SyntaxHighlight] init OK (${_supportedLanguages.length} grammars)');
      _initialized = true;
      _initFailed = false;
      return true;
    } catch (e) {
      debugPrint('[SyntaxHighlight] init error: $e');
      // themes remain null → plain code fallback
      _initialized = true;
      _initFailed = true;
      return false;
    }
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  bool get _canHighlight =>
      widget.language != null &&
      _supportedLanguages.contains(widget.language!.toLowerCase());

  TextStyle _codeTextStyle() {
    final bgColor = widget.styleSheet.codeBlockDecoration?.color;
    final isDarkBg = bgColor != null && bgColor.computeLuminance() < 0.5;
    return (widget.styleSheet.codeBlockStyle ?? const TextStyle()).copyWith(
      color: widget.styleSheet.codeBlockStyle?.color ??
          (isDarkBg ? const Color(0xFFE0E0E0) : const Color(0xFF1E1E1E)),
    );
  }

  Widget _buildCodeContent(
    BuildContext context,
    HighlighterTheme? theme,
    String themeId,
  ) {
    if (theme != null && _canHighlight) {
      try {
        final lang = widget.language!.toLowerCase();
        final highlighted = _highlightCode(
          language: lang,
          theme: theme,
          themeId: themeId,
        );
        if (widget.selectable) return Text.rich(highlighted);
        return RichText(text: highlighted);
      } catch (e) {
        debugPrint('[SyntaxHighlight] highlight error (lang=${widget.language}, code=${widget.code.length} chars): $e');
        // fall through to plain code
      }
    }
    return _buildPlainCode();
  }

  Widget _buildPlainCode() {
    final style = _codeTextStyle();
    if (widget.selectable) {
      return Text.rich(TextSpan(text: widget.code, style: style));
    }
    return Text(widget.code, style: style);
  }

  TextSpan _highlightCode({
    required String language,
    required HighlighterTheme theme,
    required String themeId,
  }) {
    final key = _HighlightCacheKey(
      language: language,
      themeId: themeId,
      code: widget.code,
    );
    final cached = _highlightCache.remove(key);
    if (cached != null) {
      _highlightCache[key] = cached;
      return cached;
    }

    final highlighter = Highlighter(language: language, theme: theme);
    final highlighted = highlighter.highlight(widget.code);
    _highlightCache[key] = highlighted;
    while (_highlightCache.length > _highlightCacheLimit) {
      _highlightCache.remove(_highlightCache.keys.first);
    }
    return highlighted;
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final theme = brightness == Brightness.dark ? _darkTheme : _lightTheme;
    final themeId = brightness == Brightness.dark ? 'dark' : 'light';

    return RepaintBoundary(
      child: Container(
        decoration: widget.styleSheet.codeBlockDecoration?.copyWith(
          boxShadow: null,
        ),
        child: Stack(
          children: [
          Container(
            padding: widget.styleSheet.codeBlockPadding,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _highlightReady
                  ? _buildCodeContent(context, theme, themeId)
                  : _buildPlainCode(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLanguageTag && widget.language != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.language!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_initFailed && _canHighlight)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Tooltip(
                            message: '代码高亮失败，请查看调试日志',
                            child: Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                if (widget.showLanguageTag && widget.language != null)
                  const SizedBox(width: 8),
                if (widget.showCopyButton)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: _copyToClipboard,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _copied
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied ? Icons.check : Icons.content_copy,
                              size: 16,
                              color: _copied
                                  ? Colors.green[700]
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                            ),
                            if (_copied) ...[
                              const SizedBox(width: 4),
                              Text(
                                '已复制',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// ── Mindmap Plugin (```mindmap) ──────────────────────────────────────────

class MindmapNode extends MarkdownNode {
  const MindmapNode(this.code);
  final String code;

  @override
  String get type => 'mindmap';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'code': code};

  @override
  MindmapNode copyWith({String? code}) => MindmapNode(code ?? this.code);

  @override
  String toString() => 'MindmapNode(code: ${code.length > 40 ? code.substring(0, 40) : code})';
}

class MindmapPlugin extends BlockParserPlugin {
  const MindmapPlugin();

  @override
  String get id => 'mindmap';
  @override
  String get name => 'Mindmap Plugin';
  @override
  int get priority => 10;

  @override
  bool canParse(String line, List<String> lines, int index) {
    final trimmed = line.trim();
    return trimmed.startsWith('```mindmap') || trimmed.startsWith('~~~mindmap');
  }

  @override
  BlockParseResult? parse(List<String> lines, int startIndex) {
    final startLine = lines[startIndex].trim();
    final fenceChar = startLine.startsWith('```') ? '```' : '~~~';

    final codeLines = <String>[];
    var consumed = 1;
    for (var i = startIndex + 1; i < lines.length; i++) {
      consumed++;
      if (lines[i].trim().startsWith(fenceChar)) break;
      codeLines.add(lines[i]);
    }
    if (codeLines.isEmpty) return null;

    return BlockParseResult(
      node: MindmapNode(codeLines.join('\n').trim()),
      linesConsumed: consumed,
    );
  }
}

class MindmapBuilder extends MarkdownWidgetBuilder {
  const MindmapBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is MindmapNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final code = (node as MindmapNode).code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: MindmapDiagram(code: code),
    );
  }
}

// ── Mindmap Diagram Widget ───────────────────────────────────────────────

class MindmapDiagram extends StatelessWidget {
  final String code;
  const MindmapDiagram({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final tree = _parseMindmap(code);
    if (tree == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: context.palette.hairline),
        ),
        child: Text('无法解析 mindmap', style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          width: width,
          child: _MindmapTree(tree: tree, availableWidth: width),
        );
      },
    );
  }

  _MindmapNodeData? _parseMindmap(String source) {
    final lines = source.split('\n').map((l) => l.trimRight()).toList();
    if (lines.isEmpty) return null;

    var firstLine = lines.first.trim();
    if (!firstLine.startsWith('mindmap')) return null;

    final children = <_MindmapNodeData>[];
    _parseChildren(lines, 1, 0, children);
    if (children.isEmpty) return null;

    return _MindmapNodeData(
      text: '',
      children: children,
      isRoot: true,
    );
  }

  int _parseChildren(List<String> lines, int start, int parentIndent, List<_MindmapNodeData> out) {
    var i = start;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trimLeft().startsWith('%')) {
        i++;
        continue;
      }

      final indent = line.length - line.trimLeft().length;
      if (indent <= parentIndent && i > start) break;

      final content = line.trim();
      var text = content;

      if (text.startsWith('mindmap')) { i++; continue; }

      var shape = _MindmapShape.none;
      if (text.startsWith('[') && text.endsWith(']')) {
        shape = _MindmapShape.rounded;
        text = text.substring(1, text.length - 1);
      } else if (text.startsWith('((') && text.endsWith('))')) {
        shape = _MindmapShape.circle;
        text = text.substring(2, text.length - 2);
      } else if (text.startsWith('(') && text.endsWith(')')) {
        shape = _MindmapShape.bubble;
        text = text.substring(1, text.length - 1);
      } else if (text.startsWith('[') && text.endsWith(']')) {
        shape = _MindmapShape.rounded;
        text = text.substring(1, text.length - 1);
      }

      final children = <_MindmapNodeData>[];
      i = _parseChildren(lines, i + 1, indent, children);

      out.add(_MindmapNodeData(text: text, children: children, shape: shape));
    }
    return i;
  }
}

enum _MindmapShape { none, rounded, bubble, circle }

class _MindmapNodeData {
  final String text;
  final List<_MindmapNodeData> children;
  final _MindmapShape shape;
  final bool isRoot;

  _MindmapNodeData({
    required this.text,
    this.children = const [],
    this.shape = _MindmapShape.none,
    this.isRoot = false,
  });
}

class _MindmapTree extends StatelessWidget {
  final _MindmapNodeData tree;
  final double availableWidth;

  const _MindmapTree({required this.tree, required this.availableWidth});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (tree.isRoot && tree.children.isEmpty) {
      return const SizedBox.shrink();
    }

    if (tree.isRoot) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: tree.children.map((child) => _buildNode(context, child, isDark, 0)).toList(),
      );
    }

    return _buildNode(context, tree, isDark, 0);
  }

  Widget _buildNode(BuildContext context, _MindmapNodeData node, bool isDark, int depth) {
    final hasChildren = node.children.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : AppSpacing.lg + depth * 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.text.isNotEmpty)
            _MindmapNodeWidget(
              text: node.text,
              shape: node.shape,
              isDark: isDark,
              depth: depth,
            ),
          if (hasChildren)
            Padding(
              padding: EdgeInsets.only(
                left: node.text.isNotEmpty ? AppSpacing.sm : 0,
                top: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in node.children)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MindmapConnector(isDark: isDark),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: _buildNode(context, child, isDark, depth + 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MindmapNodeWidget extends StatelessWidget {
  final String text;
  final _MindmapShape shape;
  final bool isDark;
  final int depth;

  const _MindmapNodeWidget({
    required this.text,
    required this.shape,
    required this.isDark,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bgColor = isDark
        ? palette.card
        : Color.lerp(
            palette.canvas,
            AppColors.primary,
            depth == 0 ? 0.06 : 0.03,
          )!;
    final borderColor = depth == 0
        ? AppColors.primary.withOpacity(0.3)
        : palette.hairline;

    Widget label = Container(
      padding: EdgeInsets.symmetric(
        horizontal: shape == _MindmapShape.none ? 0 : AppSpacing.sm + 4,
        vertical: shape == _MindmapShape.none ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: shape == _MindmapShape.none
          ? null
          : BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(
                shape == _MindmapShape.circle ? 999 : AppRadii.sm,
              ),
              border: shape != _MindmapShape.bubble
                  ? Border.all(color: borderColor)
                  : null,
            ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w400,
          color: palette.ink,
          height: 1.3,
        ),
      ),
    );

    if (shape == _MindmapShape.circle) {
      label = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: label,
        ),
      );
    }

    return label;
  }
}

class _MindmapConnector extends StatelessWidget {
  final bool isDark;
  const _MindmapConnector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: 12,
        height: 1.5,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── Markdown Pre-processing ─────────────────────────────────────────────

String _preprocessMarkdown(String raw) {
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

// ── Scroll-safe Mermaid Builder ──────────────────────────────────────────

class ScrollSafeMermaidBuilder extends MarkdownWidgetBuilder {
  const ScrollSafeMermaidBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is MermaidDiagramNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    if (node is! MermaidDiagramNode) return const SizedBox.shrink();
    return _MermaidScrollBlocker(node: node, styleSheet: styleSheet);
  }
}

class _MermaidScrollBlocker extends StatefulWidget {
  final MermaidDiagramNode node;
  final MarkdownStyleSheet styleSheet;

  const _MermaidScrollBlocker({
    required this.node,
    required this.styleSheet,
  });

  @override
  State<_MermaidScrollBlocker> createState() => _MermaidScrollBlockerState();
}

class _MermaidScrollBlockerState extends State<_MermaidScrollBlocker> {
  static const _minScale = 0.5;
  static const _maxScale = 3.0;
  static const _scaleStep = 0.25;

  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _diagramKey = GlobalKey();
  double? _diagramHeight;
  double _scale = 1.0;

  MermaidStyle get _style {
    final bgColor = widget.styleSheet.codeBlockDecoration?.color;
    final isDark = bgColor != null && bgColor.computeLuminance() < 0.5;
    return isDark ? MermaidStyle.dark() : const MermaidStyle();
  }

  void _measureDiagram() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = _diagramKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && mounted) {
        final newHeight = renderBox.size.height;
        if (_diagramHeight != newHeight) {
          setState(() => _diagramHeight = newHeight);
        }
      }
    });
  }

  void _setScale(double value) {
    final nextScale = value.clamp(_minScale, _maxScale).toDouble();
    setState(() => _scale = nextScale);
    _transformCtrl.value = Matrix4.identity()..scale(nextScale);
  }

  void _syncScaleFromGesture() {
    final gestureScale = _transformCtrl.value.getMaxScaleOnAxis();
    setState(() {
      _scale = gestureScale.clamp(_minScale, _maxScale).toDouble();
    });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagram = MermaidDiagram(
      key: _diagramHeight == null ? _diagramKey : null,
      code: widget.node.code,
      style: _style,
    );

    if (_diagramHeight == null) {
      _measureDiagram();
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Color(_style.backgroundColor),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: diagram,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: _diagramHeight,
      decoration: BoxDecoration(
        color: Color(_style.backgroundColor),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                constrained: false,
                onInteractionEnd: (_) => _syncScaleFromGesture(),
                child: diagram,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: _MermaidZoomControls(
                canZoomOut: _scale > _minScale,
                canZoomIn: _scale < _maxScale,
                onZoomOut: () => _setScale(_scale - _scaleStep),
                onReset: () => _setScale(1.0),
                onZoomIn: () => _setScale(_scale + _scaleStep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MermaidZoomControls extends StatelessWidget {
  const _MermaidZoomControls({
    required this.canZoomOut,
    required this.canZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onZoomIn,
  });

  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MermaidZoomButton(
            icon: Icons.remove_rounded,
            tooltip: '缩小',
            onPressed: canZoomOut ? onZoomOut : null,
          ),
          _MermaidZoomButton(
            icon: Icons.center_focus_strong_rounded,
            tooltip: '重置',
            onPressed: onReset,
          ),
          _MermaidZoomButton(
            icon: Icons.add_rounded,
            tooltip: '放大',
            onPressed: canZoomIn ? onZoomIn : null,
          ),
          ],
        ),
      ),
    );
  }
}

class _MermaidZoomButton extends StatelessWidget {
  const _MermaidZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

// ── Markdown Viewer Widget ───────────────────────────────────────────────

class MarkdownViewer extends StatefulWidget {
  final File file;
  final double fontSize;
  final double lineHeight;
  final ReadingPalette readingPalette;
  final double horizontalPadding;
  final ScrollController? scrollController;
  final double topPadding;

  const MarkdownViewer({
    required this.file,
    required this.fontSize,
    required this.lineHeight,
    required this.readingPalette,
    required this.horizontalPadding,
    this.scrollController,
    this.topPadding = 0,
    super.key,
  });

  @override
  State<MarkdownViewer> createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> with WidgetsBindingObserver {
  String? _data;
  String? _error;
  DateTime? _lastModified;
  Map<String, String> _emojiMap = const {};
  Timer? _fileWatchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFile();
    EmojiService.load().then((map) {
      if (mounted) setState(() => _emojiMap = map);
    });
    _fileWatchTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkFileChanged(),
    );
  }

  @override
  void dispose() {
    _fileWatchTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkFileChanged();
    }
  }

  @override
  void didUpdateWidget(MarkdownViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight) {
      _loadFile();
    }
  }

  void _checkFileChanged() {
    try {
      if (!widget.file.existsSync()) return;
      final modified = widget.file.lastModifiedSync();
      if (_lastModified != null && modified.isAfter(_lastModified!)) {
        debugPrint('[MarkdownViewer] file changed, reloading (${widget.file.path})');
        _loadFile();
      }
    } catch (e) {
      debugPrint('[MarkdownViewer] checkFileChanged error: $e');
    }
  }

  Future<void> _loadFile() async {
    try {
      final raw = await widget.file.readAsString();
      if (mounted) {
        setState(() {
          _data = _preprocessMarkdown(raw);
          _error = null;
        });
      }
      _lastModified = await widget.file.lastModified();
    } catch (e) {
      if (mounted) {
        setState(() => _error = '读取 Markdown 失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    if (_data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final bodyStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: widget.readingPalette.foreground,
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      letterSpacing: 0,
    );

    final base = brightness == Brightness.dark
        ? MarkdownStyleSheet.dark()
        : MarkdownStyleSheet.light();

    final styleSheet = base.copyWith(
      textStyle: bodyStyle,
      h1Style: textTheme.headlineLarge?.copyWith(
        fontSize: widget.fontSize + 16,
        color: widget.readingPalette.foreground,
        letterSpacing: 0,
      ),
      h2Style: textTheme.headlineLarge?.copyWith(
        fontSize: widget.fontSize + 10,
        color: widget.readingPalette.foreground,
        letterSpacing: 0,
      ),
      h3Style: textTheme.titleLarge?.copyWith(
        fontSize: widget.fontSize + 5,
        color: widget.readingPalette.foreground,
        letterSpacing: 0,
      ),
      h4Style: textTheme.titleMedium?.copyWith(
        fontSize: widget.fontSize + 2,
        color: widget.readingPalette.foreground,
        letterSpacing: 0,
      ),
      h5Style: textTheme.titleMedium?.copyWith(
        color: widget.readingPalette.foreground,
        letterSpacing: 0,
      ),
      h6Style: textTheme.titleMedium?.copyWith(
        color: widget.readingPalette.muted,
        letterSpacing: 0,
      ),
      paragraphStyle: bodyStyle,
      blockquoteStyle: bodyStyle.copyWith(color: widget.readingPalette.muted),
      blockquoteDecoration: BoxDecoration(
        color: widget.readingPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(AppSpacing.md),
      inlineCodeStyle: TextStyle(
        color: widget.readingPalette.foreground,
        backgroundColor: widget.readingPalette.codeBackground,
        fontFamily: 'monospace',
        fontSize: 15,
        height: 1.45,
      ),
      codeBlockDecoration: BoxDecoration(
        color: widget.readingPalette.codeBackground,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: widget.readingPalette.border),
      ),
      codeBlockPadding: const EdgeInsets.all(AppSpacing.md),
      tableBorder: TableBorder.all(color: widget.readingPalette.border),
      tableHeaderDecoration: BoxDecoration(
        color: widget.readingPalette.surface,
      ),
      tableHeaderStyle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
        color: widget.readingPalette.foreground,
        fontWeight: FontWeight.w700,
      ),
      tableCellStyle: bodyStyle.copyWith(fontSize: 15),
      tableCellPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      horizontalRuleColor: widget.readingPalette.border,
      horizontalRuleThickness: 1,
      linkStyle: bodyStyle.copyWith(color: widget.readingPalette.link),
      listBulletStyle: bodyStyle,
    );

    final plugins = ParserPluginRegistry()
      ..registerInline(const UnderlinePlugin())
      ..registerInline(const HighlightPlugin())
      ..registerInline(const SuperscriptPlugin())
      ..registerInline(const SubscriptPlugin())
      ..registerInline(const BareUrlPlugin())
      ..registerInline(EmojiPlugin(customEmojis: _emojiMap.isNotEmpty ? _emojiMap : null))
      ..registerBlock(const IndentedOrderedListPlugin())
      ..registerBlock(const MermaidPlugin())
      ..registerBlock(const MindmapPlugin());

    final builders = BuilderRegistry()
      ..register('underline', const UnderlineBuilder())
      ..register('highlight', const HighlightBuilder())
      ..register('superscript', const SuperscriptBuilder())
      ..register('subscript', const SubscriptBuilder())
      ..register('table', const PerformanceTableBuilder())
      ..register('code_block', const SyntaxHighlightCodeBlockBuilder(
        showCopyButton: true,
        showLanguageTag: true,
      ))
      ..register('mermaid', const ScrollSafeMermaidBuilder())
      ..register('mindmap', const MindmapBuilder())
      ..register('indented_ordered_list', const IndentedOrderedListBuilder())
      ..register('link', const ClickableLinkBuilder())
      ..register('image', const TappableImageBuilder())
      ..register('emoji', const EmojiBuilder());

    return ColoredBox(
      color: widget.readingPalette.background,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding,
          widget.topPadding + AppSpacing.md,
          widget.horizontalPadding,
          AppSpacing.xxl + kBottomNavigationBarHeight,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        child: SmoothMarkdown(
          data: _data!,
          styleSheet: styleSheet,
          useEnhancedComponents: false,
          selectable: true,
          plugins: plugins,
          builderRegistry: builders,
          onTapLink: (url) => _handleLinkTap(context, url),
          onTapImage: (url, alt, title) =>
              _showImagePreview(context, url, alt, title),
        ),
      ),
    );
  }

  void _handleLinkTap(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打开链接'),
        content: SingleChildScrollView(
          child: Text(url, style: Theme.of(ctx).textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(
      BuildContext context, String url, String? alt, String? title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(alt ?? title ?? ''),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: _PreviewImage(url: url),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final isSvg = url.toLowerCase().endsWith('.svg');
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    if (isNetwork) {
      return _CachedMarkdownImage(url: url, isSvg: isSvg);
    }
    if (isSvg) {
      return SvgPicture.asset(url);
    }
    return Image.asset(
      url,
      errorBuilder: (ctx, error, stackTrace) =>
          const Icon(Icons.broken_image, color: Colors.white),
    );
  }
}
