import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0066CC);
  static const primaryFocus = Color(0xFF0071E3);
  static const ink = Color(0xFF1D1D1F);
  static const inkMuted80 = Color(0xFF333333);
  // Was 0xFF7A7A7A: 4.29:1 on white and 3.94:1 on parchment, both below the
  // WCAG AA 4.5:1 floor for body text. 0xFF6B6B6B is 5.33:1 / 4.89:1.
  static const inkMuted48 = Color(0xFF6B6B6B);
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

/// Geometry of the floating page chrome.
///
/// Both the library and the settings page stack a fixed header on top of a
/// full-bleed scroll view. Before this existed those pages padded their lists
/// with a bare `82`, so changing the bar height (or the system text size) could
/// silently push the first card underneath the glass.
class AppChrome {
  static const double headerHeight = 72;

  /// Glass bar plus its top inset: where the header visually ends.
  static const double headerExtent = AppSpacing.xs + headerHeight;

  /// Where page content starts, leaving a breathing gap under the bar.
  static const double contentInset = headerExtent + AppSpacing.xxs;
}

/// Device-pixel-exact hairlines.
///
/// A 1.0 logical-pixel [BorderSide] covers three physical pixels on a 3x
/// screen, which is what made the chrome edges read as a grey haze. A real
/// hairline is one *physical* pixel: `1 / devicePixelRatio`, resolved once at
/// startup because a theme-level border cannot read `MediaQuery`.
class AppHairline {
  AppHairline._();

  static double _width = 1 / 3;

  /// Width in logical pixels that paints exactly one physical pixel.
  static double get width => _width;

  /// Called from `main()` before the first frame is built.
  static void configure(double devicePixelRatio) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      return;
    }
    _width = (1 / devicePixelRatio).clamp(0.25, 1.0).toDouble();
  }
}

class AppMotion {
  static const micro = Duration(milliseconds: 110);
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 320);
  static const settle = Duration(milliseconds: 420);

  static const press = Curves.easeOutCubic;
  static const release = Curves.easeOutBack;
  static const enter = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutCubic;
  static const standard = Curves.easeInOutCubic;
  static const exit = Curves.easeInCubic;
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
    canvas: Color(0xFF0A0A0C),
    parchment: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    ink: AppColors.bodyOnDark,
    muted: AppColors.darkMuted,
    hairline: Color(0xFF3A3A3C),
    dividerSoft: AppColors.tileDark2,
    navBackground: Color(0xFF000000),
    navForeground: AppColors.bodyOnDark,
    searchFill: Color(0xFF141416),
    inkMuted80: Color(0xFFCCCCCC),
    inkMuted48: Color(0xFF7A7A7A),
  );

  static ThemeData light({String? fontFamily}) {
    return _theme(Brightness.light, _lightPalette, fontFamily: fontFamily);
  }

  static ThemeData dark({String? fontFamily}) {
    return _theme(Brightness.dark, _darkPalette, fontFamily: fontFamily);
  }

  static ThemeData _theme(
    Brightness brightness,
    AppPalette palette, {
    String? fontFamily,
  }) {
    final resolvedFontFamily = fontFamily ?? AppTheme.fontFamily;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      surface: palette.card,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: resolvedFontFamily,
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
          fontFamily: resolvedFontFamily,
          fontSize: 17,
          fontWeight: _weight(FontWeight.w600, brightness),
          height: 1,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: palette.ink),
      ),
      textTheme: _textTheme(palette, resolvedFontFamily, brightness),
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
          ).copyWith(fontFamily: resolvedFontFamily),
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
          ).copyWith(fontFamily: resolvedFontFamily),
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
          borderSide: BorderSide(
            color: palette.hairline,
            width: AppHairline.width,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(
            color: palette.hairline,
            width: AppHairline.width,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.primaryFocus),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.navBackground,
        contentTextStyle: TextStyle(
          color: palette.navForeground,
          fontFamily: resolvedFontFamily,
        ),
      ),
    );
  }

  /// Light-on-dark glyphs bloom: the same w600 that looks crisp on `#FFFFFF`
  /// reads heavier on `#0A0A0C`. Dark mode therefore drops display and heading
  /// weights one step; body sizes stay untouched so CJK strokes keep their
  /// weight at small sizes.
  static FontWeight _weight(FontWeight base, Brightness brightness) {
    if (brightness == Brightness.light) {
      return base;
    }
    final index = base.index;
    if (index >= FontWeight.w600.index) {
      return FontWeight.values[index - 1];
    }
    return base;
  }

  static TextTheme _textTheme(
    AppPalette palette,
    String fontFamily,
    Brightness brightness,
  ) {
    FontWeight w(FontWeight base) => _weight(base, brightness);
    return TextTheme(
      displayLarge: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 40,
        fontWeight: w(FontWeight.w600),
        height: 1.10,
        letterSpacing: 0,
      ),
      headlineLarge: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 34,
        fontWeight: w(FontWeight.w600),
        height: 1.18,
        letterSpacing: -0.374,
      ),
      titleLarge: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 21,
        fontWeight: w(FontWeight.w600),
        height: 1.19,
        letterSpacing: 0.231,
      ),
      titleMedium: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: w(FontWeight.w600),
        height: 1.24,
        letterSpacing: -0.374,
      ),
      bodyLarge: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.47,
        letterSpacing: -0.374,
      ),
      bodyMedium: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: -0.224,
      ),
      labelLarge: TextStyle(
        color: palette.ink,
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: palette.muted,
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.29,
        letterSpacing: -0.224,
      ),
    );
  }
}
