import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/app_settings_controller.dart';
import 'package:jianxi_reader/core/widgets/liquid_glass.dart';

void main() {
  group('AppGlassSettings role policy', () {
    test('assigns the documented blur budgets', () {
      expect(
        AppGlassSettings.blurFor(AppGlassRole.staticChrome),
        LiquidGlassTokens.chromeBlur,
      );
      expect(
        AppGlassSettings.blurFor(AppGlassRole.animatedChrome),
        LiquidGlassTokens.chromeBlur,
      );
      expect(
        AppGlassSettings.blurFor(AppGlassRole.staticPanel),
        LiquidGlassTokens.panelBlur,
      );
      expect(
        AppGlassSettings.blurFor(AppGlassRole.draggedSurface),
        LiquidGlassTokens.panelBlur,
      );
      expect(
        AppGlassSettings.blurFor(AppGlassRole.interactiveControl),
        LiquidGlassTokens.controlBlur,
      );
      expect(
        AppGlassSettings.blurFor(AppGlassRole.groupedCard),
        LiquidGlassTokens.controlBlur,
      );
    });

    test('keeps premium only for static surfaces', () {
      expect(
        AppGlassSettings.qualityFor(AppGlassRole.staticChrome),
        GlassQuality.premium,
      );
      expect(
        AppGlassSettings.qualityFor(AppGlassRole.staticPanel),
        GlassQuality.premium,
      );
      const movingRoles = <AppGlassRole>[
        AppGlassRole.animatedChrome,
        AppGlassRole.draggedSurface,
        AppGlassRole.interactiveControl,
        AppGlassRole.groupedCard,
      ];
      for (final role in movingRoles) {
        expect(AppGlassSettings.qualityFor(role), GlassQuality.standard);
      }
    });
  });

  group('AppGlassSettings material', () {
    LiquidGlassSettings build(
      double intensity, {
      Brightness brightness = Brightness.light,
      AppGlassRole role = AppGlassRole.interactiveControl,
      double? blurOverride,
    }) {
      return AppGlassSettings.material(
        role: role,
        intensity: intensity,
        brightness: brightness,
        color: const Color(0x52FFFFFF),
        blurOverride: blurOverride,
      );
    }

    test('scales every material channel with intensity', () {
      final low = build(0);
      final curated = build(AppSettingsController.liquidGlassIntensityDefault);
      final high = build(1);

      expect(low.blur, lessThan(curated.blur));
      expect(curated.blur, lessThan(high.blur));
      expect(low.thickness, lessThan(curated.thickness));
      expect(curated.thickness, lessThan(high.thickness));
      expect(low.ambientRim, lessThan(curated.ambientRim));
      expect(low.lightIntensity, lessThan(high.lightIntensity));
      expect(low.refractiveIndex, lessThan(high.refractiveIndex));
      expect(low.glassColor.a, lessThan(high.glassColor.a));
    });

    test('keeps the curated refraction depth above the visible threshold', () {
      final curated = build(AppSettingsController.liquidGlassIntensityDefault);
      expect(curated.thickness, greaterThanOrEqualTo(12));
      expect(curated.thickness, lessThan(LiquidGlassTokens.thickness));
      expect(curated.ambientRim, greaterThan(0));
      expect(curated.whitenStrength, greaterThan(0));
    });

    test('uses the light whitening veil and skips it in dark mode', () {
      final light = build(AppSettingsController.liquidGlassIntensityDefault);
      final dark = build(
        AppSettingsController.liquidGlassIntensityDefault,
        brightness: Brightness.dark,
      );
      expect(light.whitenStrength, greaterThan(0));
      expect(dark.whitenStrength, 0);
      expect(dark.ambientStrength, LiquidGlassTokens.darkAmbient);
    });

    test('honors a blur override without touching the rest of the chain', () {
      const intensity = AppSettingsController.liquidGlassIntensityDefault;
      final base = build(intensity);
      final overridden = build(
        intensity,
        role: AppGlassRole.staticPanel,
        blurOverride: LiquidGlassTokens.panelBlur,
      );

      expect(
        overridden.blur,
        greaterThan(AppGlassSettings.blurFor(AppGlassRole.interactiveControl)),
      );
      expect(overridden.thickness, base.thickness);
      expect(overridden.ambientRim, base.ambientRim);
    });
  });
}
