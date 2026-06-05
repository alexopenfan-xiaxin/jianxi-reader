import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingFontSize {
  compact('紧凑', 16),
  comfortable('标准', 18),
  large('大字', 21);

  const ReadingFontSize(this.label, this.value);

  final String label;
  final double value;
}

enum ReadingLineHeight {
  compact('紧凑', 1.42),
  comfortable('舒适', 1.58),
  airy('宽松', 1.74);

  const ReadingLineHeight(this.label, this.value);

  final String label;
  final double value;
}

enum ReadingTheme {
  defaultTheme('默认'),
  paper('纸张'),
  eyeCare('护眼');

  const ReadingTheme(this.label);

  final String label;
}

enum ReadingMargin {
  compact('紧凑', 16),
  comfortable('标准', 24),
  spacious('宽松', 32);

  const ReadingMargin(this.label, this.value);

  final String label;
  final double value;
}

class ReadingPalette {
  const ReadingPalette({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.surface,
    required this.border,
    required this.link,
    required this.codeBackground,
  });

  final Color background;
  final Color foreground;
  final Color muted;
  final Color surface;
  final Color border;
  final Color link;
  final Color codeBackground;

  @override
  bool operator ==(Object other) {
    return other is ReadingPalette &&
        other.background == background &&
        other.foreground == foreground &&
        other.muted == muted &&
        other.surface == surface &&
        other.border == border &&
        other.link == link &&
        other.codeBackground == codeBackground;
  }

  @override
  int get hashCode => Object.hash(
        background,
        foreground,
        muted,
        surface,
        border,
        link,
        codeBackground,
      );
}

class AppSettingsController extends ChangeNotifier {
  static const _themeModeKey = 'settings.themeMode';
  static const _readingFontSizeKey = 'settings.readingFontSize';
  static const _readingLineHeightKey = 'settings.readingLineHeight';
  static const _readingThemeKey = 'settings.readingTheme';
  static const _readingMarginKey = 'settings.readingMargin';

  ThemeMode _themeMode = ThemeMode.system;
  ReadingFontSize _readingFontSize = ReadingFontSize.comfortable;
  ReadingLineHeight _readingLineHeight = ReadingLineHeight.comfortable;
  ReadingTheme _readingTheme = ReadingTheme.defaultTheme;
  ReadingMargin _readingMargin = ReadingMargin.comfortable;

  ThemeMode get themeMode => _themeMode;

  ReadingFontSize get readingFontSize => _readingFontSize;

  ReadingLineHeight get readingLineHeight => _readingLineHeight;

  ReadingTheme get readingTheme => _readingTheme;

  ReadingMargin get readingMargin => _readingMargin;

  double get readingFontSizeValue => _readingFontSize.value;

  double get readingLineHeightValue => _readingLineHeight.value;

  double get readingHorizontalPaddingValue => _readingMargin.value;

  ReadingPalette readingPalette({
    required Color defaultBackground,
    required Color defaultForeground,
    required Color defaultMuted,
    required Color defaultSurface,
    required Color defaultBorder,
    required Color defaultLink,
  }) {
    switch (_readingTheme) {
      case ReadingTheme.defaultTheme:
        return ReadingPalette(
          background: defaultBackground,
          foreground: defaultForeground,
          muted: defaultMuted,
          surface: defaultSurface,
          border: defaultBorder,
          link: defaultLink,
          codeBackground: defaultSurface,
        );
      case ReadingTheme.paper:
        return const ReadingPalette(
          background: Color(0xFFF8F1E6),
          foreground: Color(0xFF4E3A2C),
          muted: Color(0xFF7C6756),
          surface: Color(0xFFFFFAF2),
          border: Color(0xFFE6D8C4),
          link: Color(0xFF0A65B7),
          codeBackground: Color(0xFFF0E2CF),
        );
      case ReadingTheme.eyeCare:
        return const ReadingPalette(
          background: Color(0xFFEFF6EE),
          foreground: Color(0xFF263B2E),
          muted: Color(0xFF5F7468),
          surface: Color(0xFFF7FBF6),
          border: Color(0xFFD5E4D7),
          link: Color(0xFF126C57),
          codeBackground: Color(0xFFE2EDE1),
        );
    }
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromName(preferences.getString(_themeModeKey));
    _readingFontSize = _readingFontSizeFromName(
      preferences.getString(_readingFontSizeKey),
    );
    _readingLineHeight = _readingLineHeightFromName(
      preferences.getString(_readingLineHeightKey),
    );
    _readingTheme = _readingThemeFromName(
      preferences.getString(_readingThemeKey),
    );
    _readingMargin = _readingMarginFromName(
      preferences.getString(_readingMarginKey),
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }
    _themeMode = themeMode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, themeMode.name);
  }

  Future<void> setReadingFontSize(ReadingFontSize readingFontSize) async {
    if (_readingFontSize == readingFontSize) {
      return;
    }
    _readingFontSize = readingFontSize;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readingFontSizeKey, readingFontSize.name);
  }

  Future<void> setReadingLineHeight(ReadingLineHeight readingLineHeight) async {
    if (_readingLineHeight == readingLineHeight) {
      return;
    }
    _readingLineHeight = readingLineHeight;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readingLineHeightKey, readingLineHeight.name);
  }

  Future<void> setReadingTheme(ReadingTheme readingTheme) async {
    if (_readingTheme == readingTheme) {
      return;
    }
    _readingTheme = readingTheme;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readingThemeKey, readingTheme.name);
  }

  Future<void> setReadingMargin(ReadingMargin readingMargin) async {
    if (_readingMargin == readingMargin) {
      return;
    }
    _readingMargin = readingMargin;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readingMarginKey, readingMargin.name);
  }

  static ThemeMode _themeModeFromName(String? name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  static ReadingFontSize _readingFontSizeFromName(String? name) {
    return ReadingFontSize.values.firstWhere(
      (fontSize) => fontSize.name == name,
      orElse: () => ReadingFontSize.comfortable,
    );
  }

  static ReadingLineHeight _readingLineHeightFromName(String? name) {
    return ReadingLineHeight.values.firstWhere(
      (lineHeight) => lineHeight.name == name,
      orElse: () => ReadingLineHeight.comfortable,
    );
  }

  static ReadingTheme _readingThemeFromName(String? name) {
    return ReadingTheme.values.firstWhere(
      (theme) => theme.name == name,
      orElse: () => ReadingTheme.defaultTheme,
    );
  }

  static ReadingMargin _readingMarginFromName(String? name) {
    return ReadingMargin.values.firstWhere(
      (margin) => margin.name == name,
      orElse: () => ReadingMargin.comfortable,
    );
  }
}
