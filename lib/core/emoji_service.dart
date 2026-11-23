import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Map<String, String> _parseEmojiJson(String json) =>
    Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>);

class EmojiService {
  static Map<String, String>? _emojiMap;

  static Future<Map<String, String>> load() async {
    final cached = _emojiMap;
    if (cached != null) return cached;
    final json = await rootBundle.loadString('assets/emoji.json');
    final map = await compute(_parseEmojiJson, json);
    _emojiMap = map;
    debugPrint('[EmojiService] loaded ${map.length} emojis');
    return map;
  }
}
