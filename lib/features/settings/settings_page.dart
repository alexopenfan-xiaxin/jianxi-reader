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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                82,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: const [
                _AppearanceEntry(),
                SizedBox(height: AppSpacing.sm),
                _ReadingSettingsEntry(),
                SizedBox(height: AppSpacing.sm),
                _AboutEntry(),
              ],
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
    final liquidGlass =
        context.watch<AppSettingsController>().liquidGlassEnabled;
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
  final settings = context.watch<AppSettingsController>();
  if (settings.liquidGlassEnabled) {
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

class _AppearanceEntry extends StatelessWidget {
  const _AppearanceEntry();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _openAppearancePage(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          _AppearanceIcon(),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _AppearanceEntryText()),
          SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  void _openAppearancePage(BuildContext context) {
    Navigator.of(context).push(
      appPageRoute<void>(builder: (context) => const AppearancePage()),
    );
  }
}

class _AppearanceIcon extends StatelessWidget {
  const _AppearanceIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.primary.withOpacity(0.10)),
      ),
      child: const Icon(
        Icons.palette_outlined,
        size: 21,
        color: AppColors.primary,
      ),
    );
  }
}

class _AppearanceEntryText extends StatelessWidget {
  const _AppearanceEntryText();

  @override
  Widget build(BuildContext context) {
    return Text('外观', style: Theme.of(context).textTheme.titleMedium);
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.parchment,
      appBar: _settingsPageAppBar(context, '外观'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.auto_awesome_rounded,
                    title: '视觉模式',
                    subtitle: '经典模式保持当前界面，液态玻璃模式启用玻璃拟态界面。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GlassSegmentedControl<AppVisualMode>(
                    segments: const [
                      GlassSegment(
                        value: AppVisualMode.classic,
                        label: '经典',
                        icon: Icons.layers_outlined,
                        selectedIcon: Icons.check_rounded,
                      ),
                      GlassSegment(
                        value: AppVisualMode.liquidGlass,
                        label: '液态玻璃',
                        icon: Icons.blur_on_rounded,
                        selectedIcon: Icons.check_rounded,
                      ),
                    ],
                    value: settings.visualMode,
                    onChanged: settings.setVisualMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.palette_outlined,
                    title: '界面主题',
                    subtitle: '跟随系统，或手动选择浅色/深色界面。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GlassSegmentedControl<ThemeMode>(
                    segments: const [
                      GlassSegment(
                        value: ThemeMode.system,
                        label: '系统',
                        icon: Icons.phone_android_rounded,
                        selectedIcon: Icons.check_rounded,
                      ),
                      GlassSegment(
                        value: ThemeMode.light,
                        label: '浅色',
                        icon: Icons.light_mode_rounded,
                        selectedIcon: Icons.check_rounded,
                      ),
                      GlassSegment(
                        value: ThemeMode.dark,
                        label: '深色',
                        icon: Icons.dark_mode_rounded,
                        selectedIcon: Icons.check_rounded,
                      ),
                    ],
                    value: settings.themeMode,
                    onChanged: settings.setThemeMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.grid_view_rounded,
                    title: '首页视图',
                    subtitle: '选择首页文档以列表或书架方式展示。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GlassSegmentedControl<LibraryViewMode>(
                    segments: LibraryViewMode.values.map((viewMode) {
                      return GlassSegment(
                        value: viewMode,
                        label: viewMode.label,
                        icon: viewMode == LibraryViewMode.list
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        selectedIcon: Icons.check_rounded,
                      );
                    }).toList(),
                    value: settings.libraryViewMode,
                    onChanged: settings.setLibraryViewMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
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

class _AboutEntry extends StatelessWidget {
  const _AboutEntry();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _openAboutPage(context),
      child: Row(
        children: const [
          _AboutIcon(),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _AboutEntryText()),
          SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  void _openAboutPage(BuildContext context) {
    Navigator.of(context).push(
      appPageRoute<void>(builder: (context) => const AboutPage()),
    );
  }
}

class _AboutIcon extends StatelessWidget {
  const _AboutIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.primary.withOpacity(0.10)),
      ),
      child: const Icon(
        Icons.info_outline_rounded,
        size: 21,
        color: AppColors.primary,
      ),
    );
  }
}

class _AboutEntryText extends StatelessWidget {
  const _AboutEntryText();

  @override
  Widget build(BuildContext context) {
    return Text('关于应用', style: Theme.of(context).textTheme.titleMedium);
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const _channel = MethodChannel('com.jianxi.reader/apk_install');
  static const _updateUrl =
      'https://alexxia.5imh.xyz/update/index.php?request&local=144';
  static const _apkContentType = 'application/vnd.android.package-archive';
  static final _communityUrl = Uri.parse(
    'https://qm.qq.com/q/IcQIMYOaQg',
  );
  static final _repositoryUrl = Uri.parse(
    'https://github.com/alexopenfan-xiaxin/jianxi-reader',
  );

  bool _isChecking = false;
  bool _isClearingCache = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _packageInfo = info);
      }
    }).catchError((_) {
      // Keep the about card usable if package metadata is unavailable.
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isChecking = true);
    final client = _createUpdateClient();
    try {
      final request = await client.getUrl(Uri.parse(_updateUrl));
      request.headers.set(
        HttpHeaders.acceptHeader,
        '$_apkContentType, application/json',
      );
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok && _isApkResponse(response)) {
        final newVersion = response.headers.value('x-apk-version');
        client.close(force: true);
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => LiquidGlassDialog(
            title: const Text('发现新版本'),
            content: Text(
              newVersion == null || newVersion.isEmpty
                  ? '有新版本可用，是否下载更新？'
                  : '发现构建版本 $newVersion，是否下载更新？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('更新'),
              ),
            ],
          ),
        );
        if (confirmed == true && await _ensureInstallPermission()) {
          await _downloadAndInstall();
        }
        return;
      }

      final message = await _readUpdateMessage(response);
      if (!mounted) return;
      if (response.statusCode == HttpStatus.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? '已是最新版本')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? '检查更新失败：${response.statusCode}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败：$error')),
        );
      }
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _downloadAndInstall() async {
    if (!mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/jianxi_reader.apk';
    final progress = ValueNotifier<double>(0.0);
    final client = _createUpdateClient();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LiquidGlassDialog(
        title: const Text('下载更新'),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (ctx, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 16),
                Text(
                  value >= 1.0 ? '下载完成' : '${(value * 100).toStringAsFixed(0)}%',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final request = await client.getUrl(Uri.parse(_updateUrl));
      request.headers.set(
        HttpHeaders.acceptHeader,
        '$_apkContentType, application/json',
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok || !_isApkResponse(response)) {
        final message = await _readUpdateMessage(response);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message ?? '没有可下载的新版本')),
          );
        }
        return;
      }

      final total = response.contentLength;
      final file = File(filePath);
      final sink = file.openWrite();
      var received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress.value = received / total;
        }
      }
      await sink.close();
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$error')),
        );
      }
      return;
    } finally {
      client.close(force: true);
      progress.dispose();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!mounted) return;
    await _channel.invokeMethod('installApk', {'path': filePath});
  }

  Future<bool> _ensureInstallPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final canInstall =
        await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
    if (canInstall) {
      return true;
    }

    if (!mounted) {
      return false;
    }
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => LiquidGlassDialog(
        title: const Text('安装权限'),
        content: const Text('安装更新需要开启「安装未知应用」权限。请先前往设置开启权限，再重新检查更新。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (open == true) {
      await _channel.invokeMethod('openInstallSettings');
    }
    return false;
  }

  Future<void> _clearCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      var clearedBytes = 0;
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        clearedBytes += await _deleteDirectoryContents(tempDir);
      }

      final documentsDir = await getApplicationDocumentsDirectory();
      final downloadedApk = File('${documentsDir.path}/jianxi_reader.apk');
      if (await downloadedApk.exists()) {
        clearedBytes += await downloadedApk.length();
        await downloadedApk.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理缓存：${_formatBytes(clearedBytes)}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理缓存失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<int> _deleteDirectoryContents(Directory directory) async {
    var deletedBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        final size = await entity.length();
        await entity.delete();
        deletedBytes += size;
      } else if (entity is Directory) {
        deletedBytes += await _directorySize(entity);
        await entity.delete(recursive: true);
      } else if (entity is Link) {
        await entity.delete();
      }
    }
    return deletedBytes;
  }

  Future<int> _directorySize(Directory directory) async {
    var size = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  HttpClient _createUpdateClient() {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    client.userAgent = 'JianxiReader/1.0';
    return client;
  }

  bool _isApkResponse(HttpClientResponse response) {
    final contentType = response.headers.value(HttpHeaders.contentTypeHeader);
    return contentType?.contains(_apkContentType) ?? false;
  }

  Future<String?> _readUpdateMessage(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    if (body.trim().isEmpty) return null;
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? data['error'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      return body;
    }
    return body;
  }

  Future<void> _openExternalLink(Uri uri, String failureMessage) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final versionLabel = _packageInfo == null
        ? '版本信息读取中'
        : '版本 ${_packageInfo!.version} (${_packageInfo!.buildNumber})';

    return Scaffold(
      backgroundColor: palette.parchment,
      appBar: _settingsPageAppBar(context, '关于应用'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.12),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: AppColors.primary,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '简兮阅读器',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              versionLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: palette.muted,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '为 Markdown 与 HTML 文档设计的本地阅读器，专注于安静的书库管理、稳定的原文件刷新和舒适的阅读显示。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: palette.ink,
                          height: 1.55,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AboutLink(
                    text: '点击加入QQ交流群',
                    onTap: () => _openExternalLink(
                      _communityUrl,
                      '无法打开 QQ 交流群链接',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _AboutLink(
                    text:
                        '开源地址：https://github.com/alexopenfan-xiaxin/jianxi-reader',
                    onTap: () => _openExternalLink(
                      _repositoryUrl,
                      '无法打开开源地址',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '联系作者：alex.openfan@gmail.com',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.muted,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardTitle(
                    icon: Icons.system_update_outlined,
                    title: '应用更新',
                    subtitle: _isChecking
                        ? '正在连接更新服务。'
                        : '检查是否有可下载的新版本。',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AboutActionButton(
                    busy: _isChecking,
                    icon: Icons.refresh_rounded,
                    label: '检查更新',
                    busyLabel: '检查中',
                    onPressed: _checkForUpdate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardTitle(
                    icon: Icons.cleaning_services_outlined,
                    title: '缓存清理',
                    subtitle: _isClearingCache
                        ? '正在清理临时缓存。'
                        : '清理临时图片缓存和已下载的更新包。',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AboutActionButton(
                    busy: _isClearingCache,
                    icon: Icons.delete_sweep_outlined,
                    label: '清理缓存',
                    busyLabel: '清理中',
                    onPressed: _clearCache,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutActionButton extends StatelessWidget {
  const _AboutActionButton({
    required this.busy,
    required this.icon,
    required this.label,
    required this.busyLabel,
    required this.onPressed,
  });

  final bool busy;
  final IconData icon;
  final String label;
  final String busyLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!liquidGlassEnabled(context)) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onPressed,
          icon: busy ? _ButtonProgressIcon(color: AppColors.primary) : Icon(icon),
          label: Text(busy ? busyLabel : label),
        ),
      );
    }

    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = busy ? palette.muted : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Opacity(
        opacity: busy ? 0.72 : 1,
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: liquidGlassContainerColor(context, alpha: dark ? 0 : 0.26),
          borderColor: dark
              ? LiquidGlassTokens.metalFxCyan.withOpacity(0.28)
              : AppColors.primary.withOpacity(0.24),
          blurSigma: LiquidGlassTokens.effectBlurSigma,
          boxShadow: [
            BoxShadow(
              color: dark
                  ? LiquidGlassTokens.metalFxCyan.withOpacity(0.09)
                  : AppColors.primary.withOpacity(0.10),
              blurRadius: 20,
              spreadRadius: dark ? -8 : 0,
              offset: const Offset(0, 8),
            ),
          ],
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              onTap: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              splashFactory: NoSplash.splashFactory,
              highlightColor: AppColors.primary.withOpacity(0.05),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    busy
                        ? _ButtonProgressIcon(color: foreground)
                        : Icon(icon, color: foreground, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      busy ? busyLabel : label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonProgressIcon extends StatelessWidget {
  const _ButtonProgressIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                letterSpacing: 0,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
        ),
      ),
    );
  }
}
