import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/reading_settings_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 112,
        ),
        children: const [
          _SettingsHeader(),
          SizedBox(height: AppSpacing.sm),
          _SectionLabel(text: '显示'),
          _ThemeSettingsCard(),
          SizedBox(height: AppSpacing.sm),
          _SectionLabel(text: '阅读'),
          _ReadingSettingsCard(),
          SizedBox(height: AppSpacing.lg),
          _AboutCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        bottom: AppSpacing.sm,
        top: AppSpacing.lg,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.palette.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('设置', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '阅读方式、显示偏好和应用信息。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: palette.muted,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ThemeSettingsCard extends StatelessWidget {
  const _ThemeSettingsCard();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.palette_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('外观', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: context.palette.hairline.withValues(alpha: 0.3)),
            ),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('系统'),
                  icon: Icon(Icons.phone_android_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) {
                settings.setThemeMode(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingSettingsCard extends StatelessWidget {
  const _ReadingSettingsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.text_fields_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('阅读', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ReadingSettingsPanel(showPreview: false),
        ],
      ),
    );
  }
}

class _AboutCard extends StatefulWidget {
  const _AboutCard();

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _isChecking = false;

  Future<void> _checkForUpdate() async {
    setState(() => _isChecking = true);
    try {
      final client = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      client.userAgent = 'JianxiReader/1.0';
      final request = await client.getUrl(
        Uri.parse('https://alexxia.5imh.xyz/update/?request&local=9'),
      );
      final response = await request.close();

      if (response.statusCode == HttpStatus.noContent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已是最新版本')),
          );
        }
      } else if (response.statusCode == HttpStatus.ok) {
        if (!mounted) return;
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('发现新版本'),
            content: const Text('有新版本可用，是否下载更新？'),
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
        if (confirmed == true) {
          await _downloadAndInstall();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败：${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败：$e')),
        );
      }
    } finally {
      setState(() => _isChecking = false);
    }
  }

  static const _channel = MethodChannel('com.jianxi.reader/apk_install');

  Future<void> _downloadAndInstall() async {
    if (!mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/jianxi_reader.apk';
    final progress = ValueNotifier<double>(0.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                  value >= 1.0
                      ? '下载完成'
                      : '${(value * 100).toStringAsFixed(0)}%',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final client = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      client.userAgent = 'JianxiReader/1.0';
      final request = await client.getUrl(
        Uri.parse('https://alexxia.5imh.xyz/update/?request&local=9'),
      );
      final response = await request.close();
      final total = response.contentLength ?? 0;
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
      client.close(force: true);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!mounted) return;
    if (Platform.isAndroid) {
      final canInstall = await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
      if (!canInstall) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('安装权限'),
            content: const Text('安装更新需要开启「安装未知应用」权限。是否前往设置？'),
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
          return;
        }
        return;
      }
    }
    await _channel.invokeMethod('installApk', {'path': filePath});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('关于应用', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('简兮阅读器', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '版本 1.1.2 (9)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      '支持 Markdown 与 HTML',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                        letterSpacing: 0,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isChecking ? null : _checkForUpdate,
              icon: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_outlined, size: 18),
              label: Text(_isChecking ? '检查中' : '检查更新'),
            ),
          ),
        ],
      ),
    );
  }
}
