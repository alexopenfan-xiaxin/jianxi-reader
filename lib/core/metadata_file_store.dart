import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Serializes metadata mutations and replaces JSON files atomically.
class MetadataFileStore {
  MetadataFileStore._();

  static final Map<String, Future<void>> _queues = {};
  static Directory? _baseDirectoryForTesting;

  static Future<Directory> directory() async {
    final dir =
        _baseDirectoryForTesting ?? await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    await metadataDir.create(recursive: true);
    return metadataDir;
  }

  static Future<File> file(String fileName) async {
    final metadataDir = await directory();
    return File('${metadataDir.path}/$fileName');
  }

  @visibleForTesting
  static void setBaseDirectoryForTesting(Directory? directory) {
    _baseDirectoryForTesting = directory;
  }

  static Future<T> serialize<T>(String fileName, Future<T> Function() action) {
    final previous = _queues[fileName] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[fileName] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_queues[fileName], tail)) {
          _queues.remove(fileName);
        }
      }),
    );
    return result;
  }

  static Future<void> writeJson(String fileName, Object? value) async {
    final destination = await file(fileName);
    final temporary = File(
      '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(jsonEncode(value), flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  /// Reads a JSON document of any shape, quarantining it when unparseable.
  ///
  /// [data] is null when the file is missing, unreadable or not valid JSON;
  /// callers then decide whether to rebuild from a legacy source.
  static Future<JsonObjectRead> readJson(String fileName) async {
    final decoded = await _decode(fileName);
    return JsonObjectRead(
      data: decoded.data,
      quarantinePath: decoded.quarantinePath,
    );
  }

  /// Reads a JSON array, dropping (and counting) entries that no longer parse.
  ///
  /// A single damaged record used to take the whole file down with it: the
  /// loader cleared its cache and the next write persisted the empty list. Now
  /// only the bad entries are lost, and an unreadable file is copied aside
  /// first so nothing is silently overwritten.
  static Future<JsonListRead<T>> readJsonList<T>(
    String fileName,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final decoded = await _decode(fileName);
    if (decoded.data == null) {
      return JsonListRead<T>(
        items: const [],
        droppedEntries: 0,
        quarantinePath: decoded.quarantinePath,
      );
    }
    final raw = decoded.data;
    if (raw is! List) {
      final quarantine = await _quarantine(await file(fileName));
      debugPrint('[MetadataFileStore] $fileName is not a JSON array');
      return JsonListRead<T>(
        items: const [],
        droppedEntries: 0,
        quarantinePath: quarantine,
      );
    }

    final items = <T>[];
    var dropped = 0;
    for (final entry in raw) {
      if (entry is! Map) {
        dropped++;
        continue;
      }
      try {
        items.add(fromJson(Map<String, dynamic>.from(entry)));
      } catch (error) {
        dropped++;
        debugPrint(
          '[MetadataFileStore] dropped damaged entry in $fileName: '
          '$error',
        );
      }
    }
    if (dropped > 0) {
      debugPrint(
        '[MetadataFileStore] $fileName: kept ${items.length}, '
        'dropped $dropped damaged entr${dropped == 1 ? 'y' : 'ies'}',
      );
    }
    return JsonListRead<T>(
      items: items,
      droppedEntries: dropped,
      quarantinePath: decoded.quarantinePath,
    );
  }

  /// Reads a flat JSON string map, dropping keys whose values are unreadable.
  static Future<JsonMapRead> readJsonStringMap(String fileName) async {
    final decoded = await _decode(fileName);
    if (decoded.data == null) {
      return JsonMapRead(
        values: const {},
        droppedEntries: 0,
        quarantinePath: decoded.quarantinePath,
      );
    }
    final raw = decoded.data;
    if (raw is! Map) {
      final quarantine = await _quarantine(await file(fileName));
      debugPrint('[MetadataFileStore] $fileName is not a JSON object');
      return JsonMapRead(
        values: const {},
        droppedEntries: 0,
        quarantinePath: quarantine,
      );
    }

    final values = <String, String>{};
    var dropped = 0;
    raw.forEach((key, value) {
      if (key == null || value == null) {
        dropped++;
        return;
      }
      values[key.toString()] = value.toString();
    });
    return JsonMapRead(
      values: values,
      droppedEntries: dropped,
      quarantinePath: decoded.quarantinePath,
    );
  }

  static Future<_Decoded> _decode(String fileName) async {
    final source = await file(fileName);
    if (!await source.exists()) {
      return const _Decoded(null);
    }
    String raw;
    try {
      raw = await source.readAsString();
    } catch (error) {
      debugPrint('[MetadataFileStore] cannot read $fileName: $error');
      return const _Decoded(null);
    }
    try {
      return _Decoded(jsonDecode(raw));
    } catch (error) {
      debugPrint('[MetadataFileStore] $fileName is not valid JSON: $error');
      return _Decoded(null, quarantinePath: await _quarantine(source));
    }
  }

  static Future<String?> _quarantine(File source) async {
    try {
      final target =
          '${source.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
      await source.copy(target);
      debugPrint('[MetadataFileStore] quarantined damaged file to $target');
      return target;
    } catch (error) {
      debugPrint(
        '[MetadataFileStore] failed to quarantine ${source.path}: '
        '$error',
      );
      return null;
    }
  }
}

class _Decoded {
  const _Decoded(this.data, {this.quarantinePath});

  final Object? data;
  final String? quarantinePath;
}

/// Outcome of a tolerant JSON array read.
class JsonListRead<T> {
  const JsonListRead({
    required this.items,
    required this.droppedEntries,
    this.quarantinePath,
  });

  final List<T> items;
  final int droppedEntries;

  /// Copy of the damaged original, when the file could not be parsed at all.
  final String? quarantinePath;
}

/// Outcome of a tolerant JSON string-map read.
class JsonMapRead {
  const JsonMapRead({
    required this.values,
    required this.droppedEntries,
    this.quarantinePath,
  });

  final Map<String, String> values;
  final int droppedEntries;
  final String? quarantinePath;
}

/// Outcome of a raw JSON read.
class JsonObjectRead {
  const JsonObjectRead({required this.data, this.quarantinePath});

  final Object? data;
  final String? quarantinePath;
}
