import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingScalePreset {
  const ReadingScalePreset({
    required this.label,
    required this.fontSize,
    required this.lineHeight,
  });

  final String label;
  final double fontSize;
  final double lineHeight;
}

enum ReadingTheme {
  defaultTheme('默认'),
  paper('纸张'),
  eyeCare('护眼');

  const ReadingTheme(this.label);

  final String label;
}

enum ReadingFontFamily {
  system('默认', null),
  wenkai('落霞孤鹜', 'LXGWWenKai');

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

enum AppFontFamily {
  system('默认', null),
  lxgw('落霞孤鹜', 'LXGWWenKai');

  const AppFontFamily(this.label, this.fontFamily);

  final String label;
  final String? fontFamily;
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
  static const readingFontSizeMin = 14.0;
  static const readingFontSizeMax = 28.0;
  static const readingFontSizeDefault = 18.0;
  static const readingLineHeightMin = 1.2;
  static const readingLineHeightMax = 2.0;
  static const readingLineHeightDefault = 1.58;
  static const readingScalePresets = <ReadingScalePreset>[
    ReadingScalePreset(label: '紧凑', fontSize: 16, lineHeight: 1.42),
    ReadingScalePreset(label: '标准', fontSize: 18, lineHeight: 1.58),
    ReadingScalePreset(label: '宽松', fontSize: 21, lineHeight: 1.74),
  ];

  static const _themeModeKey = 'settings.themeMode';
  static const _readingFontSizeKey = 'settings.readingFontSize';
  static const _readingLineHeightKey = 'settings.readingLineHeight';
  static const _readingThemeKey = 'settings.readingTheme';
  static const _readingMarginKey = 'settings.readingMargin';
  static const _libraryViewModeKey = 'settings.libraryViewMode';
  static const _visualModeKey = 'settings.visualMode';
  static const _readingFontFamilyKey = 'settings.readingFontFamily';
  static const _appFontFamilyKey = 'settings.appFontFamily';
  static const _predictiveBackEnabledKey = 'settings.predictiveBackEnabled';

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  double _readingFontSize = readingFontSizeDefault;
  double _readingLineHeight = readingLineHeightDefault;
  ReadingTheme _readingTheme = ReadingTheme.defaultTheme;
  ReadingMargin _readingMargin = ReadingMargin.comfortable;
  LibraryViewMode _libraryViewMode = LibraryViewMode.list;
  AppVisualMode _visualMode = AppVisualMode.classic;
  ReadingFontFamily _readingFontFamily = ReadingFontFamily.system;
  AppFontFamily _appFontFamily = AppFontFamily.system;
  bool _predictiveBackEnabled = false;

  ThemeMode get themeMode => _themeMode;

  double get readingFontSize => _readingFontSize;

  double get readingLineHeight => _readingLineHeight;

  ReadingTheme get readingTheme => _readingTheme;

  ReadingMargin get readingMargin => _readingMargin;

  LibraryViewMode get libraryViewMode => _libraryViewMode;

  AppVisualMode get visualMode => _visualMode;

  ReadingFontFamily get readingFontFamily => _readingFontFamily;

  String? get readingFontFamilyValue => _readingFontFamily.fontFamily;

  AppFontFamily get appFontFamily => _appFontFamily;

  String? get appFontFamilyValue => _appFontFamily.fontFamily;

  bool get predictiveBackEnabled => _predictiveBackEnabled;

  bool get liquidGlassEnabled => _visualMode == AppVisualMode.liquidGlass;

  double get readingFontSizeValue => _readingFontSize;

  double get readingLineHeightValue => _readingLineHeight;

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
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final preferences = _prefs!;
    _themeMode = _themeModeFromName(preferences.getString(_themeModeKey));
    _readingFontSize = _readingFontSizeFromStored(
      preferences.get(_readingFontSizeKey),
    );
    _readingLineHeight = _readingLineHeightFromStored(
      preferences.get(_readingLineHeightKey),
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
    _visualMode = _visualModeFromName(preferences.getString(_visualModeKey));
    _readingFontFamily = _readingFontFamilyFromName(
      preferences.getString(_readingFontFamilyKey),
    );
    _appFontFamily = _appFontFamilyFromName(
      preferences.getString(_appFontFamilyKey),
    );
    _predictiveBackEnabled =
        preferences.getBool(_predictiveBackEnabledKey) ?? false;
    notifyListeners();
  }

  Future<void> _persist(String key, String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(key, value);
  }

  Future<void> _persistDouble(String key, double value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble(key, value);
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }
    _themeMode = themeMode;
    notifyListeners();
    await _persist(_themeModeKey, themeMode.name);
  }

  Future<void> setReadingFontSize(double readingFontSize) async {
    final value = _normalizeFontSize(readingFontSize);
    if ((_readingFontSize - value).abs() < 0.01) {
      return;
    }
    _readingFontSize = value;
    notifyListeners();
    await _persistDouble(_readingFontSizeKey, value);
  }

  Future<void> setReadingLineHeight(double readingLineHeight) async {
    final value = _normalizeLineHeight(readingLineHeight);
    if ((_readingLineHeight - value).abs() < 0.001) {
      return;
    }
    _readingLineHeight = value;
    notifyListeners();
    await _persistDouble(_readingLineHeightKey, value);
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

  Future<void> resetReadingSettings() async {
    _readingTheme = ReadingTheme.defaultTheme;
    _readingMargin = ReadingMargin.comfortable;
    _readingFontSize = readingFontSizeDefault;
    _readingLineHeight = readingLineHeightDefault;
    _readingFontFamily = ReadingFontFamily.system;
    notifyListeners();
    await _persist(_readingThemeKey, _readingTheme.name);
    await _persist(_readingMarginKey, _readingMargin.name);
    await _persistDouble(_readingFontSizeKey, _readingFontSize);
    await _persistDouble(_readingLineHeightKey, _readingLineHeight);
    await _persist(_readingFontFamilyKey, _readingFontFamily.name);
  }

  Future<void> setAppFontFamily(AppFontFamily fontFamily) async {
    if (_appFontFamily == fontFamily) {
      return;
    }
    _appFontFamily = fontFamily;
    notifyListeners();
    await _persist(_appFontFamilyKey, fontFamily.name);
  }

  Future<void> setPredictiveBackEnabled(bool enabled) async {
    if (_predictiveBackEnabled == enabled) {
      return;
    }
    _predictiveBackEnabled = enabled;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_predictiveBackEnabledKey, enabled);
  }

  static ThemeMode _themeModeFromName(String? name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  static double _readingFontSizeFromStored(Object? value) {
    return _normalizeFontSize(switch (value) {
      double stored => stored,
      int stored => stored.toDouble(),
      String stored => double.tryParse(stored) ?? _legacyFontSize(stored),
      _ => readingFontSizeDefault,
    });
  }

  static double _readingLineHeightFromStored(Object? value) {
    return _normalizeLineHeight(switch (value) {
      double stored => stored,
      int stored => stored.toDouble(),
      String stored => double.tryParse(stored) ?? _legacyLineHeight(stored),
      _ => readingLineHeightDefault,
    });
  }

  static double _legacyFontSize(String name) {
    return switch (name) {
      'compact' => 16,
      'comfortable' => readingFontSizeDefault,
      'large' => 21,
      _ => readingFontSizeDefault,
    };
  }

  static double _legacyLineHeight(String name) {
    return switch (name) {
      'compact' => 1.42,
      'comfortable' => readingLineHeightDefault,
      'airy' => 1.74,
      _ => readingLineHeightDefault,
    };
  }

  static double _normalizeFontSize(double value) {
    if (value.isNaN || value.isInfinite) {
      return readingFontSizeDefault;
    }
    final clamped = value.clamp(readingFontSizeMin, readingFontSizeMax);
    return (clamped * 10).roundToDouble() / 10;
  }

  static double _normalizeLineHeight(double value) {
    if (value.isNaN || value.isInfinite) {
      return readingLineHeightDefault;
    }
    final clamped = value.clamp(readingLineHeightMin, readingLineHeightMax);
    return (clamped * 100).roundToDouble() / 100;
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

  static AppFontFamily _appFontFamilyFromName(String? name) {
    return AppFontFamily.values.firstWhere(
      (family) => family.name == name,
      orElse: () => AppFontFamily.system,
    );
  }
}
