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

class AppSettingsController extends ChangeNotifier {
  static const _themeModeKey = 'settings.themeMode';
  static const _readingFontSizeKey = 'settings.readingFontSize';
  static const _readingLineHeightKey = 'settings.readingLineHeight';

  ThemeMode _themeMode = ThemeMode.system;
  ReadingFontSize _readingFontSize = ReadingFontSize.comfortable;
  ReadingLineHeight _readingLineHeight = ReadingLineHeight.comfortable;

  ThemeMode get themeMode => _themeMode;

  ReadingFontSize get readingFontSize => _readingFontSize;

  ReadingLineHeight get readingLineHeight => _readingLineHeight;

  double get readingFontSizeValue => _readingFontSize.value;

  double get readingLineHeightValue => _readingLineHeight.value;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromName(preferences.getString(_themeModeKey));
    _readingFontSize = _readingFontSizeFromName(
      preferences.getString(_readingFontSizeKey),
    );
    _readingLineHeight = _readingLineHeightFromName(
      preferences.getString(_readingLineHeightKey),
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
}
