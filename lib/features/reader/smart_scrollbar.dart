import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';

/// A smart scrollbar that detects fast scrolling and switches between
/// a subtle default style and a wider, draggable style.
class SmartScrollbar extends StatefulWidget {
  const SmartScrollbar({
    required this.controller,
    required this.readingPalette,
    required this.child,
    super.key,
  });

  final ScrollController controller;
  final ReadingPalette readingPalette;
  final Widget child;

  @override
  State<SmartScrollbar> createState() => _SmartScrollbarState();
}

class _SmartScrollbarState extends State<SmartScrollbar> {
  /// Speed threshold in pixels-per-second to qualify as "fast scroll".
  static const double _fastScrollThreshold = 2500.0;

  /// How long after the last fast-scroll event before reverting to default.
  static const Duration _revertDelay = Duration(milliseconds: 800);

  bool _isFastScrolling = false;
  Timer? _revertTimer;

  double _lastOffset = 0;
  DateTime _lastEventTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant SmartScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _revertTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;

    final now = DateTime.now();
    final currentOffset = widget.controller.offset;
    final delta = (currentOffset - _lastOffset).abs();
    final elapsed = now.difference(_lastEventTime).inMicroseconds;

    _lastOffset = currentOffset;
    _lastEventTime = now;

    if (elapsed <= 0) return;

    final speed = delta / (elapsed / 1e6); // px/s

    if (speed > _fastScrollThreshold) {
      _revertTimer?.cancel();
      if (!_isFastScrolling && mounted) {
        setState(() => _isFastScrolling = true);
      }
      _revertTimer = Timer(_revertDelay, _revertToDefault);
    }
  }

  void _revertToDefault() {
    if (_isFastScrolling && mounted) {
      setState(() => _isFastScrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Scrollbar(
        controller: widget.controller,
        interactive: _isFastScrolling,
        child: widget.child,
      ),
    );
  }
}
