# 简兮阅读器 — Agent Guide

## Project map

- UI lives in `lib/features/`; design tokens and shared widgets are in `lib/core/design_tokens.dart` and `lib/core/widgets/`.
- Markdown parsing and rendering live in `lib/features/reader/markdown/`. Library-wide search uses `lib/data/search/` and the native core in `rust/`.
- File operations use `lib/core/document_file_service.dart`. Library metadata lives in `lib/data/metadata/`; `lib/core/metadata_file_store.dart` handles atomic JSON writes.
- Tests live in `test/`; widget tests can reuse `test/fakes/fake_document_service.dart`. Prefer current code, tests, and workflows over historical plans.

## Validation

- `.github/workflows/ci.yml` pins the toolchain and defines the checks: dependency lockfile, release metadata, Dart formatting and analysis, Flutter and Rust tests, and the Android release APK.
- This Windows machine lacks space for the Flutter SDK. Do not install it or run `flutter` or `dart` locally; rely on CI for SDK-dependent checks and builds.
- Run relevant lightweight checks that do not need the SDK (e.g. `git diff --check`). Report which checks ran and which were left to CI.

## Regression risks

- Keep persisted document IDs deterministic and preserve atomic metadata updates.
- Preserve Markdown section virtualization, cross-section selection, tappable links and images, scroll anchoring, and TOC/search navigation.
- Use the shared `appPageRoute` and preserve tab state when changing navigation. Use `GlassQuality.standard` for moving surfaces; `premium` can flash black there.
- Keep `INTERNET` in the main Android manifest for updates and remote document resources. Do not broaden existing TLS exceptions.

## Git and release

- Commit only task changes and push to `origin/main` by default unless the user says otherwise. If the remote has advanced, integrate its changes before pushing; do not force-push.
- Ordinary changes and pushes do not imply a version bump or release. For publishing and signing, follow `docs/release.md` and `.github/workflows/publish.yml`.
