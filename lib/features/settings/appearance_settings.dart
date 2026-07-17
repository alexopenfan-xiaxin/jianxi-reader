part of 'settings_page.dart';

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
    Navigator.of(
      context,
    ).push(appPageRoute<void>(builder: (context) => const AppearancePage()));
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
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
    return Text('外观与动画', style: Theme.of(context).textTheme.titleMedium);
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final values = context
        .select<
          AppSettingsController,
          ({
            AppVisualMode visualMode,
            AppFontFamily appFontFamily,
            ThemeMode themeMode,
            LibraryViewMode libraryViewMode,
            bool predictiveBackEnabled,
          })
        >(
          (settings) => (
            visualMode: settings.visualMode,
            appFontFamily: settings.appFontFamily,
            themeMode: settings.themeMode,
            libraryViewMode: settings.libraryViewMode,
            predictiveBackEnabled: settings.predictiveBackEnabled,
          ),
        );
    final settings = context.read<AppSettingsController>();
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.parchment,
      appBar: _settingsPageAppBar(context, '外观与动画'),
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
              _SettingsResponsiveCards(
                wide: _isWideSettingsLayout(context, constraints),
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
                          value: values.visualMode,
                          onChanged: settings.setVisualMode,
                        ),
                      ],
                    ),
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardTitle(
                          icon: Icons.text_fields_rounded,
                          title: '应用字体',
                          subtitle: '选择整个应用界面的字体。',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GlassSegmentedControl<AppFontFamily>(
                          segments: AppFontFamily.values.map((family) {
                            return GlassSegment(
                              value: family,
                              label: family.label,
                              icon: family == AppFontFamily.system
                                  ? Icons.font_download_outlined
                                  : Icons.auto_stories_outlined,
                              selectedIcon: Icons.check_rounded,
                            );
                          }).toList(),
                          value: values.appFontFamily,
                          onChanged: settings.setAppFontFamily,
                        ),
                      ],
                    ),
                  ),
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
                          value: values.themeMode,
                          onChanged: settings.setThemeMode,
                        ),
                      ],
                    ),
                  ),
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
                          value: values.libraryViewMode,
                          onChanged: settings.setLibraryViewMode,
                        ),
                      ],
                    ),
                  ),
                  AppCard(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: values.predictiveBackEnabled,
                      onChanged: settings.setPredictiveBackEnabled,
                      secondary: const Icon(Icons.swipe_rounded),
                      title: const Text('预测性返回手势'),
                      subtitle: const Text(
                        'Android 13 及以上使用系统预测返回；关闭后保留应用左侧边缘返回。',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
