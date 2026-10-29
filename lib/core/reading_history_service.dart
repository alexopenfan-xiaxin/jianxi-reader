import 'metadata_file_store.dart';

/// A single reading event: document opened at a point in time.
class ReadingHistoryEvent {
  const ReadingHistoryEvent({
    required this.documentId,
    required this.openedAtMillis,
    this.progressRatio,
  });

  final String documentId;
  final int openedAtMillis;
  final double? progressRatio;

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'openedAtMillis': openedAtMillis,
    if (progressRatio != null) 'progressRatio': progressRatio,
  };

  factory ReadingHistoryEvent.fromJson(Map<String, dynamic> json) {
    return ReadingHistoryEvent(
      documentId: json['documentId'] as String,
      openedAtMillis:
          json['openedAtMillis'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      progressRatio: (json['progressRatio'] as num?)?.toDouble(),
    );
  }
}

/// Stores reading history events for timeline display.
/// File: `metadata/history.json`
class ReadingHistoryService {
  ReadingHistoryService._();

  static const _fileName = 'history.json';
  static const _maxEvents = 500;
  static List<ReadingHistoryEvent>? _cache;
  static Future<List<ReadingHistoryEvent>>? _loadFuture;

  static Future<List<ReadingHistoryEvent>> loadAll() async {
    return _loadFuture ??= () async {
      // Same tolerance as bookmarks: drop only the entries that stopped
      // parsing, keep the rest, and never overwrite an unreadable file blind.
      final read = await MetadataFileStore.readJsonList(
        _fileName,
        ReadingHistoryEvent.fromJson,
      );
      _cache = read.items;
      return _cache!;
    }();
  }

  static Future<void> record({
    required String documentId,
    double? progressRatio,
  }) {
    return MetadataFileStore.serialize(_fileName, () async {
      final events = await loadAll();
      final next = [
        ...events,
        ReadingHistoryEvent(
          documentId: documentId,
          openedAtMillis: DateTime.now().millisecondsSinceEpoch,
          progressRatio: progressRatio,
        ),
      ];
      if (next.length > _maxEvents) {
        next.removeRange(0, next.length - _maxEvents);
      }
      await _replaceAll(events, next);
    });
  }

  static Future<List<ReadingHistoryEvent>> recentEvents({
    int limit = 50,
  }) async {
    final events = await loadAll();
    final sorted = List<ReadingHistoryEvent>.from(events)
      ..sort((a, b) => b.openedAtMillis.compareTo(a.openedAtMillis));
    return sorted.take(limit).toList();
  }

  static Future<void> removeForDocument(String documentId) {
    return MetadataFileStore.serialize(_fileName, () async {
      final events = await loadAll();
      await _replaceAll(
        events,
        events.where((event) => event.documentId != documentId).toList(),
      );
    });
  }

  static Future<void> clearAll() {
    return MetadataFileStore.serialize(_fileName, () async {
      final events = await loadAll();
      await _replaceAll(events, []);
    });
  }

  /// Puts removed events back after an undo, without duplicating them.
  static Future<void> restoreAll(List<ReadingHistoryEvent> restored) {
    if (restored.isEmpty) return Future<void>.value();
    return MetadataFileStore.serialize(_fileName, () async {
      final all = await loadAll();
      String keyOf(ReadingHistoryEvent event) =>
          '${event.documentId}@${event.openedAtMillis}';
      final known = all.map(keyOf).toSet();
      final next = [
        ...all,
        ...restored.where((event) => !known.contains(keyOf(event))),
      ];
      if (next.length > _maxEvents) {
        next.sort((a, b) => a.openedAtMillis.compareTo(b.openedAtMillis));
        next.removeRange(0, next.length - _maxEvents);
      }
      await _replaceAll(all, next);
    });
  }

  static Future<void> _replaceAll(
    List<ReadingHistoryEvent> current,
    List<ReadingHistoryEvent> next,
  ) async {
    final json = next.map((event) => event.toJson()).toList();
    await MetadataFileStore.writeJson(_fileName, json);
    current
      ..clear()
      ..addAll(next);
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
