import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../../../core/app_settings_controller.dart';
import '../../../core/design_tokens.dart';

class MarkdownStyleFactory {
  const MarkdownStyleFactory._();

  static MarkdownStyleSheet build(
    BuildContext context, {
    required double fontSize,
    required double lineHeight,
    required ReadingPalette readingPalette,
    String? fontFamily,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final bodyStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: readingPalette.foreground,
      fontSize: fontSize,
      height: lineHeight,
      fontFamily: fontFamily,
      letterSpacing: 0,
    );

    final base = brightness == Brightness.dark
        ? MarkdownStyleSheet.dark()
        : MarkdownStyleSheet.light();

    return base.copyWith(
      textStyle: bodyStyle,
      h1Style: textTheme.headlineLarge?.copyWith(
        fontSize: fontSize + 16,
        color: readingPalette.foreground,
        fontFamily: fontFamily,
        letterSpacing: 0,
      ),
      h2Style: textTheme.headlineLarge?.copyWith(
        fontSize: fontSize + 10,
        color: readingPalette.foreground,
        fontFamily: fontFamily,
        letterSpacing: 0,
      ),
      h3Style: textTheme.titleLarge?.copyWith(
        fontSize: fontSize + 5,
        color: readingPalette.foreground,
        fontFamily: fontFamily,
        letterSpacing: 0,
      ),
      h4Style: textTheme.titleMedium?.copyWith(
        fontSize: fontSize + 2,
        color: readingPalette.foreground,
        fontFamily: fontFamily,
        letterSpacing: 0,
      ),
      h5Style: textTheme.titleMedium?.copyWith(
        color: readingPalette.foreground,
        fontFamily: fontFamily,
        letterSpacing: 0,
      ),
      h6Style: textTheme.titleMedium?.copyWith(
        color: readingPalette.muted,
        fontFamily: fontFamily,
        letterSpacing: 0,
      ),
      paragraphStyle: bodyStyle,
      blockquoteStyle: bodyStyle.copyWith(color: readingPalette.muted),
      blockquoteDecoration: BoxDecoration(
        color: readingPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(AppSpacing.md),
      inlineCodeStyle: TextStyle(
        color: readingPalette.foreground,
        backgroundColor: readingPalette.codeBackground,
        fontFamily: 'monospace',
        fontSize: 15,
        height: 1.45,
      ),
      codeBlockDecoration: BoxDecoration(
        color: readingPalette.codeBackground,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: readingPalette.border),
      ),
      codeBlockPadding: const EdgeInsets.all(AppSpacing.md),
      tableBorder: TableBorder.all(color: readingPalette.border),
      tableHeaderDecoration: BoxDecoration(color: readingPalette.surface),
      tableHeaderStyle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
        color: readingPalette.foreground,
        fontWeight: FontWeight.w700,
      ),
      tableCellStyle: bodyStyle.copyWith(fontSize: 15),
      tableCellPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      horizontalRuleColor: readingPalette.border,
      horizontalRuleThickness: 1,
      linkStyle: bodyStyle.copyWith(color: readingPalette.link),
      listBulletStyle: bodyStyle,
    );
  }
}
