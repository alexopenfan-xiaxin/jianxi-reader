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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPreview) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: palette.hairline),
            ),
            child: Text(
              '简兮阅读器\n这是一段阅读预览文本，展示了当前的字体大小和行距效果。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: settings.readingFontSizeValue,
                height: settings.readingLineHeightValue,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('字号', style: Theme.of(context).textTheme.titleMedium),
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
        Text('行距', style: Theme.of(context).textTheme.titleMedium),
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
