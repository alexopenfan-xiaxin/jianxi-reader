import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Feathered edges for a scroll view that runs underneath floating chrome.
///
/// The library and settings pages both scroll full-bleed behind a fixed glass
/// bar, so content used to end in a hard cut right at the bar's lower edge. A
/// plain two-colour gradient fixes the cut but bands on high-DPI panels, so the
/// ramp uses the seven non-linear stops the Claude chrome ships (sampled at
/// 15/30/45/60/75/87% with alphas 5.1/14.9/30.2/50.2/70.2/85.1%, i.e. roughly
/// `y = x^1.5`). Each band collapses to nothing at its scroll extreme, so a
/// list resting at the top keeps hard, crisp edges.
class ScrollEdgeFade extends StatefulWidget {
  const ScrollEdgeFade({
    super.key,
    required this.child,
    this.topInset = 0,
    this.topFade = 28,
    this.bottomFade = 0,
  });

  /// The scrollable to feather.
  final Widget child;

  /// Where the top ramp starts: the lower edge of the floating chrome. Content
  /// above this line is covered by the bar, so fading it out is invisible.
  final double topInset;

  /// Height of the ramp once content has scrolled under the chrome.
  final double topFade;

  /// Height of the bottom ramp; zero disables it.
  final double bottomFade;

  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  static const List<double> _alphas = <double>[
    0,
    0.051,
    0.149,
    0.302,
    0.502,
    0.702,
    0.851,
    1,
  ];

  static const List<double> _positions = <double>[
    0,
    0.15,
    0.30,
    0.45,
    0.60,
    0.75,
    0.87,
    1,
  ];

  double _topBand = 0;
  double _bottomBand = 0;

  @override
  Widget build(BuildContext context) {
    // The returned widget type must not change between rebuilds: swapping
    // `child` for `ShaderMask(child)` deactivates the whole scroll subtree and
    // drops the scroll offset. `_shader` paints an all-opaque mask at rest, so
    // keeping the mask mounted is free visually.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: _shader,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) =>
            _sync(notification.metrics, widget.topFade, widget.bottomFade),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _sync(notification.metrics, widget.topFade, widget.bottomFade),
          child: widget.child,
        ),
      ),
    );
  }

  /// Grows a band from zero at the edge to [size] once the content has scrolled
  /// [size] away, so the feather appears instead of popping in.
  static double _band(double distanceFromEdge, double size) {
    if (size <= 0 || distanceFromEdge <= 0) {
      return 0;
    }
    return math.min(distanceFromEdge, size);
  }

  bool _sync(ScrollMetrics metrics, double topFade, double bottomFade) {
    final top = _band(metrics.pixels, topFade);
    final bottom = _band(metrics.maxScrollExtent - metrics.pixels, bottomFade);
    if (top == _topBand && bottom == _bottomBand) {
      return false;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Metrics can be reported mid-layout; dirty the widget afterwards.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _topBand = top;
          _bottomBand = bottom;
        });
      });
      return false;
    }
    setState(() {
      _topBand = top;
      _bottomBand = bottom;
    });
    return false;
  }

  Shader _shader(Rect bounds) {
    final height = bounds.height;
    if (height <= 0) {
      return const LinearGradient(
        colors: <Color>[Colors.white, Colors.white],
      ).createShader(bounds);
    }

    final inset = widget.topInset.clamp(0.0, height).toDouble();
    final top = _topBand.clamp(0.0, math.max(0.0, height - inset)).toDouble();
    final bottom = _bottomBand
        .clamp(0.0, math.max(0.0, height - inset - top))
        .toDouble();

    final colors = <Color>[];
    final stops = <double>[];

    void add(double position, double alpha) {
      final stop = (position / height).clamp(0.0, 1.0).toDouble();
      colors.add(Colors.white.withValues(alpha: alpha));
      stops.add(stops.isEmpty ? stop : math.max(stop, stops.last));
    }

    if (top > 0) {
      add(0, 0);
      add(inset, 0);
      for (var i = 1; i < _alphas.length; i++) {
        add(inset + top * _positions[i], _alphas[i]);
      }
    } else {
      add(0, 1);
    }

    if (bottom > 0) {
      final start = height - bottom;
      for (var i = 1; i < _alphas.length; i++) {
        add(start + bottom * _positions[i], 1 - _alphas[i]);
      }
    } else {
      add(height, 1);
    }

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(bounds);
  }
}
