# Rust migration boundary

The Flutter app keeps Flutter widgets, navigation, file access, preferences, WebView rendering, and
Markdown presentation in Dart. Rust owns the measured full-text search core in `rust/`:

- CJK bigram and ASCII tokenization;
- per-document token counting;
- in-memory index replacement and search ranking.

`lib/data/search/search_native.dart` calls the Rust `cdylib` through Dart FFI. If the library cannot
be loaded, Dart uses the same algorithm as a fallback. CI runs Rust unit tests, Flutter tests with `JIANXI_REQUIRE_RUST_SEARCH=true`, and an Android APK assertion that the
Rust `.so` is packaged.

The NativeScript app has a separate Android Rust bridge for deterministic document helpers. The two
applications deliberately share the migration rule rather than a binary: UI and platform I/O stay
in their framework, while pure hot or behavior-sensitive logic moves behind a tested native API.

## CI-only build policy

This workstation does not install Flutter, Rust, or Android toolchains. Use the existing GitHub
Actions workflows to validate and package both targets. Local edits should still preserve the
framework fallback paths so JavaScript/Dart development remains possible without native artifacts.
