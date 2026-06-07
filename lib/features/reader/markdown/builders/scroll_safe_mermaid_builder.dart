import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../../../../core/design_tokens.dart';

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
    _transformCtrl.value = Matrix4.diagonal3Values(nextScale, nextScale, nextScale);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
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
          )
        ],
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
