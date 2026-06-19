import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A search index entry for a single document.
class SearchIndexEntry {
  const SearchIndexEntry({
    required this.documentId,
    required this.title,
    required this.plainText,
    required this.headings,
    required this.tags,
    required this.indexedAtMillis,
    required this.sourceModifiedAtMillis,
  });

  final String documentId;
  final String title;
  final String plainText;
  final List<String> headings;
  final List<String> tags;
  final int indexedAtMillis;
  final int sourceModifiedAtMillis;

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'title': title,
        'plainText': plainText,
        'headings': headings,
        'tags': tags,
        'indexedAtMillis': indexedAtMillis,
        'sourceModifiedAtMillis': sourceModifiedAtMillis,
      };

  factory SearchIndexEntry.fromJson(Map<String, dynamic> json) {
    return SearchIndexEntry(
      documentId: json['documentId'] as String,
      title: json['title'] as String? ?? '',
      plainText: json['plainText'] as String? ?? '',
      headings: List<String>.from(json['headings'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      indexedAtMillis: json['indexedAtMillis'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      sourceModifiedAtMillis:
          json['sourceModifiedAtMillis'] as int? ?? 0,
    );
  }
}

/// A search result item.
class SearchResult {
  const SearchResult({
    required this.documentId,
    required this.title,
    required this.snippet,
    required this.matchedTags,
    required this.matchedHeadings,
  });

  final String documentId;
  final String title;
  final String snippet;
  final List<String> matchedTags;
  final List<String> matchedHeadings;
}

/// Local full-text search index stored in JSON.
/// File: `metadata/search_index.json`
class SearchIndexService {
  SearchIndexService._();

  static const _fileName = 'search_index.json';
  static Map<String, SearchIndexEntry>? _cache;
  static Future<Map<String, SearchIndexEntry>>? _loadFuture;
  static const _maxSnippetLength = 120;

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    if (!metadataDir.existsSync()) {
      await metadataDir.create(recursive: true);
    }
    return File('${metadataDir.path}/$_fileName');
  }

  static Future<Map<String, SearchIndexEntry>> loadAll() async {
    return _loadFuture ??= () async {
      final file = await _file;
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _cache = json.map((k, v) => MapEntry(
                k,
                SearchIndexEntry.fromJson(v as Map<String, dynamic>),
              ));
        } catch (e) {
          debugPrint('[SearchIndexService] load failed: $e');
          _cache = {};
        }
      } else {
        _cache = {};
      }
      return _cache!;
    }();
  }

  /// Index or re-index a document.
  static Future<void> indexDocument(SearchIndexEntry entry) async {
    final all = await loadAll();
    all[entry.documentId] = entry;
    await _save(all);
  }

  /// Remove a document from the index.
  static Future<void> removeDocument(String documentId) async {
    final all = await loadAll();
    if (all.remove(documentId) != null) {
      await _save(all);
    }
  }

  /// Search across all indexed documents.
  ///
  /// Returns results sorted by relevance (title match > heading match > content match).
  static Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final all = await loadAll();
    final q = query.trim().toLowerCase();
    final results = <SearchResult>[];

    for (final entry in all.values) {
      final titleMatch = entry.title.toLowerCase().contains(q);
      final headingMatches = entry.headings
          .where((h) => h.toLowerCase().contains(q))
          .toList();
      final tagMatches = entry.tags
          .where((t) => t.toLowerCase().contains(q))
          .toList();
      final contentMatch = entry.plainText.toLowerCase().contains(q);

      if (!titleMatch && headingMatches.isEmpty && tagMatches.isEmpty && !contentMatch) {
        continue;
      }

      // Build snippet from content match.
      String snippet = '';
      if (contentMatch) {
        final lowerText = entry.plainText.toLowerCase();
        final idx = lowerText.indexOf(q);
        if (idx != -1) {
          final start = (idx - 40).clamp(0, entry.plainText.length);
          final end = (idx + q.length + 40).clamp(0, entry.plainText.length);
          snippet = entry.plainText.substring(start, end);
          if (start > 0) snippet = '...$snippet';
          if (end < entry.plainText.length) snippet = '$snippet...';
        }
      } else if (headingMatches.isNotEmpty) {
        snippet = headingMatches.first;
      } else if (titleMatch) {
        snippet = entry.title;
      }
      if (snippet.length > _maxSnippetLength) {
        snippet = '${snippet.substring(0, _maxSnippetLength)}...';
      }

      results.add(SearchResult(
        documentId: entry.documentId,
        title: entry.title,
        snippet: snippet,
        matchedTags: tagMatches,
        matchedHeadings: headingMatches,
      ));
    }

    // Sort: title match first, then heading match, then content.
    results.sort((a, b) {
      final aTitle = a.title.toLowerCase().contains(q) ? 0 : 1;
      final bTitle = b.title.toLowerCase().contains(q) ? 0 : 1;
      if (aTitle != bTitle) return aTitle.compareTo(bTitle);
      final aHeading = a.matchedHeadings.isNotEmpty ? 0 : 1;
      final bHeading = b.matchedHeadings.isNotEmpty ? 0 : 1;
      return aHeading.compareTo(bHeading);
    });

    return results;
  }

  static Future<void> _save(Map<String, SearchIndexEntry> entries) async {
    try {
      final file = await _file;
      final json = entries.map((k, v) => MapEntry(k, v.toJson()));
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('[SearchIndexService] save failed: $e');
    }
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
