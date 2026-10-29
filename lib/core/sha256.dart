import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Incremental SHA-256 (FIPS 180-4), in pure Dart.
///
/// `package:crypto` is only a transitive dependency of this project, so
/// importing it directly would break `flutter pub get --enforce-lockfile`.
/// The updater needs a digest check, so it carries its own implementation
/// instead of widening the dependency set.
class Sha256 {
  Sha256();

  static const int _blockSize = 64;

  static const List<int> _initialState = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];

  static const List<int> _k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  final Uint32List _state = Uint32List.fromList(_initialState);
  final Uint32List _schedule = Uint32List(64);
  final Uint8List _buffer = Uint8List(_blockSize);
  int _bufferLength = 0;
  int _totalLength = 0;
  bool _finished = false;

  /// Convenience helper for one-shot digests.
  static String hashBytes(List<int> data) {
    final hasher = Sha256()..add(data);
    return hasher.finish();
  }

  /// Feed more bytes into the digest.
  void add(List<int> data) {
    if (_finished) {
      throw StateError('Sha256 digest already finished');
    }
    _absorb(data);
  }

  void _absorb(List<int> data) {
    _totalLength += data.length;
    var offset = 0;

    if (_bufferLength > 0) {
      final take = math.min(_blockSize - _bufferLength, data.length);
      _buffer.setRange(_bufferLength, _bufferLength + take, data);
      _bufferLength += take;
      offset += take;
      if (_bufferLength == _blockSize) {
        _processBlock(_buffer, 0);
        _bufferLength = 0;
      }
    }

    while (data.length - offset >= _blockSize) {
      _processBlock(data, offset);
      offset += _blockSize;
    }

    final remaining = data.length - offset;
    if (remaining > 0) {
      _buffer.setRange(0, remaining, data, offset);
      _bufferLength = remaining;
    }
  }

  /// Finish the digest and return it as lowercase hex.
  String finish() {
    if (_finished) {
      throw StateError('Sha256 digest already finished');
    }
    _finished = true;

    final bitLength = _totalLength * 8;
    final zeros = (56 - (_totalLength + 1) % _blockSize) % _blockSize;
    final padding = Uint8List(1 + zeros + 8);
    padding[0] = 0x80;
    final lengthBytes = ByteData(8)
      ..setUint32(0, (bitLength ~/ 0x100000000) & 0xffffffff)
      ..setUint32(4, bitLength & 0xffffffff);
    padding.setRange(
      1 + zeros,
      1 + zeros + 8,
      lengthBytes.buffer.asUint8List(),
    );
    _absorb(padding);

    final out = StringBuffer();
    for (final word in _state) {
      out.write(word.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }

  void _processBlock(List<int> block, int offset) {
    final w = _schedule;
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] =
          ((block[j] << 24) |
              (block[j + 1] << 16) |
              (block[j + 2] << 8) |
              block[j + 3]) &
          0xffffffff;
    }
    for (var i = 16; i < 64; i++) {
      final x = w[i - 15];
      final y = w[i - 2];
      final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
      final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = _state[0];
    var b = _state[1];
    var c = _state[2];
    var d = _state[3];
    var e = _state[4];
    var f = _state[5];
    var g = _state[6];
    var h = _state[7];

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & g);
      final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    _state[0] = (_state[0] + a) & 0xffffffff;
    _state[1] = (_state[1] + b) & 0xffffffff;
    _state[2] = (_state[2] + c) & 0xffffffff;
    _state[3] = (_state[3] + d) & 0xffffffff;
    _state[4] = (_state[4] + e) & 0xffffffff;
    _state[5] = (_state[5] + f) & 0xffffffff;
    _state[6] = (_state[6] + g) & 0xffffffff;
    _state[7] = (_state[7] + h) & 0xffffffff;
  }

  static int _rotr(int value, int bits) =>
      ((value >> bits) | (value << (32 - bits))) & 0xffffffff;
}

/// True when [value] looks like a lowercase/uppercase hex SHA-256 digest.
bool isSha256Hex(String value) {
  if (value.length != 64) return false;
  for (final unit in utf8.encode(value)) {
    final isDigit = unit >= 0x30 && unit <= 0x39;
    final isLower = unit >= 0x61 && unit <= 0x66;
    final isUpper = unit >= 0x41 && unit <= 0x46;
    if (!isDigit && !isLower && !isUpper) return false;
  }
  return true;
}
