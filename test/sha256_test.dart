import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/sha256.dart';

void main() {
  group('Sha256', () {
    test('matches the FIPS 180-4 vectors', () {
      expect(
        Sha256.hashBytes(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        Sha256.hashBytes(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        Sha256.hashBytes(
          utf8.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
          ),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('pads correctly around the block boundary', () {
      expect(
        Sha256.hashBytes(utf8.encode('a'.padRight(55, 'a'))),
        '9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318',
      );
      expect(
        Sha256.hashBytes(utf8.encode('a'.padRight(56, 'a'))),
        'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a',
      );
      expect(
        Sha256.hashBytes(utf8.encode('a'.padRight(64, 'a'))),
        'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb',
      );
      expect(
        Sha256.hashBytes(utf8.encode('a'.padRight(65, 'a'))),
        '635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0',
      );
    });

    test('produces the same digest however the input is chunked', () {
      final payload = utf8.encode(List.filled(7, 'the quick brown fox').join());
      final whole = Sha256.hashBytes(payload);

      final byteAtATime = Sha256();
      for (final byte in payload) {
        byteAtATime.add([byte]);
      }
      expect(byteAtATime.finish(), whole);

      final uneven = Sha256();
      var offset = 0;
      for (final size in const [17, 31, 64, 5]) {
        if (offset >= payload.length) break;
        final end = offset + size < payload.length
            ? offset + size
            : payload.length;
        uneven.add(payload.sublist(offset, end));
        offset = end;
      }
      uneven.add(payload.sublist(offset));
      expect(uneven.finish(), whole);
    });

    test('rejects further input once finished', () {
      final hasher = Sha256()..add(utf8.encode('abc'));
      hasher.finish();
      expect(() => hasher.add(const [0]), throwsStateError);
      expect(hasher.finish, throwsStateError);
    });
  });

  group('isSha256Hex', () {
    test('accepts 64 hex characters only', () {
      expect(isSha256Hex('a'.padRight(64, 'a')), isTrue);
      expect(isSha256Hex('B76B05E9'.padRight(64, '0')), isTrue);
      expect(isSha256Hex('a'.padRight(63, 'a')), isFalse);
      expect(isSha256Hex('g'.padRight(64, 'g')), isFalse);
      expect(isSha256Hex(''), isFalse);
    });
  });
}
