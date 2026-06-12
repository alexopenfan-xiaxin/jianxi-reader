import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';

/// A smart scrollbar that detects fast scrolling and switches between
/// a subtle default style and a wider, draggable style.
///
/// For Flutter-native scrollables (e.g. Markdown [SingleChildScrollView]),
/// pass the [ScrollController] and leave [externalScrollSource] as `false`.
///
/// For non-Flutter scrollables (e.g. WebView HTML), set
/// [externalScrollSource] to `true`, pass a dummy [ScrollController], and
/// call [reportScroll] from the parent whenever a scroll event occurs.
class SmartScrollbar extends StatefulWidget {
  const SmartScrollbar({
    required this.controller,
    required this.readingPalette,
    required this.child,
    this.externalScrollSource = false,
    this.viewportRatio = 0.5,
    super.key,
  });

  final ScrollController controller;
  final ReadingPalette readingPalette;
  final Widget child;

  /// When `true`, scrollbar is drawn as a custom overlay and scroll
  /// events are reported via [reportScroll] instead of a [ScrollController].
  final bool externalScrollSource;

  /// Ratio of viewport height to total content height (0–1).
  /// Used to size the custom scrollbar thumb when [externalScrollSource]
  /// is `true`.
  final double viewportRatio;

  @override
  State<SmartScrollbar> createState() => SmartScrollbarState();
}

class SmartScrollbarState extends State<SmartScrollbar> {
  /// Speed threshold in pixels-per-second to qualify as "fast scroll".
  static const double _fastScrollThreshold = 2500.0;

  /// How long after the last fast-scroll / drag event before reverting.
  static const Duration _revertDelay = Duration(seconds: 3);

  bool _isFastScrolling = false;
  bool _isDraggingScrollbar = false;
  Timer? _revertTimer;

  double _lastOffset = 0;
  DateTime _lastEventTime = DateTime.now();

  /// Current scroll ratio for external scroll sources (0–1).
  double _scrollRatio = 0.0;

  // ── public API for external scroll sources ──────────────────────────

  /// Report a scroll event from an external source (e.g. WebView JS channel).
  /// [ratio] is the current scroll position as a fraction (0.0 – 1.0).
  void reportScroll(double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);

    // Compute estimated speed in px/s using layout height.
    final now = DateTime.now();
    final renderBox = context.findRenderObject() as RenderBox?;
    final layoutHeight = renderBox?.size.height ?? 600.0;
    final delta = (clamped - _scrollRatio).abs() * layoutHeight;
    final elapsed = now.difference(_lastEventTime).inMicroseconds;

    _scrollRatio = clamped;
    _lastEventTime = now;

    if (elapsed <= 0) return;
    final speed = delta / (elapsed / 1e6);
    if (speed > _fastScrollThreshold) {
      _enterFastMode();
    }
  }

  // ── lifecycle ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (!widget.externalScrollSource) {
      widget.controller.addListener(_onNativeScroll);
    }
  }

  @override
  void didUpdateWidget(covariant SmartScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        !widget.externalScrollSource) {
      oldWidget.controller.removeListener(_onNativeScroll);
      widget.controller.addListener(_onNativeScroll);
    }
  }

  @override
  void dispose() {
    if (!widget.externalScrollSource) {
      widget.controller.removeListener(_onNativeScroll);
    }
    _revertTimer?.cancel();
    super.dispose();
  }

  // ── native scroll handling (Markdown) ───────────────────────────────

  void _onNativeScroll() {
    if (_isDraggingScrollbar) return;
    if (!widget.controller.hasClients) return;

    final now = DateTime.now();
    final currentOffset = widget.controller.offset;
    final delta = (currentOffset - _lastOffset).abs();
    final elapsed = now.difference(_lastEventTime).inMicroseconds;

    _lastOffset = currentOffset;
    _lastEventTime = now;

    if (elapsed <= 0) return;
    final speed = delta / (elapsed / 1e6);
    if (speed > _fastScrollThreshold) {
      _enterFastMode();
    }
  }

  // ── fast-mode state machine ────────────────────────────────────────

  void _enterFastMode() {
    _revertTimer?.cancel();
    if (!_isFastScrolling && mounted) {
      setState(() => _isFastScrolling = true);
    }
    _revertTimer = Timer(_revertDelay, _revertToDefault);
  }

  void _revertToDefault() {
    if (_isDraggingScrollbar) return;
    if (_isFastScrolling && mounted) {
      setState(() => _isFastScrolling = false);
    }
  }

  void _onScrollbarDragStart() {
    _revertTimer?.cancel();
    _isDraggingScrollbar = true;
    if (!_isFastScrolling && mounted) {
      setState(() => _isFastScrolling = true);
    }
  }

  void _onScrollbarDragEnd() {
    _isDraggingScrollbar = false;
    _revertTimer?.cancel();
    _revertTimer = Timer(_revertDelay, _revertToDefault);
  }

  // ── build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.externalScrollSource) {
      return _buildExternal();
    }
    return _buildNative();
  }

  /// Native Flutter Scrollbar (for Markdown documents).
  Widget _buildNative() {
    final isDark = widget.readingPalette.background.computeLuminance() < 0.5;
    final thumbColor = widget.readingPalette.foreground.withOpacity(
      _isFastScrolling ? (isDark ? 0.55 : 0.45) : (isDark ? 0.28 : 0.22),
    );
    final trackColor = _isFastScrolling
        ? widget.readingPalette.border.withOpacity(isDark ? 0.18 : 0.12)
        : Colors.transparent;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll<bool>(_isFastScrolling),
        trackVisibility: WidgetStatePropertyAll<bool>(_isFastScrolling),
        thickness: WidgetStatePropertyAll<double>(
          _isFastScrolling ? 8.0 : 4.0,
        ),
        thumbColor: WidgetStatePropertyAll<Color?>(thumbColor),
        trackColor: WidgetStatePropertyAll<Color?>(trackColor),
        trackBorderColor: WidgetStatePropertyAll<Color?>(Colors.transparent),
        radius: const Radius.circular(4),
        crossAxisMargin: _isFastScrolling ? 2.0 : 0.0,
        mainAxisMargin: 0.0,
        minThumbLength: 40.0,
      ),
      child: Listener(
        onPointerDown: (event) {
          if (_isFastScrolling) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final width = renderBox.size.width;
              if (event.localPosition.dx > width - 16) {
                _onScrollbarDragStart();
              }
            }
          }
        },
        onPointerUp: (_) {
          if (_isDraggingScrollbar) _onScrollbarDragEnd();
        },
        onPointerCancel: (_) {
          if (_isDraggingScrollbar) _onScrollbarDragEnd();
        },
        child: Scrollbar(
          controller: widget.controller,
          interactive: _isFastScrolling,
          child: widget.child,
        ),
      ),
    );
  }

  /// Custom scrollbar overlay (for HTML WebView documents).
  Widget _buildExternal() {
    final isDark = widget.readingPalette.background.computeLuminance() < 0.5;
    final thumbColor = widget.readingPalette.foreground.withOpacity(
      _isFastScrolling ? (isDark ? 0.55 : 0.45) : (isDark ? 0.28 : 0.22),
    );
    final trackColor = _isFastScrolling
        ? widget.readingPalette.border.withOpacity(isDark ? 0.18 : 0.12)
        : Colors.transparent;
    final thumbWidth = _isFastScrolling ? 8.0 : 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewH = constraints.maxHeight;
        final vr = widget.viewportRatio.clamp(0.05, 1.0);
        final thumbH = math.max(40.0, viewH * vr);
        final maxTop = viewH - thumbH;
        final thumbTop = (_scrollRatio * maxTop).clamp(0.0, maxTop);

        return Stack(
          children: [
            // Content fills the entire area (WebView handles scrolling).
            Positioned.fill(child: widget.child),

            // Track (only visible in fast mode).
            if (_isFastScrolling)
              Positioned(
                top: 0,
                bottom: 0,
                right: 2,
                width: thumbWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // Thumb.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              top: thumbTop,
              right: 2,
              width: thumbWidth,
              height: thumbH,
              child: GestureDetector(
                onVerticalDragStart: (_) => _onScrollbarDragStart(),
                onVerticalDragEnd: (_) => _onScrollbarDragEnd(),
                onVerticalDragCancel: () {
                  if (_isDraggingScrollbar) _onScrollbarDragEnd();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
