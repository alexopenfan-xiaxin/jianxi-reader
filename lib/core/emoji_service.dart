import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EmojiService {
  static Map<String, String>? _emojiMap;

  static Future<Map<String, String>> load() async {
    if (_emojiMap != null) return _emojiMap!;
    final json = await rootBundle.loadString('assets/emoji.json');
    final list = jsonDecode(json) as List<dynamic>;
    final map = <String, String>{};
    for (final entry in list) {
      final emoji = entry['emoji'] as String;
      for (final alias in entry['aliases'] as List<dynamic>) {
        map[alias as String] = emoji;
      }
    }
    _emojiMap = map;
    debugPrint('[EmojiService] loaded ${map.length} emojis');
    return map;
  }
}
