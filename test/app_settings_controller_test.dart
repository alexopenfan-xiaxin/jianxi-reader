import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/app_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses the curated liquid glass intensity default', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    await settings.load();

    expect(
      settings.liquidGlassIntensityValue,
      AppSettingsController.liquidGlassIntensityDefault,
    );
  });

  test('ignores legacy custom intensity preferences', () async {
    SharedPreferences.setMockInitialValues({
      'settings.liquidGlassIntensityMode': 'custom',
      'settings.liquidGlassIntensity': 0.3,
    });
    final settings = AppSettingsController();
    await settings.load();

    expect(
      settings.liquidGlassIntensityValue,
      AppSettingsController.liquidGlassIntensityDefault,
    );
  });
}