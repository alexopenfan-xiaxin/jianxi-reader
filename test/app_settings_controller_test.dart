import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/app_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists liquid glass intensity preference', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    await settings.load();

    expect(
      settings.liquidGlassIntensityMode,
      LiquidGlassIntensityMode.standard,
    );
    // Standard mode always resolves to the curated default, not the raw store.
    expect(
      settings.liquidGlassIntensityValue,
      AppSettingsController.liquidGlassIntensityDefault,
    );

    await settings.setLiquidGlassIntensity(0.3);
    expect(
      settings.liquidGlassIntensityMode,
      LiquidGlassIntensityMode.custom,
      reason: 'moving the slider should opt into custom mode',
    );
    expect(settings.liquidGlassIntensityValue, closeTo(0.3, 1e-9));

    final restored = AppSettingsController();
    await restored.load();
    expect(restored.liquidGlassIntensityMode, LiquidGlassIntensityMode.custom);
    expect(restored.liquidGlassIntensityValue, closeTo(0.3, 1e-9));

    await restored.setLiquidGlassIntensityMode(
      LiquidGlassIntensityMode.standard,
    );
    final reverted = AppSettingsController();
    await reverted.load();
    expect(
      reverted.liquidGlassIntensityMode,
      LiquidGlassIntensityMode.standard,
    );
    expect(
      reverted.liquidGlassIntensityValue,
      AppSettingsController.liquidGlassIntensityDefault,
      reason: 'standard mode ignores the stored custom value',
    );
  });

  test('clamps out-of-range intensity', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    await settings.load();

    await settings.setLiquidGlassIntensity(3.4);
    expect(
      settings.liquidGlassIntensityValue,
      AppSettingsController.liquidGlassIntensityMax,
    );
  });
}
