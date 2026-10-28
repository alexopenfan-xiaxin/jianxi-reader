# 简兮阅读器 — Agent Guide

## 1. Task boundaries

- A user's explicit task boundary wins. For a read-only review or diagnosis, do not edit, commit, push, build, or publish; do not widen a narrow task into version, lint, encoding, changelog, or release work.
- Do routine reversible work without asking. Ask only when a missing choice materially changes the result, credentials are needed, or the operation would publish, overwrite, delete, or expose data.
- Preserve unrelated working-tree changes; stage only task files; never `git add -A`.

## 2. Environment and validation

- The author's Windows machine has no Flutter/Dart SDK. Do not probe, install, or run `dart`/`flutter` there unless the user explicitly asks.
- CI is the only gate: `.github/workflows/ci.yml` runs lockfile, `dart format`, `flutter analyze --fatal-infos`, and `flutter test` on Flutter 3.44 for `main` and pull requests. Unformatted or non-analyzing pushes come back as fix-up commits; write formatter-shaped Dart, re-read touched blocks for brackets/commas/imports, and run `git diff --check`.
- If the user explicitly requests local validation or a build, use Flutter 3.44 on a machine that has it (or the `build-apk` workflow), run only the requested checks, and say when validation was skipped. Never claim a check ran when it did not.

## 3. Project map

- State: `LibraryController` (`lib/features/library/`) and `AppSettingsController` (`lib/core/`) are provided `ChangeNotifier`s; `DocumentSearchController` (`lib/features/reader/`) is owned by `ReaderPage`.
- Design: `lib/core/design_tokens.dart` (`context.palette`, `AppColors`, `AppSpacing`, `AppRadii`); shared widgets in `lib/core/widgets/` (`app_card.dart`, `liquid_glass.dart`).
- Files and metadata: `lib/core/document_file_service.dart`; `MetadataFileStore` (`lib/core/metadata_file_store.dart`) serializes mutations and atomically replaces identity, bookmark, and history files.
- UI: `lib/features/shell/app_shell.dart` and `lib/features/{library,reader,settings}/`. Hot spots: `liquid_glass.dart`, `about_settings.dart`, `library_toolbar.dart`.
- Markdown: `markdown_viewer.dart`; `MarkdownDocument` parses in a background isolate (`compute`), and the viewport virtualizes sections inside one shared `SelectionArea`.
- Tests: `test/` (17 files); use `test/fakes/fake_document_service.dart` for widget tests.
- Add new logic in a new file instead of growing `document_file_service.dart` (~40KB), `markdown_viewer.dart` (~39KB), `reader_page.dart` (~38KB), or `library_list_view.dart` (~38KB).
- `docs/liquid_glass_component_migration_plan.md` and `.trae/` are historical plans (some describe abandoned or merged work); code and tests are the source of truth.

## 4. Constraints

- Flutter 3.44; one font-family name (the bundled font is `LXGWWenKai`), never a CSS-style stack.
- Navigation: keep the shell's `IndexedStack` keyless; use `appPageRoute`. Pushes use horizontal `SharedAxisTransition`, pops `FadeThroughTransition`; root pages may opt into `AppPageTransition.fadeThrough`. The left-edge swipe handles interactive back; do not reintroduce predictive-back branches.
- Drag or scroll bottom sheets use `DraggableScrollableSheet` with `isScrollControlled: true`.
- Animations must terminate; no repeating animations in widget-test trees. Stagger with controller `Interval`s, not delayed timers; cancel hold timers in `dispose`.
- Markdown renders through `MarkdownRenderer` in `markdown_viewer.dart`; keep it selectable with tappable links and images. Preserve cross-section selection, scroll anchoring, TOC correction, and per-section search indices. Persisted document IDs must be deterministic, never Dart `hashCode`.
- Liquid glass: default to `GlassQuality.standard`. `premium` is only safe for chrome that never transforms (bottom nav, static dialogs); headers, app bars, and anything inside a tab or page transition stay on `standard` because premium's backdrop group flashes black. Intensity is fixed at `AppSettingsController.liquidGlassIntensityDefault` (0.9); do not reintroduce the removed slider.
- Android release builds need `INTERNET` in the main manifest.
- TLS: the update host `blog.openfan.dpdns.org` has an incomplete certificate chain. Two legacy workarounds exist: `badCertificateCallback` for that host in `about_settings.dart`, and `curl --insecure` in `publish.yml`. Do not widen either; removing them requires a fixed server chain.

## 5. Commits, version, and release

- `main` is the only long-lived branch; do not recreate `test`.
- Commit only task files and push to `origin/main` by default unless the user asks otherwise; never force-push. If `origin/main` advanced, integrate before pushing.
- `pubspec.yaml` is the version source of truth. Bump `version` and the build number at a release boundary, not on every edit; keep `_fallbackBuildNumber` in `about_settings.dart` in sync. End commit subjects with `(build N)` for the current build; `publish.yml` strips it when generating notes.
- "run" or an ordinary code change is not release authorization. Build, GitHub Release, and update-server upload need an explicit full-release request.
- Release path: `.github/workflows/publish.yml` (dispatch defaults to `main`) builds once, checks `v<version>+<build>`, publishes notes and APK, and uploads to the update server. Manual fallback, credentials, and failure handling: `docs/release.md`.
