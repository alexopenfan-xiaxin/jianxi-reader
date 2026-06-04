import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0066CC);
  static const primaryFocus = Color(0xFF0071E3);
  static const primaryOnDark = Color(0xFF2997FF);
  static const ink = Color(0xFF1D1D1F);
  static const inkMuted80 = Color(0xFF333333);
  static const inkMuted48 = Color(0xFF7A7A7A);
  static const bodyMuted = Color(0xFF7A7A7A);
  static const darkMuted = Color(0xFFCCCCCC);
  static const bodyOnDark = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFFFFFF);
  static const parchment = Color(0xFFF5F5F7);
  static const pearl = Color(0xFFFAFAFC);
  static const tileDark = Color(0xFF272729);
  static const tileDark2 = Color(0xFF2A2A2C);
  static const hairline = Color(0xFFE0E0E0);
  static const dividerSoft = Color(0xFFF0F0F0);

  // Semantic colors
  static const error = Color(0xFFFF3B30);
  static const warning = Color(0xFFFF9F0A);
  static const success = Color(0xFF34C759);

  // Reading mode
  static const sepiaBg = Color(0xFFF9F3E8);
  static const sepiaInk = Color(0xFF5B4636);

  // Badge colors
  static const htmlBadge = Color(0xFFE67E22);
}

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.parchment,
    required this.card,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.dividerSoft,
    required this.navBackground,
    required this.navForeground,
    required this.searchFill,
    required this.inkMuted80,
    required this.inkMuted48,
  });

  final Color canvas;
  final Color parchment;
  final Color card;
  final Color ink;
  final Color muted;
  final Color hairline;
  final Color dividerSoft;
  final Color navBackground;
  final Color navForeground;
  final Color searchFill;
  final Color inkMuted80;
  final Color inkMuted48;

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? parchment,
    Color? card,
    Color? ink,
    Color? muted,
    Color? hairline,
    Color? dividerSoft,
    Color? navBackground,
    Color? navForeground,
    Color? searchFill,
    Color? inkMuted80,
    Color? inkMuted48,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      parchment: parchment ?? this.parchment,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      hairline: hairline ?? this.hairline,
      dividerSoft: dividerSoft ?? this.dividerSoft,
      navBackground: navBackground ?? this.navBackground,
      navForeground: navForeground ?? this.navForeground,
      searchFill: searchFill ?? this.searchFill,
      inkMuted80: inkMuted80 ?? this.inkMuted80,
      inkMuted48: inkMuted48 ?? this.inkMuted48,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      parchment: Color.lerp(parchment, other.parchment, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      dividerSoft: Color.lerp(dividerSoft, other.dividerSoft, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navForeground: Color.lerp(navForeground, other.navForeground, t)!,
      searchFill: Color.lerp(searchFill, other.searchFill, t)!,
      inkMuted80: Color.lerp(inkMuted80, other.inkMuted80, t)!,
      inkMuted48: Color.lerp(inkMuted48, other.inkMuted48, t)!,
    );
  }
}

class AppRadii {
  static const sm = 8.0;
  static const md = 11.0;
  static const lg = 18.0;
  static const pill = 9999.0;
}

class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 17.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

extension AppThemeTokens on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

class AppTheme {
  static const fontFamily = 'Inter';

  static const _lightPalette = AppPalette(
    canvas: AppColors.canvas,
    parchment: AppColors.parchment,
    card: AppColors.canvas,
    ink: AppColors.ink,
    muted: AppColors.bodyMuted,
    hairline: AppColors.hairline,
    dividerSoft: AppColors.dividerSoft,
    navBackground: AppColors.tileDark,
    navForeground: AppColors.bodyOnDark,
    searchFill: AppColors.canvas,
    inkMuted80: AppColors.inkMuted80,
    inkMuted48: AppColors.inkMuted48,
  );

  static const _darkPalette = AppPalette(
    canvas: Color(0xFF111113),
    parchment: Color(0xFF000000),
    card: AppColors.tileDark,
    ink: AppColors.bodyOnDark,
    muted: AppColors.darkMuted,
    hairline: Color(0xFF3A3A3C),
    dividerSoft: AppColors.tileDark2,
    navBackground: Color(0xFF000000),
    navForeground: AppColors.bodyOnDark,
    searchFill: Color(0xFF1C1C1E),
    inkMuted80: Color(0xFFCCCCCC),
    inkMuted48: Color(0xFF7A7A7A),
  );

  static ThemeData light() {
    return _theme(Brightness.light, _lightPalette);
  }

  static ThemeData dark() {
    return _theme(Brightness.dark, _darkPalette);
  }

  static ThemeData _theme(Brightness brightness, AppPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      surface: palette.card,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.parchment,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        toolbarHeight: 52,
        backgroundColor: palette.parchment,
        foregroundColor: palette.ink,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: palette.ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: palette.ink),
      ),
      textTheme: _textTheme(palette),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.bodyOnDark,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: AppColors.primary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.searchFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(color: palette.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(color: palette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.primaryFocus),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.navBackground,
        contentTextStyle: TextStyle(color: palette.navForeground),
      ),
    );
  }

  static TextTheme _textTheme(AppPalette palette) {
    return TextTheme(
      displayLarge: TextStyle(
        color: palette.ink,
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.10,
        letterSpacing: 0,
      ),
      headlineLarge: TextStyle(
        color: palette.ink,
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: -0.374,
      ),
      titleLarge: TextStyle(
        color: palette.ink,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.19,
        letterSpacing: 0.231,
      ),
      titleMedium: TextStyle(
        color: palette.ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.24,
        letterSpacing: -0.374,
      ),
      bodyLarge: TextStyle(
        color: palette.ink,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.47,
        letterSpacing: -0.374,
      ),
      bodyMedium: TextStyle(
        color: palette.ink,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: -0.224,
      ),
      labelLarge: TextStyle(
        color: palette.ink,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: palette.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.29,
        letterSpacing: -0.224,
      ),
    );
  }
}
