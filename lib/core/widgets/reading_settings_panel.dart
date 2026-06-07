import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';
import 'glass_segmented_control.dart';

class ReadingSettingsPanel extends StatelessWidget {
  final bool showPreview;

  const ReadingSettingsPanel({super.key, this.showPreview = false});

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
        if (showPreview) ...[
          AnimatedContainer(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '简兮简兮，方将万舞。\n\n这是一段 Markdown 正文预览。\n可观察当前主题、字号、行距与页边距。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: settings.readingFontSizeValue,
                        height: settings.readingLineHeightValue,
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
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
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
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.lg),
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
