import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/glass_segmented_control.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/reading_settings_panel.dart';

part 'appearance_settings.dart';
part 'about_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  82,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  _SettingsResponsiveCards(
                    wide: _isWideSettingsLayout(context, constraints),
                    children: const [
                      _AppearanceEntry(),
                      _ReadingSettingsEntry(),
                      _AboutEntry(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FixedSettingsHeader(),
          ),
        ],
      ),
    );
  }
}

class _FixedSettingsHeader extends StatelessWidget {
  const _FixedSettingsHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass = context.select<AppSettingsController, bool>(
        (s) => s.liquidGlassEnabled);
    final headerContent = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const _SettingsHomeIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '设置',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
          ),
          const _SettingsCompanionIcon(),
        ],
      ),
    );

    if (liquidGlass) {
      return LiquidGlassSurface(
        borderRadius: BorderRadius.circular(24),
        color: liquidGlassHeaderColor(context),
        borderColor: Colors.white.withOpacity(0.16),
        blurSigma: LiquidGlassTokens.effectBlurSigma,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(
              bottom: BorderSide(color: palette.hairline.withOpacity(0.20)),
            ),
          ),
          child: headerContent,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.parchment.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(color: palette.hairline.withOpacity(0.34)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: headerContent,
        ),
      ),
    );
  }
}

PreferredSizeWidget _settingsPageAppBar(BuildContext context, String title) {
  final palette = context.palette;
  final liquidGlass = context.select<AppSettingsController, bool>(
    (settings) => settings.liquidGlassEnabled,
  );
  if (liquidGlass) {
    return _LiquidSettingsAppBar(title: title);
  }
  return AppBar(
    title: Text(title),
    backgroundColor: palette.parchment,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}

class _LiquidSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _LiquidSettingsAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(24),
      color: liquidGlassHeaderColor(context),
      borderColor: Colors.white.withOpacity(0.16),
      blurSigma: LiquidGlassTokens.effectBlurSigma,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(
              bottom: BorderSide(color: palette.hairline.withOpacity(0.20)),
            ),
          ),
          child: SizedBox(
            height: kToolbarHeight,
            child: NavigationToolbar(
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
                color: palette.ink,
                onPressed: () => Navigator.maybePop(context),
              ),
              middle: Text(
                title,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
              centerMiddle: false,
              middleSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHomeIcon extends StatelessWidget {
  const _SettingsHomeIcon();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _SettingsHomeIconPainter(
          primary: AppColors.primary,
          line: palette.ink,
        ),
      ),
    );
  }
}

class _SettingsHomeIconPainter extends CustomPainter {
  const _SettingsHomeIconPainter({
    required this.primary,
    required this.line,
  });

  final Color primary;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final knobPaint = Paint()..color = primary.withOpacity(0.92);
    final trackPaint = Paint()
      ..color = line.withOpacity(0.58)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()..color = primary.withOpacity(0.15);

    final rows = <double>[0.34, 0.50, 0.66];
    final knobs = <double>[0.58, 0.42, 0.64];
    for (var index = 0; index < rows.length; index++) {
      final y = size.height * rows[index];
      canvas.drawLine(
        Offset(size.width * 0.30, y),
        Offset(size.width * 0.72, y),
        trackPaint,
      );
      final center = Offset(size.width * knobs[index], y);
      canvas.drawCircle(center, 5.8, glowPaint);
      canvas.drawCircle(center, 3.6, knobPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsHomeIconPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.line != line;
  }
}

class _SettingsCompanionIcon extends StatelessWidget {
  const _SettingsCompanionIcon();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _SettingsCompanionIconPainter(
          primary: AppColors.primary,
          line: palette.ink,
        ),
      ),
    );
  }
}

class _SettingsCompanionIconPainter extends CustomPainter {
  const _SettingsCompanionIconPainter({
    required this.primary,
    required this.line,
  });

  final Color primary;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = primary.withOpacity(0.10);
    final linePaint = Paint()
      ..color = line.withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = primary.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final headRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.53),
      width: size.width * 0.46,
      height: size.height * 0.38,
    );
    final headPath = Path()
      ..moveTo(size.width * 0.30, size.height * 0.45)
      ..lineTo(size.width * 0.35, size.height * 0.30)
      ..lineTo(size.width * 0.45, size.height * 0.42)
      ..lineTo(size.width * 0.55, size.height * 0.42)
      ..lineTo(size.width * 0.65, size.height * 0.30)
      ..lineTo(size.width * 0.70, size.height * 0.45)
      ..arcTo(headRect, -0.15, 3.44, false)
      ..close();
    canvas.drawPath(headPath, bodyPaint);
    canvas.drawPath(headPath, linePaint);

    canvas.drawCircle(
      Offset(size.width * 0.43, size.height * 0.53),
      1.8,
      Paint()..color = line.withOpacity(0.80),
    );
    canvas.drawCircle(
      Offset(size.width * 0.57, size.height * 0.53),
      1.8,
      Paint()..color = line.withOpacity(0.80),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.60),
        width: 9,
        height: 6,
      ),
      0.10,
      2.94,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SettingsCompanionIconPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.line != line;
  }
}

class _ReadingSettingsEntry extends StatelessWidget {
  const _ReadingSettingsEntry();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _openReadingSettingsPage(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          _ReadingSettingsIcon(),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _ReadingSettingsEntryText()),
          SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  void _openReadingSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      appPageRoute<void>(builder: (context) => const ReadingSettingsPage()),
    );
  }
}

class _ReadingSettingsIcon extends StatelessWidget {
  const _ReadingSettingsIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.10),
        ),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        size: 21,
        color: AppColors.primary,
      ),
    );
  }
}

class _ReadingSettingsEntryText extends StatelessWidget {
  const _ReadingSettingsEntryText();

  @override
  Widget build(BuildContext context) {
    return Text('阅读体验', style: Theme.of(context).textTheme.titleMedium);
  }
}

class ReadingSettingsPage extends StatelessWidget {
  const ReadingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.parchment,
      appBar: _settingsPageAppBar(context, '阅读体验'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _isWideSettingsLayout(context, constraints)
                        ? 900
                        : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '调整阅读主题、页边距、字号和行距，只影响文档阅读内容。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: palette.muted,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AppCard(
                        child: ReadingSettingsPanel(showPreview: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

bool _isWideSettingsLayout(BuildContext context, BoxConstraints constraints) {
  return MediaQuery.orientationOf(context) == Orientation.landscape &&
      constraints.maxWidth >= 640;
}

class _SettingsResponsiveCards extends StatelessWidget {
  const _SettingsResponsiveCards({
    required this.wide,
    required this.children,
  });

  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
