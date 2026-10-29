/// Tokenisation for the library full-text index.
///
/// Chinese has no spaces, so the index uses character bigrams ("缓存失效" →
/// 缓存/存失/失效); ASCII runs are indexed as lower-cased words. A one-character
/// CJK query produces no bigram, so callers fall back to a substring scan —
/// that path is rare and cheap because it only reads matched documents.
library;

const int _cjkStart = 0x4E00;
const int _cjkEnd = 0x9FFF;
const int _extAStart = 0x3400;
const int _extAEnd = 0x4DBF;

/// True for characters the bigram tokenizer treats as a run of ideographs.
bool isCjkRune(int rune) {
  return (rune >= _cjkStart && rune <= _cjkEnd) ||
      (rune >= _extAStart && rune <= _extAEnd);
}

bool _isAsciiWordRune(int rune) {
  final isDigit = rune >= 0x30 && rune <= 0x39;
  final isUpper = rune >= 0x41 && rune <= 0x5A;
  final isLower = rune >= 0x61 && rune <= 0x7A;
  return isDigit || isUpper || isLower;
}

/// Splits [text] into index tokens. Order is preserved; duplicates are kept so
/// callers can count them.
List<String> tokenize(String text) {
  final tokens = <String>[];
  final runes = text.runes.toList();
  var index = 0;
  while (index < runes.length) {
    final rune = runes[index];
    if (isCjkRune(rune)) {
      var end = index;
      while (end < runes.length && isCjkRune(runes[end])) {
        end++;
      }
      for (var position = index; position + 1 < end; position++) {
        tokens.add(
          String.fromCharCodes(runes.sublist(position, position + 2)),
        );
      }
      index = end;
      continue;
    }
    if (_isAsciiWordRune(rune)) {
      var end = index;
      while (end < runes.length && _isAsciiWordRune(runes[end])) {
        end++;
      }
      tokens.add(String.fromCharCodes(runes.sublist(index, end)).toLowerCase());
      index = end;
      continue;
    }
    index++;
  }
  return tokens;
}

/// Token counts for one document.
Map<String, int> countTokens(String text) {
  final counts = <String, int>{};
  for (final token in tokenize(text)) {
    counts[token] = (counts[token] ?? 0) + 1;
  }
  return counts;
}

/// The first index where any of [tokens] appears literally, or null.
int? firstTokenIndex(String text, List<String> tokens) {
  final haystack = text.toLowerCase();
  var best = -1;
  for (final token in tokens) {
    final index = haystack.indexOf(token);
    if (index == -1) continue;
    if (best == -1 || index < best) best = index;
  }
  return best == -1 ? null : best;
}

/// A short window of [text] around the first hit, for the result list.
String snippetAround(String text, List<String> tokens, {int radius = 42}) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';
  final hit = firstTokenIndex(flat, tokens);
  if (hit == null) {
    return flat.length <= radius * 2
        ? flat
        : '${flat.substring(0, radius * 2)}…';
  }
  final start = (hit - radius).clamp(0, flat.length);
  final end = (hit + radius).clamp(0, flat.length);
  final prefix = start > 0 ? '…' : '';
  final suffix = end < flat.length ? '…' : '';
  return '$prefix${flat.substring(start, end)}$suffix';
}
