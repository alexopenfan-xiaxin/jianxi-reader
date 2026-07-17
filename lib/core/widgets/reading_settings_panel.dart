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
    final totalItems = 7;
    final delay = index / totalItems;
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(
        delay,
        (delay + 0.5).clamp(0.0, 1.0),
        curve: AppMotion.enter,
      ),
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
    final values = context
        .select<
          AppSettingsController,
          ({
            ReadingTheme readingTheme,
            ReadingMargin readingMargin,
            double readingFontSize,
            double readingLineHeight,
            ReadingFontFamily readingFontFamily,
            String? readingFontFamilyValue,
            bool liquidGlassEnabled,
            double readingHorizontalPadding,
          })
        >(
          (settings) => (
            readingTheme: settings.readingTheme,
            readingMargin: settings.readingMargin,
            readingFontSize: settings.readingFontSize,
            readingLineHeight: settings.readingLineHeight,
            readingFontFamily: settings.readingFontFamily,
            readingFontFamilyValue: settings.readingFontFamilyValue,
            liquidGlassEnabled: settings.liquidGlassEnabled,
            readingHorizontalPadding: settings.readingHorizontalPaddingValue,
          ),
        );
    final settings = context.read<AppSettingsController>();
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
          _staggerItem(
            0,
            _ReadingPreviewPanel(
              readingPalette: readingPalette,
              fontSize: values.readingFontSize,
              lineHeight: values.readingLineHeight,
              fontFamily: values.readingFontFamilyValue,
              horizontalPadding: values.readingHorizontalPadding,
              liquidGlassEnabled: values.liquidGlassEnabled,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _staggerItem(
          widget.showPreview ? 1 : 0,
          Column(
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
                value: values.readingTheme,
                onChanged: settings.setReadingTheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(
          widget.showPreview ? 2 : 1,
          Column(
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
                value: values.readingMargin,
                onChanged: settings.setReadingMargin,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(
          widget.showPreview ? 3 : 2,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingLabel(text: '字号'),
              const SizedBox(height: AppSpacing.sm),
              _ReadingValueSlider(
                value: values.readingFontSize,
                min: AppSettingsController.readingFontSizeMin,
                max: AppSettingsController.readingFontSizeMax,
                divisions: 28,
                valueLabel: '${values.readingFontSize.toStringAsFixed(1)} px',
                presets: AppSettingsController.readingScalePresets
                    .map(
                      (preset) => _ReadingSliderPreset(
                        label: preset.label,
                        value: preset.fontSize,
                      ),
                    )
                    .toList(),
                onChanged: settings.setReadingFontSize,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(
          widget.showPreview ? 4 : 3,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingLabel(text: '行距'),
              const SizedBox(height: AppSpacing.sm),
              _ReadingValueSlider(
                value: values.readingLineHeight,
                min: AppSettingsController.readingLineHeightMin,
                max: AppSettingsController.readingLineHeightMax,
                divisions: 40,
                valueLabel: values.readingLineHeight.toStringAsFixed(2),
                presets: AppSettingsController.readingScalePresets
                    .map(
                      (preset) => _ReadingSliderPreset(
                        label: preset.label,
                        value: preset.lineHeight,
                      ),
                    )
                    .toList(),
                onChanged: settings.setReadingLineHeight,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(
          widget.showPreview ? 5 : 4,
          Column(
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
                value: values.readingFontFamily,
                onChanged: settings.setReadingFontFamily,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _staggerItem(
          widget.showPreview ? 6 : 5,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: settings.resetReadingSettings,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('恢复默认阅读设置'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingPreviewPanel extends StatelessWidget {
  const _ReadingPreviewPanel({
    required this.readingPalette,
    required this.fontSize,
    required this.lineHeight,
    required this.horizontalPadding,
    required this.liquidGlassEnabled,
    this.fontFamily,
  });

  final ReadingPalette readingPalette;
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final bool liquidGlassEnabled;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '简兮简兮，方将万舞。\n\n这是一段 Markdown 正文预览。\n可观察当前主题、字号、行距与页边距。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: fontSize,
            height: lineHeight,
            fontFamily: fontFamily,
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

    if (liquidGlassEnabled) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return LiquidGlassSurface(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: AppSpacing.md,
        ),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        color: readingPalette.background.withValues(alpha: 0.42),
        borderColor: dark
            ? readingPalette.border.withValues(alpha: 0.55)
            : Colors.transparent,
        chromaticEdge: dark,
        edgeHighlight: dark,
        innerHighlight: dark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.03),
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
        horizontal: horizontalPadding,
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

class _ReadingSliderPreset {
  const _ReadingSliderPreset({required this.label, required this.value});

  final String label;
  final double value;
}

class _ReadingValueSlider extends StatelessWidget {
  const _ReadingValueSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.presets,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final List<_ReadingSliderPreset> presets;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                label: valueLabel,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 64,
              child: Text(
                valueLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: presets.map((preset) {
            final selected = (preset.value - value).abs() < 0.02;
            return ActionChip(
              label: Text(preset.label),
              avatar: selected
                  ? const Icon(Icons.check_rounded, size: 16)
                  : null,
              backgroundColor: selected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : palette.card.withValues(alpha: 0.72),
              side: BorderSide(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.28)
                    : palette.hairline,
              ),
              onPressed: () => onChanged(preset.value),
            );
          }).toList(),
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
