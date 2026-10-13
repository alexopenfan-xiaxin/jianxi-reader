import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  const HapticService._();

  static const _channel = MethodChannel('com.jianxi.reader/haptics');

  static void selectionClick() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _channel.invokeMethod<void>('selectionClick').catchError((_) {});
      return;
    }
    HapticFeedback.selectionClick();
  }

  static void lightImpact() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _channel.invokeMethod<void>('lightImpact').catchError((_) {});
      return;
    }
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _channel.invokeMethod<void>('mediumImpact').catchError((_) {});
      return;
    }
    HapticFeedback.mediumImpact();
  }

  static void successFeedback() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _channel.invokeMethod<void>('successFeedback').catchError((_) {});
      return;
    }
    HapticFeedback.mediumImpact();
  }
}
