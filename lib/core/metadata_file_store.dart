import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Serializes metadata mutations and replaces JSON files atomically.
class MetadataFileStore {
  MetadataFileStore._();

  static final Map<String, Future<void>> _queues = {};

  static Future<File> file(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${dir.path}/metadata');
    await metadataDir.create(recursive: true);
    return File('${metadataDir.path}/$fileName');
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
    final temporary = File('${destination.path}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(value), flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
