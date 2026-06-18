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
  comfortable('标准', 1.58),
  airy('宽松', 1.74);

  const ReadingLineHeight(this.label, this.value);

  final String label;
  final double value;
}

enum ReadingTheme {
  defaultTheme('默认'),
  paper('纸张'),
  eyeCare('护眼'),
  night('夜览');

  const ReadingTheme(this.label);

  final String label;
}

enum ReadingFontFamily {
  system('默认', null),
  wenkai('文楷', 'LXGWWenKai');

  const ReadingFontFamily(this.label, this.fontFamily);

  final String label;
  final String? fontFamily;
}

enum ReadingMargin {
  compact('紧凑', 16),
  comfortable('标准', 24),
  spacious('宽松', 32);

  const ReadingMargin(this.label, this.value);

  final String label;
  final double value;
}

enum LibraryViewMode {
  list('列表'),
  shelf('书架');

  const LibraryViewMode(this.label);

  final String label;
}

enum AppVisualMode {
  classic('经典'),
  liquidGlass('液态玻璃');

  const AppVisualMode(this.label);

  final String label;
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
  static const _libraryViewModeKey = 'settings.libraryViewMode';
  static const _visualModeKey = 'settings.visualMode';
  static const _readingFontFamilyKey = 'settings.readingFontFamily';

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  ReadingFontSize _readingFontSize = ReadingFontSize.comfortable;
  ReadingLineHeight _readingLineHeight = ReadingLineHeight.comfortable;
  ReadingTheme _readingTheme = ReadingTheme.defaultTheme;
  ReadingMargin _readingMargin = ReadingMargin.comfortable;
  LibraryViewMode _libraryViewMode = LibraryViewMode.list;
  AppVisualMode _visualMode = AppVisualMode.classic;
  ReadingFontFamily _readingFontFamily = ReadingFontFamily.system;

  ThemeMode get themeMode => _themeMode;

  ReadingFontSize get readingFontSize => _readingFontSize;

  ReadingLineHeight get readingLineHeight => _readingLineHeight;

  ReadingTheme get readingTheme => _readingTheme;

  ReadingMargin get readingMargin => _readingMargin;

  LibraryViewMode get libraryViewMode => _libraryViewMode;

  AppVisualMode get visualMode => _visualMode;

  ReadingFontFamily get readingFontFamily => _readingFontFamily;

  String? get readingFontFamilyValue => _readingFontFamily.fontFamily;

  bool get liquidGlassEnabled => _visualMode == AppVisualMode.liquidGlass;

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
    final useDarkReadingVariant = defaultBackground.computeLuminance() < 0.5;
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
        if (useDarkReadingVariant) {
          return const ReadingPalette(
            background: Color(0xFF211A14),
            foreground: Color(0xFFEAD8C3),
            muted: Color(0xFFC2A88F),
            surface: Color(0xFF2B2118),
            border: Color(0xFF4A3828),
            link: Color(0xFF8CC8FF),
            codeBackground: Color(0xFF322619),
          );
        }
        return const ReadingPalette(
          background: Color(0xFFF8F1E6),
          foreground: Color(0xFF4E3A2C),
          muted: Color(0xFF7C6756),
          surface: Color(0xFFFFFAF2),
          border: Color(0xFFE6D8C4),
          link: Color(0xFF075FA8),
          codeBackground: Color(0xFFF0E2CF),
        );
      case ReadingTheme.eyeCare:
        if (useDarkReadingVariant) {
          return const ReadingPalette(
            background: Color(0xFF14211A),
            foreground: Color(0xFFDDEBDD),
            muted: Color(0xFFA8BDAF),
            surface: Color(0xFF1B2B22),
            border: Color(0xFF33483B),
            link: Color(0xFF8EE3C0),
            codeBackground: Color(0xFF203529),
          );
        }
        return const ReadingPalette(
          background: Color(0xFFEFF6EE),
          foreground: Color(0xFF263B2E),
          muted: Color(0xFF5F7468),
          surface: Color(0xFFF7FBF6),
          border: Color(0xFFD5E4D7),
          link: Color(0xFF0E6D55),
          codeBackground: Color(0xFFE2EDE1),
        );
      case ReadingTheme.night:
        return const ReadingPalette(
          background: Color(0xFF000000),
          foreground: Color(0xFFB0A89A),
          muted: Color(0xFF706860),
          surface: Color(0xFF0A0A0A),
          border: Color(0xFF1A1A1A),
          link: Color(0xFFCC9955),
          codeBackground: Color(0xFF0D0D0D),
        );
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final preferences = _prefs!;
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
    _libraryViewMode = _libraryViewModeFromName(
      preferences.getString(_libraryViewModeKey),
    );
    _visualMode = _visualModeFromName(
      preferences.getString(_visualModeKey),
    );
    _readingFontFamily = _readingFontFamilyFromName(
      preferences.getString(_readingFontFamilyKey),
    );
    notifyListeners();
  }

  Future<void> _persist(String key, String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(key, value);
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }
    _themeMode = themeMode;
    notifyListeners();
    await _persist(_themeModeKey, themeMode.name);
  }

  Future<void> setReadingFontSize(ReadingFontSize readingFontSize) async {
    if (_readingFontSize == readingFontSize) {
      return;
    }
    _readingFontSize = readingFontSize;
    notifyListeners();
    await _persist(_readingFontSizeKey, readingFontSize.name);
  }

  Future<void> setReadingLineHeight(ReadingLineHeight readingLineHeight) async {
    if (_readingLineHeight == readingLineHeight) {
      return;
    }
    _readingLineHeight = readingLineHeight;
    notifyListeners();
    await _persist(_readingLineHeightKey, readingLineHeight.name);
  }

  Future<void> setReadingTheme(ReadingTheme readingTheme) async {
    if (_readingTheme == readingTheme) {
      return;
    }
    _readingTheme = readingTheme;
    notifyListeners();
    await _persist(_readingThemeKey, readingTheme.name);
  }

  Future<void> setReadingMargin(ReadingMargin readingMargin) async {
    if (_readingMargin == readingMargin) {
      return;
    }
    _readingMargin = readingMargin;
    notifyListeners();
    await _persist(_readingMarginKey, readingMargin.name);
  }

  Future<void> setLibraryViewMode(LibraryViewMode libraryViewMode) async {
    if (_libraryViewMode == libraryViewMode) {
      return;
    }
    _libraryViewMode = libraryViewMode;
    notifyListeners();
    await _persist(_libraryViewModeKey, libraryViewMode.name);
  }

  Future<void> setVisualMode(AppVisualMode visualMode) async {
    if (_visualMode == visualMode) {
      return;
    }
    _visualMode = visualMode;
    notifyListeners();
    await _persist(_visualModeKey, visualMode.name);
  }

  Future<void> setReadingFontFamily(ReadingFontFamily fontFamily) async {
    if (_readingFontFamily == fontFamily) {
      return;
    }
    _readingFontFamily = fontFamily;
    notifyListeners();
    await _persist(_readingFontFamilyKey, fontFamily.name);
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

  static LibraryViewMode _libraryViewModeFromName(String? name) {
    return LibraryViewMode.values.firstWhere(
      (viewMode) => viewMode.name == name,
      orElse: () => LibraryViewMode.list,
    );
  }

  static AppVisualMode _visualModeFromName(String? name) {
    return AppVisualMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => AppVisualMode.classic,
    );
  }

  static ReadingFontFamily _readingFontFamilyFromName(String? name) {
    return ReadingFontFamily.values.firstWhere(
      (family) => family.name == name,
      orElse: () => ReadingFontFamily.system,
    );
  }
}
