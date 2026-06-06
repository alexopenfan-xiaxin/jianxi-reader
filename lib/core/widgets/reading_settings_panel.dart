import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings_controller.dart';
import '../design_tokens.dart';

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
            duration: const Duration(milliseconds: 200),
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
            child: Text(
              '简兮阅读器\n这是一段阅读预览文本，用来查看当前主题、字号、行距和页边距。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: settings.readingFontSizeValue,
                    height: settings.readingLineHeightValue,
                    color: readingPalette.foreground,
                    letterSpacing: 0,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _SettingLabel(text: '阅读主题'),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ReadingTheme>(
          segments: ReadingTheme.values
              .map(
                (theme) => ButtonSegment(
                  value: theme,
                  label: Text(theme.label),
                ),
              )
              .toList(),
          selected: {settings.readingTheme},
          onSelectionChanged: (selection) {
            settings.setReadingTheme(selection.first);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingLabel(text: '页边距'),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ReadingMargin>(
          segments: ReadingMargin.values
              .map(
                (margin) => ButtonSegment(
                  value: margin,
                  label: Text(margin.label),
                ),
              )
              .toList(),
          selected: {settings.readingMargin},
          onSelectionChanged: (selection) {
            settings.setReadingMargin(selection.first);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingLabel(text: '字号'),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ReadingFontSize>(
          segments: ReadingFontSize.values
              .map(
                (fontSize) => ButtonSegment(
                  value: fontSize,
                  label: Text(fontSize.label),
                ),
              )
              .toList(),
          selected: {settings.readingFontSize},
          onSelectionChanged: (selection) {
            settings.setReadingFontSize(selection.first);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingLabel(text: '行距'),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ReadingLineHeight>(
          segments: ReadingLineHeight.values
              .map(
                (lineHeight) => ButtonSegment(
                  value: lineHeight,
                  label: Text(lineHeight.label),
                ),
              )
              .toList(),
          selected: {settings.readingLineHeight},
          onSelectionChanged: (selection) {
            settings.setReadingLineHeight(selection.first);
          },
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
