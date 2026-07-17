import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/metadata_file_store.dart';

void main() {
  test('metadata mutations for one file run in submission order', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final order = <int>[];

    final first = MetadataFileStore.serialize('queue_test.json', () async {
      firstStarted.complete();
      await releaseFirst.future;
      order.add(1);
    });
    await firstStarted.future;
    final second = MetadataFileStore.serialize('queue_test.json', () async {
      order.add(2);
    });

    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(order, [1, 2]);
  });
}
