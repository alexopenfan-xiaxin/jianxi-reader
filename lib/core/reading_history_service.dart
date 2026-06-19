import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
      openedAtMillis: json['openedAtMillis'] as int? ??
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

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    if (!metadataDir.existsSync()) {
      await metadataDir.create(recursive: true);
    }
    return File('${metadataDir.path}/$_fileName');
  }

  static Future<List<ReadingHistoryEvent>> loadAll() async {
    return _loadFuture ??= () async {
      final file = await _file;
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final list = jsonDecode(raw) as List;
          _cache = list
              .map((e) => ReadingHistoryEvent.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('[ReadingHistoryService] load failed: $e');
          _cache = [];
        }
      } else {
        _cache = [];
      }
      return _cache!;
    }();
  }

  static Future<void> record({
    required String documentId,
    double? progressRatio,
  }) async {
    final events = await loadAll();
    final event = ReadingHistoryEvent(
      documentId: documentId,
      openedAtMillis: DateTime.now().millisecondsSinceEpoch,
      progressRatio: progressRatio,
    );
    events.add(event);
    // Trim to max events (keep most recent).
    if (events.length > _maxEvents) {
      events.removeRange(0, events.length - _maxEvents);
    }
    await _save(events);
  }

  static Future<List<ReadingHistoryEvent>> recentEvents({int limit = 50}) async {
    final events = await loadAll();
    final sorted = List<ReadingHistoryEvent>.from(events)
      ..sort((a, b) => b.openedAtMillis.compareTo(a.openedAtMillis));
    return sorted.take(limit).toList();
  }

  static Future<void> removeForDocument(String documentId) async {
    final events = await loadAll();
    events.removeWhere((e) => e.documentId == documentId);
    await _save(events);
  }

  static Future<void> clearAll() async {
    _cache = [];
    await _save([]);
  }

  static Future<void> _save(List<ReadingHistoryEvent> events) async {
    try {
      final file = await _file;
      final json = events.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('[ReadingHistoryService] save failed: $e');
    }
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
