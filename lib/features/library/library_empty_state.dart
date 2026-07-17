part of 'library_page.dart';

class _AnimatedStateShell extends StatelessWidget {
  const _AnimatedStateShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppMotion.normal,
      curve: AppMotion.enter,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LibraryStateIllustration(
            kind: _LibraryStateArtKind.warningPage,
            size: 42,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

enum _LibraryStateArtKind { emptyPage, searchPage, warningPage }

class _LibraryStateIllustration extends StatelessWidget {
  const _LibraryStateIllustration({required this.kind, this.size = 80});

  final _LibraryStateArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LibraryStateIllustrationPainter(
          kind: kind,
          primary: AppColors.primary,
          line: context.palette.ink,
          muted: context.palette.muted,
          error: AppColors.error,
        ),
      ),
    );
  }
}

class _LibraryStateIllustrationPainter extends CustomPainter {
  const _LibraryStateIllustrationPainter({
    required this.kind,
    required this.primary,
    required this.line,
    required this.muted,
    required this.error,
  });

  final _LibraryStateArtKind kind;
  final Color primary;
  final Color line;
  final Color muted;
  final Color error;

  @override
  void paint(Canvas canvas, Size size) {
    final pagePaint = Paint()
      ..color = primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = line.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = kind == _LibraryStateArtKind.warningPage ? error : primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.04
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.14,
        size.width * 0.50,
        size.height * 0.66,
      ),
      Radius.circular(size.shortestSide * 0.08),
    );
    canvas.drawRRect(page, pagePaint);
    canvas.drawRRect(page, linePaint);

    final foldPath = Path()
      ..moveTo(size.width * 0.59, size.height * 0.14)
      ..lineTo(size.width * 0.72, size.height * 0.27)
      ..lineTo(size.width * 0.59, size.height * 0.27)
      ..close();
    canvas.drawPath(foldPath, Paint()..color = primary.withValues(alpha: 0.12));
    canvas.drawPath(foldPath, linePaint);

    for (final y in [0.40, 0.52, 0.64]) {
      canvas.drawLine(
        Offset(size.width * 0.32, size.height * y),
        Offset(size.width * 0.62, size.height * y),
        linePaint..color = muted.withValues(alpha: 0.45),
      );
    }

    switch (kind) {
      case _LibraryStateArtKind.emptyPage:
        canvas.drawLine(
          Offset(size.width * 0.36, size.height * 0.86),
          Offset(size.width * 0.66, size.height * 0.86),
          accentPaint,
        );
      case _LibraryStateArtKind.searchPage:
        canvas.drawCircle(
          Offset(size.width * 0.70, size.height * 0.68),
          size.shortestSide * 0.13,
          accentPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.79, size.height * 0.77),
          Offset(size.width * 0.90, size.height * 0.88),
          accentPaint,
        );
      case _LibraryStateArtKind.warningPage:
        canvas.drawLine(
          Offset(size.width * 0.80, size.height * 0.56),
          Offset(size.width * 0.80, size.height * 0.70),
          accentPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.80, size.height * 0.78),
          size.shortestSide * 0.015,
          Paint()..color = error,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LibraryStateIllustrationPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.primary != primary ||
        oldDelegate.line != line ||
        oldDelegate.muted != muted ||
        oldDelegate.error != error;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      key: const ValueKey('empty_library'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LibraryStateIllustration(
              kind: _LibraryStateArtKind.emptyPage,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('未有简牍', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                '选择一个 Markdown 或 HTML 文档开始阅读',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: palette.muted,
                  height: 1.55,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                final controller = context.read<LibraryController>();
                _importFirstDocument(context, controller);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('导入文档'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFirstDocument(
    BuildContext context,
    LibraryController controller,
  ) async {
    await _importAndMaybeOpen(context, controller);
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LibraryStateIllustration(
              kind: _LibraryStateArtKind.searchPage,
              size: 72,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '未寻得匹配文档',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
