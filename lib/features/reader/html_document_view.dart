import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_settings_controller.dart';
import 'html_styler.dart';

class HtmlDocumentView extends StatefulWidget {
  const HtmlDocumentView({
    required this.file,
    required this.fontSize,
    required this.lineHeight,
    required this.readingPalette,
    required this.horizontalPadding,
    required this.initialScrollOffset,
    required this.onScrollOffsetChanged,
    this.topPadding = 0,
    super.key,
  });

  final File file;
  final double fontSize;
  final double lineHeight;
  final ReadingPalette readingPalette;
  final double horizontalPadding;
  final double initialScrollOffset;
  final ValueChanged<double> onScrollOffsetChanged;
  final double topPadding;

  @override
  State<HtmlDocumentView> createState() => _HtmlDocumentViewState();
}

class _HtmlDocumentViewState extends State<HtmlDocumentView> {
  late final WebViewController _controller;
  Timer? _scrollOffsetTimer;
  bool _isLoading = true;
  bool _hasRestoredScrollOffset = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(widget.readingPalette.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
              _restoreScrollOffset();
              _startScrollOffsetTimer();
            }
          },
        ),
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant HtmlDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.readingPalette != widget.readingPalette ||
        oldWidget.horizontalPadding != widget.horizontalPadding) {
      _hasRestoredScrollOffset = false;
      _controller.setBackgroundColor(widget.readingPalette.background);
      _loadHtml();
    }
  }

  @override
  void dispose() {
    _scrollOffsetTimer?.cancel();
    unawaited(_reportScrollOffset());
    super.dispose();
  }

  Future<void> _loadHtml() async {
    _scrollOffsetTimer?.cancel();
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final rawHtml = await widget.file.readAsString();
    final html = HtmlStyler.buildAssimilatedHtml(
      rawHtml,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      readingPalette: widget.readingPalette,
      horizontalPadding: widget.horizontalPadding,
      topPadding: widget.topPadding,
    );
    final baseUrl = widget.file.parent.uri.toString();
    if (!mounted) {
      return;
    }
    await _controller.loadHtmlString(html, baseUrl: baseUrl);
  }

  void _startScrollOffsetTimer() {
    _scrollOffsetTimer?.cancel();
    _scrollOffsetTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _reportScrollOffset(),
    );
  }

  Future<void> _restoreScrollOffset() async {
    if (_hasRestoredScrollOffset || widget.initialScrollOffset <= 0) {
      _hasRestoredScrollOffset = true;
      return;
    }
    try {
      await _controller.scrollTo(0, widget.initialScrollOffset.round());
      _hasRestoredScrollOffset = true;
    } catch (error) {
      debugPrint('[HtmlDocumentView] restore scroll offset failed: $error');
    }
  }

  Future<void> _reportScrollOffset() async {
    try {
      final position = await _controller.getScrollPosition();
      widget.onScrollOffsetChanged(position.dy);
    } catch (error) {
      debugPrint('[HtmlDocumentView] read scroll offset failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
