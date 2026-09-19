# 简兮阅读器 — Agent Guide

## Scope and source of truth

- This is a Flutter Markdown/HTML reader. Use the relevant source and tests for implementation details; this guide records durable constraints, not a history of every release.
- A user's explicit task boundary takes precedence over defaults below. For a read-only review or diagnosis, do not edit, commit, push, build, or publish. Do not expand a narrowly scoped task to unrelated version, lint, encoding, changelog, or release work.
- Do not ask for confirmation on routine, reversible work already within the request. Ask when a missing choice materially changes the result, credentials are required, or an operation would publish, overwrite, delete, or expose data beyond the user's authorization.
- Preserve unrelated working-tree changes. Stage only task files; never use `git add -A` as a shortcut.

## Project map

- State: `LibraryController` in `lib/features/library/` and `AppSettingsController` in `lib/core/` via Provider.
- Theme and tokens: `lib/core/design_tokens.dart`; use `context.palette`, `AppColors`, `AppSpacing`, and `AppRadii`. Shared card: `lib/core/widgets/app_card.dart`.
- Files and metadata: `lib/core/document_file_service.dart`; `MetadataFileStore` serializes mutations and atomically replaces identity, bookmark, and history files.
- UI: `lib/features/shell/app_shell.dart`, `lib/features/library/`, `lib/features/reader/`, and `lib/features/settings/`. Reuse the existing widgets in `lib/core/widgets/`.
- Markdown: `lib/features/reader/markdown/` parses sections in a background isolate and renders a virtualized viewport inside one shared `SelectionArea`. Preserve cross-section selection, scroll anchoring, TOC correction, and per-section search indices when touching that path.

## Implementation constraints

- Target Flutter 3.44 unless the user specifies otherwise. Use a single font-family name such as `'Inter'`, not a CSS-style stack.
- Keep the shell's `IndexedStack` keyless so tab state survives. Use `appPageRoute` for navigation. Pushes use horizontal `SharedAxisTransition`; pops use `FadeThroughTransition`; root-level pages may opt into `AppPageTransition.fadeThrough`. The left-edge swipe handles interactive back; do not reintroduce predictive-back branches by accident.
- Modal bottom sheets use `DraggableScrollableSheet` with `isScrollControlled: true` when they need drag/scroll behavior.
- Keep animations terminating; do not add repeating animations to widget-test trees. Stagger animations with controller `Interval`s rather than delayed timers. Cancel any hold timer in `dispose`.
- Markdown reading uses `MarkdownRenderer`, not `SmoothMarkdown`; keep it selectable and links/images tappable. Persisted document IDs must be deterministic, never Dart `hashCode`.
- Liquid glass uses `liquid_glass_widgets`. `GlassQuality.premium` is only for chrome that never transforms on screen (the floating bottom nav, dialogs); the premium path tracks sliding ancestors through its backdrop group and flashes black, so page headers, app bars, and anything inside a tab or page transition must stay on the default `standard`. The user intensity scales the full material via `LiquidGlassIntensity` — blur, tint, thickness, refractive index, specular light, and the `ambientRim` edge ring — not just blur and tint. Preserve the curated intensity setting and avoid committing slider previews on every drag frame.
- Android release builds need `INTERNET` permission in the main manifest. App update checks and downloads use normal platform TLS certificate validation; never add a certificate bypass.

## Changes and validation

- For application code changes, bump the patch version in `pubspec.yaml` unless the user gives a version. Increase its build number monotonically and sync `_fallbackBuildNumber` in `lib/features/settings/about_settings.dart`. Treat `pubspec.yaml` as the version source of truth; do not copy a current version or update URL into this guide. Include `(build N)` in a task commit subject.
- Inspect the actual path and relevant tests before editing. After manual Dart edits, re-read edited blocks for syntax, brackets, and commas. Use `git diff --check` for changed repository files.
- On this local machine, do not probe or run `dart`/`flutter` commands unless the user explicitly asks. Do not run `dart format`, `flutter analyze`, builds, or Flutter tests here by default. Report that local Flutter validation was skipped; CI runs lockfile, formatting, analysis, and tests on `main`/`test` and pull requests.
- If the user explicitly requests a local Flutter validation or build, use Flutter 3.44 and the relevant checks: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --fatal-infos`, `flutter test`, and the requested build target. Run only the checks needed for the request.
- For an opaque bug, reproduce the smallest case, trace the relevant code path including error handling, and verify the root cause. Read dependency internals only for package-sourced failures. Add targeted diagnostic logging or a visible degradation indicator only when it helps that failure; remove temporary diagnostics unless useful to keep. Write an offline script only when package behavior cannot be verified more simply. Follow the local Flutter-command rule above.

## Git and release boundaries

- For completed repository-file changes, commit only task files and push to `origin/test` by default, unless the user requests another destination or explicitly limits the task to local edits. Never force-push. If `origin/test` advanced, integrate before pushing and verify the requested remote state.
- A short word such as “run” is not release authorization. Build, GitHub Release, update-server upload, and `main` synchronization require an explicit full-release request. Do not infer them from a normal code change or a push to `test`.
- The normal full-release path is `.github/workflows/publish.yml` (dispatch defaults to `test`): it builds once, checks the `v<version>+<build>` tag, publishes notes and APK, uploads to the update server, then synchronizes `test` to `main`. Its branch synchronization is a workflow-specific behavior, not permission for an agent to force-push.
- Use a manual release path only when the user explicitly requests it or the workflow is unavailable. Match the workflow's tag/artifact contract, use secrets from an approved credential source, and never put tokens or update-server keys in this guide, command output, or a remote URL. Do not bypass TLS verification to make an upload work; diagnose certificate failures instead.
- If authentication blocks an explicitly requested push or release, explain the failure and ask for a safe credential path. Do not ask for credentials preemptively. Do not delete an existing release/tag or overwrite a divergent remote ref without explicit approval.
