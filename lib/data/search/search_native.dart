import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef _AllocNative = Pointer<Uint8> Function(IntPtr);
typedef _AllocDart = Pointer<Uint8> Function(int);
typedef _DeallocNative = Void Function(Pointer<Uint8>, IntPtr);
typedef _DeallocDart = void Function(Pointer<Uint8>, int);
typedef _TransformNative = IntPtr Function(
  Pointer<Uint8>,
  IntPtr,
  Pointer<Uint8>,
  IntPtr,
);
typedef _TransformDart = int Function(
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
);
typedef _MutateNative = Int32 Function(Pointer<Uint8>, IntPtr);
typedef _MutateDart = int Function(Pointer<Uint8>, int);

class NativeSearchHit {
  const NativeSearchHit({required this.path, required this.score});
  final String path;
  final int score;
}

class NativeSearch {
  NativeSearch._();
  static final NativeSearch? _instance = _load();
  static NativeSearch? get instance => _instance;

  static NativeSearch? _load() {
    final required = const bool.fromEnvironment('JIANXI_REQUIRE_RUST_SEARCH');
    try {
      final library = DynamicLibrary.open(_libraryPath());
      return NativeSearch._()
        .._alloc = library.lookupFunction<_AllocNative, _AllocDart>(
          'jianxi_alloc',
        )
        .._dealloc = library.lookupFunction<_DeallocNative, _DeallocDart>(
          'jianxi_dealloc',
        )
        .._tokenize = library.lookupFunction<_TransformNative, _TransformDart>(
          'jianxi_tokenize',
        )
        .._countTokens = library.lookupFunction<
          _TransformNative,
          _TransformDart
        >('jianxi_count_tokens')
        .._replaceIndex = library.lookupFunction<_MutateNative, _MutateDart>(
          'jianxi_replace_index',
        )
        .._search = library.lookupFunction<_TransformNative, _TransformDart>(
          'jianxi_search',
        );
    } catch (error) {
      if (required) {
      throw StateError(
        'Rust search library is required but unavailable: $error',
      );
      }
      debugPrint(
        '[NativeSearch] Rust library unavailable; using Dart fallback: $error',
      );
      return null;
    }
  }

  static String _libraryPath() {
    const override = String.fromEnvironment('JIANXI_SEARCH_LIBRARY');
    if (override.isNotEmpty) return override;
    if (Platform.isAndroid) return 'libjianxi_search.so';
    if (Platform.isLinux) return 'rust/target/debug/libjianxi_search.so';
    throw UnsupportedError('Rust search is not configured on this platform');
  }

  late final _AllocDart _alloc;
  late final _DeallocDart _dealloc;
  late final _TransformDart _tokenize;
  late final _TransformDart _countTokens;
  late final _MutateDart _replaceIndex;
  late final _TransformDart _search;

  List<String> tokenize(String text) => (jsonDecode(
    utf8.decode(_transform(_tokenize, utf8.encode(text))),
  ) as List<dynamic>).cast<String>();

  Map<String, int> countTokens(String text) {
    final decoded =
        jsonDecode(
              utf8.decode(_transform(_countTokens, utf8.encode(text))),
            )
            as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  void replaceIndex(List<Map<String, Object?>> documents) {
    final payload = utf8.encode(jsonEncode({'documents': documents}));
    final input = _copyIn(payload);
    try {
      final status = _replaceIndex(input, payload.length);
      if (status != 0) throw StateError('Rust index sync failed ($status)');
    } finally {
      if (payload.isNotEmpty) _dealloc(input, payload.length);
    }
  }

  List<NativeSearchHit> search(String query) => (jsonDecode(
    utf8.decode(_transform(_search, utf8.encode(query))),
  ) as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(
        (hit) => NativeSearchHit(
          path: hit['path'] as String,
          score: (hit['score'] as num).toInt(),
        ),
      )
      .toList(growable: false);

  List<int> _transform(_TransformDart operation, List<int> bytes) {
    final input = _copyIn(bytes);
    try {
      final required = operation(input, bytes.length, nullptr, 0);
      if (required < 0) {
        throw StateError('Rust search operation failed ($required)');
      }
      final output = _alloc(required);
      if (output == nullptr) throw StateError('Rust search allocation failed');
      try {
        final written = operation(input, bytes.length, output, required);
        if (written != required) {
          throw StateError('Rust search returned an invalid response length');
        }
        return output.asTypedList(written).toList(growable: false);
      } finally {
        _dealloc(output, required);
      }
    } finally {
      if (bytes.isNotEmpty) _dealloc(input, bytes.length);
    }
  }

  Pointer<Uint8> _copyIn(List<int> bytes) {
    if (bytes.isEmpty) return nullptr;
    final pointer = _alloc(bytes.length);
    if (pointer == nullptr) throw StateError('Rust search allocation failed');
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    return pointer;
  }
}
