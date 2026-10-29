import 'package:flutter/widgets.dart';

/// Accessibility helpers shared by the app shell and widgets.
///
/// G10 asks for three things the app previously ignored: text that still fits at
/// large system font sizes, animations that respect "remove animations", and
/// muted text that passes WCAG AA. The colour side lives in `design_tokens`;
/// these are the two runtime knobs.
class AppAccessibility {
  AppAccessibility._();

  /// Upper bound applied to the system text scale.
  ///
  /// Nobody wants tiny text, so the floor is 1.0; the ceiling keeps fixed-height
  /// chrome (72dp headers, 122dp recent cards) from overflowing at 2.0+, which
  /// is what the audit measured. 1.6 still respects a user who asked for larger
  /// text while leaving the layout intact.
  static const double maxTextScale = 1.6;
  static const double minTextScale = 1.0;

  static TextScaler clampTextScaler(TextScaler scaler) {
    return scaler.clamp(
      minScaleFactor: minTextScale,
      maxScaleFactor: maxTextScale,
    );
  }

  /// Takes the system "remove animations" switch into account.
  ///
  /// Entrance cascades, shimmer sweeps and progress `animateTo` calls all used a
  /// fixed duration, so the OS setting did nothing.
  static Duration duration(BuildContext context, Duration duration) {
    final disabled = MediaQuery.maybeDisableAnimationsOf(context);
    if (disabled ?? false) {
      return Duration.zero;
    }
    return duration;
  }
}
