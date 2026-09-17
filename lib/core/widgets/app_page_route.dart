import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Page transition styles. Pushes travel along the horizontal axis
/// ([SharedAxisTransition], matching the app's previous slide feel); pops
/// fade through. Root-level destinations can opt into a pure fade through
/// via [AppPageTransition.fadeThrough].
enum AppPageTransition { sharedAxis, fadeThrough }

PageRoute<T> appPageRoute<T>({
  required WidgetBuilder builder,
  AppPageTransition transition = AppPageTransition.sharedAxis,
}) {
  return AppPageRoute<T>(
    transition: transition,
    builder: (context) => _EdgeSwipeBackPage(child: builder(context)),
  );
}

/// A [MaterialPageRoute] with the app's signature motion: incoming pages
/// slide in along the horizontal axis ([SharedAxisTransition]) while outgoing
/// pages fade through. The custom left-edge swipe back gesture
/// ([_EdgeSwipeBackPage]) handles the return gesture; the system predictive
/// back peek animation is intentionally not used.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    this.transition = AppPageTransition.sharedAxis,
  });

  final AppPageTransition transition;

  @override
  Duration get transitionDuration => AppMotion.normal;

  @override
  Duration get reverseTransitionDuration => AppMotion.fast;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The route rebuilds this subtree on every animation frame, so the
    // status can be consulted to give pushes and pops distinct motion.
    if (animation.status == AnimationStatus.reverse ||
        transition == AppPageTransition.fadeThrough) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Colors.transparent,
        child: child,
      );
    }
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Colors.transparent,
      child: child,
    );
  }
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
