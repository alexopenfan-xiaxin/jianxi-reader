import 'package:flutter/foundation.dart';

class DocumentSearchController extends ChangeNotifier {
  String _query = '';
  int _matchCount = 0;
  int _currentIndex = 0;

  String get query => _query;
  String get normalizedQuery => _query.trim();
  int get matchCount => _matchCount;
  int get currentIndex => _matchCount == 0 ? 0 : _currentIndex;
  bool get hasQuery => normalizedQuery.isNotEmpty;
  bool get hasMatches => _matchCount > 0;

  void updateQuery(String query) {
    if (_query == query) {
      return;
    }
    _query = query;
    _matchCount = 0;
    _currentIndex = 0;
    notifyListeners();
  }

  void updateMatchCount(int count) {
    final cleanCount = count < 0 ? 0 : count;
    final nextIndex = cleanCount == 0
        ? 0
        : _currentIndex.clamp(0, cleanCount - 1).toInt();
    if (_matchCount == cleanCount && _currentIndex == nextIndex) {
      return;
    }
    _matchCount = cleanCount;
    _currentIndex = nextIndex;
    notifyListeners();
  }

  void next() {
    if (_matchCount == 0) {
      return;
    }
    _currentIndex = (_currentIndex + 1) % _matchCount;
    notifyListeners();
  }

  void previous() {
    if (_matchCount == 0) {
      return;
    }
    _currentIndex = (_currentIndex - 1 + _matchCount) % _matchCount;
    notifyListeners();
  }

  void clear() {
    if (_query.isEmpty && _matchCount == 0 && _currentIndex == 0) {
      return;
    }
    _query = '';
    _matchCount = 0;
    _currentIndex = 0;
    notifyListeners();
  }
}
