part of 'settings_page.dart';

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
      'https://alexxia.5imh.xyz/update/index.php?request&local=161';
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
        setState(() => _isChecking = false);
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
