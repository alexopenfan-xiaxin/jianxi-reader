import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: const [
          _SettingsHeader(),
          SizedBox(height: AppSpacing.lg),
          _AppearanceEntry(),
          SizedBox(height: AppSpacing.sm),
          _ReadingSettingsEntry(),
          SizedBox(height: AppSpacing.sm),
          _AboutEntry(),
        ],
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
          '阅读方式、显示偏好和应用信息集中管理。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: palette.muted,
                letterSpacing: 0,
              ),
        ),
      ],
    );
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
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppearancePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _AppearanceIcon extends StatelessWidget {
  const _AppearanceIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
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
    final settings = context.watch<AppSettingsController>();
    final palette = context.palette;
    final themeLabel = switch (settings.themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('外观', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$themeLabel · 首页${settings.libraryViewMode.label}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.muted,
                letterSpacing: 0,
              ),
        ),
      ],
    );
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
      appBar: AppBar(title: const Text('外观')),
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
                    icon: Icons.palette_outlined,
                    title: '界面主题',
                    subtitle: '跟随系统，或手动选择浅色/深色界面。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<ThemeMode>(
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
                  SegmentedButton<LibraryViewMode>(
                    segments: LibraryViewMode.values
                        .map(
                          (viewMode) => ButtonSegment(
                            value: viewMode,
                            label: Text(viewMode.label),
                          ),
                        )
                        .toList(),
                    selected: {settings.libraryViewMode},
                    onSelectionChanged: (selection) {
                      settings.setLibraryViewMode(selection.first);
                    },
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
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ReadingSettingsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _ReadingSettingsIcon extends StatelessWidget {
  const _ReadingSettingsIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.10),
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
    final settings = context.watch<AppSettingsController>();
    final palette = context.palette;
    final summary =
        '${settings.readingTheme.label} · ${settings.readingMargin.label}边距 · '
        '${settings.readingFontSize.label}字号 · ${settings.readingLineHeight.label}行距';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('阅读体验', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.muted,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }
}

class ReadingSettingsPage extends StatelessWidget {
  const ReadingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.parchment,
      appBar: AppBar(title: const Text('阅读体验')),
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
            color: AppColors.primary.withValues(alpha: 0.08),
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
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AboutPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _AboutIcon extends StatelessWidget {
  const _AboutIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
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
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('关于应用', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '应用信息、版本更新与联系信息',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.muted,
                letterSpacing: 0,
              ),
        ),
      ],
    );
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
      'https://alexxia.5imh.xyz/update/index.php?request&local=90';
  static const _apkContentType = 'application/vnd.android.package-archive';
  static final _communityUrl = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&svctype=5&tempid=h5_group_info&busi_data=eyJncm91cENvZGUiOiI0NjA3MTkyOTEifQ%253D%253D',
  );
  static final _repositoryUrl = Uri.parse(
    'https://github.com/alexopenfan-xiaxin/jianxi-reader',
  );

  bool _isChecking = false;
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
          builder: (ctx) => AlertDialog(
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
        if (confirmed == true) {
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
    if (Platform.isAndroid) {
      final canInstall =
          await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
              false;
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
        }
        return;
      }
    }
    await _channel.invokeMethod('installApk', {'path': filePath});
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
      appBar: AppBar(title: const Text('关于应用')),
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
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.12),
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isChecking ? null : _checkForUpdate,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_isChecking ? '检查中' : '检查更新'),
                    ),
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
