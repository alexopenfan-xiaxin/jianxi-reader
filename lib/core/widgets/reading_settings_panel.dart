import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';
import 'glass_segmented_control.dart';
import 'liquid_glass.dart';

class ReadingSettingsPanel extends StatefulWidget {
  final bool showPreview;

  const ReadingSettingsPanel({super.key, this.showPreview = false});

  @override
  State<ReadingSettingsPanel> createState() => _ReadingSettingsPanelState();
}

class _ReadingSettingsPanelState extends State<ReadingSettingsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: AppMotion.settle,
    );
    if (widget.showPreview) {
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggerItem(int index, Widget child) {
    if (!widget.showPreview) return child;
    final totalItems = 6;
    final delay = index / totalItems;
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: AppMotion.enter),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final palette = context.palette;
    final readingPalette = settings.readingPalette(
      defaultBackground: palette.parchment,
      defaultForeground: palette.ink,
      defaultMuted: palette.muted,
      defaultSurface: palette.card,
      defaultBorder: palette.hairline,
      defaultLink: AppColors.primary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showPreview) ...[
          _staggerItem(0, _ReadingPreviewPanel(
            settings: settings,
            readingPalette: readingPalette,
          )),
          const SizedBox(height: AppSpacing.lg),
        ],
        _staggerItem(widget.showPreview ? 1 : 0, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingLabel(text: '阅读主题'),
            const SizedBox(height: AppSpacing.sm),
            GlassSegmentedControl<ReadingTheme>(
              segments: ReadingTheme.values.map((theme) {
                return GlassSegment(
                  value: theme,
                  label: theme.label,
                  selectedIcon: Icons.check_rounded,
                );
              }).toList(),
              value: settings.readingTheme,
              onChanged: settings.setReadingTheme,
            ),
          ],
        )),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(widget.showPreview ? 2 : 1, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingLabel(text: '页边距'),
            const SizedBox(height: AppSpacing.sm),
            GlassSegmentedControl<ReadingMargin>(
              segments: ReadingMargin.values.map((margin) {
                return GlassSegment(
                  value: margin,
                  label: margin.label,
                  selectedIcon: Icons.check_rounded,
                );
              }).toList(),
              value: settings.readingMargin,
              onChanged: settings.setReadingMargin,
            ),
          ],
        )),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(widget.showPreview ? 3 : 2, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingLabel(text: '字号'),
            const SizedBox(height: AppSpacing.sm),
            GlassSegmentedControl<ReadingFontSize>(
              segments: ReadingFontSize.values.map((fontSize) {
                return GlassSegment(
                  value: fontSize,
                  label: fontSize.label,
                  selectedIcon: Icons.check_rounded,
                );
              }).toList(),
              value: settings.readingFontSize,
              onChanged: settings.setReadingFontSize,
            ),
          ],
        )),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(widget.showPreview ? 4 : 3, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingLabel(text: '行距'),
            const SizedBox(height: AppSpacing.sm),
            GlassSegmentedControl<ReadingLineHeight>(
              segments: ReadingLineHeight.values.map((lineHeight) {
                return GlassSegment(
                  value: lineHeight,
                  label: lineHeight.label,
                  selectedIcon: Icons.check_rounded,
                );
              }).toList(),
              value: settings.readingLineHeight,
              onChanged: settings.setReadingLineHeight,
            ),
          ],
        )),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(widget.showPreview ? 5 : 4, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingLabel(text: '字体'),
            const SizedBox(height: AppSpacing.sm),
            GlassSegmentedControl<ReadingFontFamily>(
              segments: ReadingFontFamily.values.map((family) {
                return GlassSegment(
                  value: family,
                  label: family.label,
                  selectedIcon: Icons.check_rounded,
                );
              }).toList(),
              value: settings.readingFontFamily,
              onChanged: settings.setReadingFontFamily,
            ),
          ],
        )),
      ],
    );
  }
}

class _ReadingPreviewPanel extends StatelessWidget {
  const _ReadingPreviewPanel({
    required this.settings,
    required this.readingPalette,
  });

  final AppSettingsController settings;
  final ReadingPalette readingPalette;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '简兮简兮，方将万舞。\n\n这是一段 Markdown 正文预览。\n可观察当前主题、字号、行距与页边距。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: settings.readingFontSizeValue,
                height: settings.readingLineHeightValue,
                fontFamily: settings.readingFontFamilyValue,
                color: readingPalette.foreground,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '预览仅影响阅读页，不改变原文件',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: readingPalette.muted,
                letterSpacing: 0,
              ),
        ),
      ],
    );

    if (settings.liquidGlassEnabled) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return LiquidGlassSurface(
        padding: EdgeInsets.symmetric(
          horizontal: settings.readingHorizontalPaddingValue,
          vertical: AppSpacing.md,
        ),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        color: readingPalette.background.withOpacity(0.42),
        borderColor:
            dark ? readingPalette.border.withOpacity(0.55) : Colors.transparent,
        chromaticEdge: dark,
        edgeHighlight: dark,
        innerHighlight: dark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.12 : 0.03),
            blurRadius: dark ? 22 : 12,
            offset: Offset(0, dark ? 10 : 5),
          ),
        ],
        child: content,
      );
    }

    return AnimatedContainer(
      duration: AppMotion.normal,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: settings.readingHorizontalPaddingValue,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: readingPalette.background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: readingPalette.border),
      ),
      child: content,
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}
