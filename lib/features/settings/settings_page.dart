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
import '../../core/widgets/glass_segmented_control.dart';
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
      'https://alexxia.5imh.xyz/update/index.php?request&local=103';
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isClearingCache ? null : _clearCache,
                      icon: _isClearingCache
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_sweep_outlined),
                      label: Text(_isClearingCache ? '清理中' : '清理缓存'),
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
