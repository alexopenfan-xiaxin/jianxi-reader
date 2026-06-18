import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  const HapticService._();

  static const _channel = MethodChannel('com.jianxi.reader/haptics');

  static void selectionClick() {
    HapticFeedback.selectionClick();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _channel.invokeMethod<void>('selectionClick').catchError((_) {});
  }

  static void lightImpact() {
    HapticFeedback.lightImpact();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _channel.invokeMethod<void>('lightImpact').catchError((_) {});
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _channel.invokeMethod<void>('mediumImpact').catchError((_) {});
  }

  static void successFeedback() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      HapticFeedback.mediumImpact();
      return;
    }
    _channel.invokeMethod<void>('successFeedback').catchError((_) {});
  }
}
