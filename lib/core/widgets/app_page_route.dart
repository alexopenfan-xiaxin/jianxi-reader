import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';

PageRouteBuilder<T> appPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) {
      return _EdgeSwipeBackPage(child: builder(context));
    },
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final primary = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );
      final incomingOffset = Tween<Offset>(
        begin: const Offset(0.028, 0),
        end: Offset.zero,
      ).animate(primary);

      return FadeTransition(
        opacity: primary,
        child: SlideTransition(position: incomingOffset, child: child),
      );
    },
  );
}

class _EdgeSwipeBackPage extends StatefulWidget {
  const _EdgeSwipeBackPage({required this.child});

  final Widget child;

  @override
  State<_EdgeSwipeBackPage> createState() => _EdgeSwipeBackPageState();
}

class _EdgeSwipeBackPageState extends State<_EdgeSwipeBackPage> {
  static const _edgeWidth = 26.0;
  static const _dismissDistance = 92.0;
  double _dragOffset = 0;
  bool _tracking = false;

  void _handleDragStart(DragStartDetails details) {
    final canPop = Navigator.of(context).canPop();
    _tracking = canPop && details.localPosition.dx <= _edgeWidth;
    if (_tracking) {
      setState(() => _dragOffset = 0);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_tracking) {
      return;
    }
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 160.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_tracking) {
      return;
    }
    final shouldPop =
        _dragOffset >= _dismissDistance || (details.primaryVelocity ?? 0) > 420;
    _tracking = false;
    if (shouldPop) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  void _handleDragCancel() {
    if (!_tracking) {
      return;
    }
    _tracking = false;
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final predictiveBackEnabled = context.select<AppSettingsController, bool>(
      (settings) => settings.predictiveBackEnabled,
    );
    if (predictiveBackEnabled) {
      return PopScope(canPop: true, child: widget.child);
    }
    return PopScope(
      canPop: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: _tracking ? Duration.zero : AppMotion.fast,
            curve: AppMotion.release,
            transform: Matrix4.translationValues(_dragOffset * 0.18, 0, 0),
            child: widget.child,
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onHorizontalDragCancel: _handleDragCancel,
            ),
          ),
        ],
      ),
    );
  }
}
