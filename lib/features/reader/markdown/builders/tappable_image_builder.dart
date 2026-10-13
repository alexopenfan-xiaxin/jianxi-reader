import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/design_tokens.dart';

class TappableImageBuilder extends MarkdownWidgetBuilder {
  const TappableImageBuilder({this.documentDirectory});

  final String? documentDirectory;

  @override
  bool canBuild(MarkdownNode node) => node is ImageNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final imageNode = node as ImageNode;
    final url = imageNode.url;
    final isNetwork = _isNetworkImageUrl(url);
    final isSvg = _isSvgUrl(url);
    final localPath = isNetwork
        ? null
        : _resolveLocalImagePath(url, documentDirectory);

    Widget imageWidget;
    if (isNetwork) {
      imageWidget = CachedMarkdownImage(url: url, isSvg: isSvg);
    } else if (_isDataImageUrl(url)) {
      imageWidget = _dataImageWidget(url);
    } else if (localPath != null && File(localPath).existsSync()) {
      imageWidget = isSvg
          ? SvgPicture.file(File(localPath))
          : Image.file(
              File(localPath),
              fit: BoxFit.contain,
              cacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              errorBuilder: (ctx, error, stackTrace) =>
                  const Icon(Icons.broken_image),
            );
    } else if (isSvg) {
      imageWidget = SvgPicture.asset(url);
    } else {
      imageWidget = Image.asset(
        url,
        errorBuilder: (ctx, error, stackTrace) =>
            const Icon(Icons.broken_image),
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
                  style: (styleSheet.paragraphStyle ?? const TextStyle())
                      .copyWith(fontSize: 12, color: AppColors.bodyMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _isNetworkImageUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool _isSvgUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase();
  return path != null && path.endsWith('.svg');
}

bool _isDataImageUrl(String url) {
  return url.trimLeft().toLowerCase().startsWith('data:image/');
}

String? _resolveLocalImagePath(String url, String? documentDirectory) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    if (uri.scheme == 'file') return uri.toFilePath();
    if (uri.scheme.isNotEmpty) return null;
  }
  final decoded = Uri.decodeComponent(trimmed);
  if (p.isAbsolute(decoded)) return p.normalize(decoded);
  if (documentDirectory == null || documentDirectory.isEmpty) return null;
  return p.normalize(p.join(documentDirectory, decoded));
}

Widget _dataImageWidget(String url) {
  try {
    final comma = url.indexOf(',');
    if (comma <= 0) throw const FormatException('invalid data image');
    final header = url.substring(5, comma).toLowerCase();
    if (!header.contains('base64')) {
      throw const FormatException('only base64 data images are supported');
    }
    return Image.memory(
      base64Decode(Uri.decodeComponent(url.substring(comma + 1))),
      fit: BoxFit.contain,
      errorBuilder: (ctx, error, stackTrace) =>
          const Icon(Icons.broken_image),
    );
  } catch (_) {
    return const Icon(Icons.broken_image);
  }
}

class CachedMarkdownImage extends StatefulWidget {
  const CachedMarkdownImage({
    required this.url,
    required this.isSvg,
    super.key,
  });

  final String url;
  final bool isSvg;

  @override
  State<CachedMarkdownImage> createState() => _CachedMarkdownImageState();
}

class _CachedMarkdownImageState extends State<CachedMarkdownImage> {
  static const _timeout = Duration(seconds: 15);
  static const _maxImageBytes = 25 * 1024 * 1024;
  static const _maxCacheBytes = 100 * 1024 * 1024;
  static final Map<String, Future<File>> _inFlight = {};

  Future<File>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedMarkdownImage oldWidget) {
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
          cacheWidth:
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
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

  Future<File> _loadImage({bool forceRefresh = false}) {
    if (!forceRefresh) {
      final existing = _inFlight[widget.url];
      if (existing != null) return existing;
    }
    final future = _loadImageUncached(forceRefresh: forceRefresh);
    if (!forceRefresh) {
      _inFlight[widget.url] = future;
      future.then<void>(
        (_) {
          if (identical(_inFlight[widget.url], future)) {
            _inFlight.remove(widget.url);
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(_inFlight[widget.url], future)) {
            _inFlight.remove(widget.url);
          }
        },
      );
    }
    return future;
  }

  Future<File> _loadImageUncached({required bool forceRefresh}) async {
    final file = await _cacheFileForUrl(widget.url, widget.isSvg);
    if (!forceRefresh && file.existsSync() && file.lengthSync() > 0) {
      await file.setLastModified(DateTime.now());
      return file;
    }
    return _downloadImage(file);
  }

  Future<File> _downloadImage(File destination) async {
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client
          .getUrl(Uri.parse(widget.url))
          .timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          '图片请求失败：${response.statusCode}',
          uri: Uri.parse(widget.url),
        );
      }
      if (response.contentLength > _maxImageBytes) {
        throw const FileSystemException('图片过大');
      }
      await destination.parent.create(recursive: true);
      sink = destination.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(_timeout)) {
        received += chunk.length;
        if (received > _maxImageBytes) {
          throw const FileSystemException('图片过大');
        }
        sink.add(chunk);
      }
      await sink.close();
      sink = null;
      if (received == 0) {
        throw const FileSystemException('图片内容为空');
      }
      await _pruneImageCache(destination.parent);
      return destination;
    } catch (_) {
      await sink?.close();
      if (destination.existsSync()) {
        await destination.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _pruneImageCache(Directory cacheDirectory) async {
    if (!cacheDirectory.existsSync()) {
      return;
    }
    final files = <_ImageCacheFile>[];
    var totalBytes = 0;
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final stat = await entity.stat();
      totalBytes += stat.size;
      files.add(_ImageCacheFile(file: entity, stat: stat));
    }
    if (totalBytes <= _maxCacheBytes) {
      return;
    }
    files.sort(
      (left, right) => left.stat.modified.compareTo(right.stat.modified),
    );
    for (final entry in files) {
      if (totalBytes <= _maxCacheBytes) {
        break;
      }
      totalBytes -= entry.stat.size;
      await entry.file.delete();
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

class MarkdownPreviewImage extends StatelessWidget {
  const MarkdownPreviewImage({
    required this.url,
    this.documentDirectory,
    super.key,
  });

  final String url;
  final String? documentDirectory;

  @override
  Widget build(BuildContext context) {
    final isSvg = _isSvgUrl(url);
    final isNetwork = _isNetworkImageUrl(url);
    if (isNetwork) {
      return CachedMarkdownImage(url: url, isSvg: isSvg);
    }
    if (_isDataImageUrl(url)) {
      return _dataImageWidget(url);
    }
    final localPath = _resolveLocalImagePath(url, documentDirectory);
    if (localPath != null && File(localPath).existsSync()) {
      return isSvg
          ? SvgPicture.file(File(localPath))
          : Image.file(
              File(localPath),
              fit: BoxFit.contain,
              cacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
            );
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

class _ImageCacheFile {
  const _ImageCacheFile({required this.file, required this.stat});

  final File file;
  final FileStat stat;
}
