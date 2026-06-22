import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/app_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists predictive back preference', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    await settings.load();

    expect(settings.predictiveBackEnabled, isFalse);

    await settings.setPredictiveBackEnabled(true);
    final restored = AppSettingsController();
    await restored.load();

    expect(restored.predictiveBackEnabled, isTrue);
  });
}
