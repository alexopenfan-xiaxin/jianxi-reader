import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/metadata_file_store.dart';
import '../../features/library/document_entry.dart';
import 'search_text.dart';

/// One full-text result.
class SearchHit {
  const SearchHit({
    required this.documentId,
    required this.path,
    required this.title,
    required this.score,
    required this.snippet,
  });

  final String documentId;
  final String path;
  final String title;
  final double score;

  /// Text around the first hit, for the result row.
  final String snippet;
}

/// Library-wide full-text index.
///
/// Tokens are stored per document instead of as a global inverted list: the
/// library is small (hundreds of documents), and per-document maps make
/// incremental updates and removals trivial — the hot failure mode in 2.x was a
/// stale global structure that nobody could repair.
class LibrarySearchIndex {
  LibrarySearchIndex._();

  static const String fileName = 'search_index.json';
  static const int schemaVersion = 1;

  /// Documents larger than this are indexed only up to this many bytes.
  static const int maxIndexedBytes = 2 * 1024 * 1024;

  static Map<String, _IndexedDocument>? _cache;

  /// Brings the index in line with [documents]: new or changed files are
  /// re-read, entries whose document disappeared are dropped.
  static Future<void> refresh(Iterable<DocumentEntry> documents) async {
    final index = Map<String, _IndexedDocument>.of(await _load());
    final seen = <String>{};
    var changed = false;

    for (final document in documents) {
      seen.add(document.path);
      final existing = index[document.path];
      final modified = document.modifiedAt.millisecondsSinceEpoch;
      if (existing != null &&
          existing.updatedAtMillis == modified &&
          existing.sizeBytes == document.sizeBytes) {
        continue;
      }
      final indexed = await _indexDocument(document, modified);
      if (indexed == null) {
        if (existing != null) {
          index.remove(document.path);
          changed = true;
        }
        continue;
      }
      index[document.path] = indexed;
      changed = true;
    }

    for (final path in index.keys.toList()) {
      if (seen.contains(path)) continue;
      index.remove(path);
      changed = true;
    }

    if (changed) {
      await _write(index);
    }
  }

  /// Searches the index. Falls back to a substring scan when the query has no
  /// indexable token (a single CJK character, for example).
  static Future<List<SearchHit>> search(String query, {int limit = 40}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final tokens = tokenize(trimmed).toSet();
    final index = await _load();
    if (index.isEmpty) return const [];

    if (tokens.isEmpty) {
      return _substringSearch(trimmed, index.values.toList(), limit);
    }

    final matched = <_IndexedDocument>[];
    final scores = <String, double>{};
    for (final document in index.values) {
      var score = 0.0;
      var matchesAll = true;
      for (final token in tokens) {
        final count = document.tokens[token] ?? 0;
        if (count == 0) {
          matchesAll = false;
          break;
        }
        // Long tokens (words) weigh more than a repeated bigram.
        score += count * (token.length > 1 ? 2 : 1);
      }
      if (!matchesAll) continue;
      matched.add(document);
      scores[document.path] = score;
    }

    matched.sort(
      (left, right) =>
          (scores[right.path] ?? 0).compareTo(scores[left.path] ?? 0),
    );

    final hits = <SearchHit>[];
    for (final document in matched.take(limit)) {
      hits.add(await _toHit(document, tokens.toList(), scores[document.path]!));
    }
    return hits;
  }

  /// Re-reads one document after its content changed (markdown save, refresh).
  static Future<void> updateDocument(DocumentEntry document) async {
    await refresh([document]);
  }

  static Future<void> removeDocument(String path) async {
    final index = Map<String, _IndexedDocument>.of(await _load());
    if (index.remove(path) != null) {
      await _write(index);
    }
  }

  static Future<void> clear() async {
    _cache = null;
    await MetadataFileStore.writeJson(fileName, _emptyPayload());
  }

  @visibleForTesting
  static void clearCache() {
    _cache = null;
  }

  static Future<List<SearchHit>> _substringSearch(
    String query,
    List<_IndexedDocument> documents,
    int limit,
  ) async {
    final needle = query.toLowerCase();
    final hits = <SearchHit>[];
    for (final document in documents) {
      final file = File(document.path);
      if (!await file.exists()) continue;
      final text = await _readIndexable(file);
      if (!text.toLowerCase().contains(needle)) continue;
      hits.add(
        SearchHit(
          documentId: document.documentId,
          path: document.path,
          title: document.title,
          score: 1,
          snippet: snippetAround(text, [needle]),
        ),
      );
      if (hits.length >= limit) break;
    }
    return hits;
  }

  static Future<SearchHit> _toHit(
    _IndexedDocument document,
    List<String> tokens,
    double score,
  ) async {
    var snippet = '';
    try {
      final text = await _readIndexable(File(document.path));
      snippet = snippetAround(text, tokens);
    } catch (error) {
      debugPrint('[LibrarySearchIndex] snippet failed: $error');
    }
    return SearchHit(
      documentId: document.documentId,
      path: document.path,
      title: document.title,
      score: score,
      snippet: snippet,
    );
  }

  static Future<_IndexedDocument?> _indexDocument(
    DocumentEntry document,
    int modifiedAtMillis,
  ) async {
    final file = File(document.path);
    if (!await file.exists()) return null;
    final text = await _readIndexable(file);
    if (text.isEmpty) return null;
    return _IndexedDocument(
      documentId: document.path,
      path: document.path,
      title: document.name,
      sizeBytes: document.sizeBytes,
      updatedAtMillis: modifiedAtMillis,
      length: text.length,
      tokens: countTokens(text),
    );
  }

  static Future<String> _readIndexable(File file) async {
    try {
      final stat = await file.stat();
      if (stat.size <= maxIndexedBytes) {
        return await file.readAsString();
      }
      final handle = await file.open();
      try {
        final bytes = await handle.read(maxIndexedBytes);
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await handle.close();
      }
    } catch (error) {
      debugPrint('[LibrarySearchIndex] cannot read ${file.path}: $error');
      return '';
    }
  }

  static Future<Map<String, _IndexedDocument>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final read = await MetadataFileStore.readJson(fileName);
    final index = <String, _IndexedDocument>{};
    final data = read.data;
    if (data is Map) {
      final documents = data['documents'];
      if (documents is List) {
        for (final entry in documents) {
          if (entry is! Map) continue;
          try {
            final document = _IndexedDocument.fromJson(
              Map<String, dynamic>.from(entry),
            );
            index[document.path] = document;
          } catch (error) {
            debugPrint('[LibrarySearchIndex] dropped entry: $error');
          }
        }
      }
    }
    return _cache = index;
  }

  static Future<void> _write(Map<String, _IndexedDocument> index) async {
    _cache = index;
    await MetadataFileStore.writeJson(fileName, {
      'schema': schemaVersion,
      'documents': index.values.map((document) => document.toJson()).toList(),
    });
  }

  static Map<String, dynamic> _emptyPayload() => {
    'schema': schemaVersion,
    'documents': const [],
  };
}

class _IndexedDocument {
  _IndexedDocument({
    required this.documentId,
    required this.path,
    required this.title,
    required this.sizeBytes,
    required this.updatedAtMillis,
    required this.length,
    required this.tokens,
  });

  final String documentId;
  final String path;
  final String title;
  final int sizeBytes;
  final int updatedAtMillis;
  final int length;
  final Map<String, int> tokens;

  Map<String, dynamic> toJson() => {
    'id': documentId,
    'path': path,
    'title': title,
    'size': sizeBytes,
    'updatedAt': updatedAtMillis,
    'length': length,
    'tokens': tokens,
  };

  factory _IndexedDocument.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) {
      throw FormatException('index entry needs a path', json);
    }
    final rawTokens = json['tokens'];
    final tokens = <String, int>{};
    if (rawTokens is Map) {
      rawTokens.forEach((key, value) {
        if (key is String && value is num) {
          tokens[key] = value.toInt();
        }
      });
    }
    return _IndexedDocument(
      documentId: (json['id'] as String?) ?? path,
      path: path,
      title: (json['title'] as String?) ?? path,
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      updatedAtMillis: (json['updatedAt'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
      tokens: tokens,
    );
  }
}
