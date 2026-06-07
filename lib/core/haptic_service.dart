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
}
