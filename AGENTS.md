# 简兮阅读器 — Agent Guide

## Project Overview
Flutter mobile reader for Markdown and HTML documents. Library management, reading settings, text selection, update check.

## Key Architecture
- **State management**: Provider (`LibraryController` in `lib/features/library/`, `AppSettingsController` in `lib/core/`)
- **Routing**: Direct `Navigator.push` (no routing library), `PageRouteBuilder` with slide transitions
- **Theme**: `AppTheme` in `lib/core/design_tokens.dart` — `getLightPalette()` / `getDarkPalette()`, `AppColors`, `AppSpacing`, `AppRadii`
- **Design tokens singleton**: `AppColors` (static colors), palette via `BuildContext` extension (`context.palette`)
- **Cards**: `AppCard` widget in `lib/core/widgets/app_card.dart`
- **File service**: `DocumentFileService` in `lib/core/document_file_service.dart` (scan, import, rename, remove, metadata)
- **Android permissions**: `INTERNET` required in `AndroidManifest.xml` for release builds (debug manifest has it, main manifest does not by default)
- **SSL**: `badCertificateCallback` bypasses certificate validation for update check server

## Project Structure
```
lib/
├── main.dart
├── app.dart                     # MultiProvider: AppSettingsController + LibraryController
├── core/
│   ├── design_tokens.dart       # Colors, spacing, radii, fontFamily, theme data
│   ├── emoji_service.dart        # Loads gemoji DB into Map<String,String> via rootBundle
│   ├── file_rules.dart          # DocumentType, extension validation, baseName validation
│   ├── document_file_service.dart  # DocumentLibraryService interface + DocumentFileService impl
│   ├── app_settings_controller.dart  # ThemeMode, ReadingFontSize, ReadingLineHeight
│   └── widgets/
│       ├── app_card.dart        # Reusable card (Material + InkWell)
│       ├── reading_settings_panel.dart  # Shared font-size/line-height settings
│       ├── palette.dart         # PaletteProvider + context.palette extension
│       └── app_icon.dart
├── features/
│   ├── shell/app_shell.dart     # IndexedStack (no key) + FloatingBottomNav
│   ├── library/
│   │   ├── library_page.dart    # Library list, search, sort, empty/error states
│   │   ├── library_controller.dart
│   │   ├── document_entry.dart  # DocumentEntry model (path, name, type, size, dates, isReferenced)
│   │   └── document_actions.dart  # Rename dialog, remove confirmation
│   ├── reader/
│   │   ├── reader_page.dart     # AppBar + LinearProgressIndicator + DraggableScrollableSheet
│   │   ├── markdown_viewer.dart # SmoothMarkdown (selectable: true, code highlight, Mermaid)
│   │   └── html_document_view.dart
│   └── settings/
│       └── settings_page.dart   # Theme, reading, about card + check update button
```

## Conventions
- No CSS-style font-family strings — use single font name (`'Inter'`)
- `IndexedStack` must NOT have a `key` parameter (preserves tab state)
- Modal bottom sheets should use `DraggableScrollableSheet` + `isScrollControlled: true`
- `SmoothMarkdown` uses `selectable: true` for text selection
- All navigation uses `PageRouteBuilder` with 300ms `easeOutCubic` slide
- HTTP requests use `dart:io` `HttpClient` with `badCertificateCallback` (server uses self-signed cert)
- Target Flutter compatibility is **Flutter 3.32.5** unless the user explicitly says otherwise. Do not use APIs introduced after that version; for example, `Color.withValues(alpha:)` is not available on 3.32.5, so use a compatible alternative such as `withOpacity(...)` when adjusting alpha.
- After any manual Dart edit, especially in large Flutter widget trees such as `markdown_viewer.dart`, re-read the edited block and verify every comma is syntactically valid. A stray/trailing comma outside a valid argument list, collection literal, parameter list, or enum entry is a real syntax error; do not dismiss it as formatting. If `dart format` / `flutter analyze` is unavailable, perform this comma/bracket/parenthesis review manually before committing.
- On this local machine, do not probe whether `dart` / `flutter` commands are available. Unless the user explicitly asks to run them, skip `dart format`, `flutter analyze`, builds, and Flutter tests here; rely on static review and state that these commands were skipped by local rule.

## Build & Run
```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --release --target-platform android-arm64 --split-per-abi
# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (~10MB)
```

Requires `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`.

## Version
- `pubspec.yaml`: `1.9.0+90` (versionName = 1.9.0, versionCode = 90)
- Update check URL: `https://alexxia.5imh.xyz/update/index.php?request&local=90`
  - 200 APK stream → new version available, download and install
  - 200 JSON → already latest or server message
  - 404 JSON → no APK available or file missing
- **Always bump version with every code change** (versionName = 1.X.Y, versionCode = monotonic integer)
- **IMPORTANT**: When bumping version, also update the in-app version display (`settings_page.dart`) AND the update check URL query param (`?request&local=N`) — all three must match. Also bump the `build` count in commit messages.
- If the user requests code changes but does not explicitly specify `versionName`, increment the patch version by one while keeping the build number monotonic as requested or inferred. Example: after `2.0.1+102`, the next unspecified versionName should be `2.0.2`, not another `2.0.1` build.

## GitHub
- Remote: `https://github.com/alexopenfan-xiaxin/jianxi-reader.git`
- Auth: Personal Access Token (via remote URL or GitHub API)
- Tags: `v1.0.0` (asset `app-arm64-v8a-release.apk`), `v1.0.1` (asset `app-arm64-v8a-release.apk`), `v1.1.3` (asset `app-arm64-v8a-release.apk`), `v1.1.4` (asset `app-arm64-v8a-release.apk`)

## Systematic Bug-Fixing Methodology

When facing an opaque bug, follow this process:

### 1. Reproduce & Isolate
- Identify the exact minimal reproduction case (e.g. a markdown file with one code block)
- Confirm the bug is **not** caused by test project errors (ignore pre-existing test failures in `test/`)

### 2. Trace the Execution Path
- Read the relevant source files end-to-end; don't skip `catch (_) {}` blocks
- For package-sourced failures, read the package source at `%PUB_CACHE%/hosted/pub.dev/<package>-<version>/lib/src/`

### 3. Add Diagnostic Logging
Use `debugPrint('[Tag] ...')` at each stage:
- Entry point / guard condition
- Before and after every `await` / async call
- Inside every `catch` block — silent catches are always suspicious

### 4. Add Visual Error Indicators
When a widget silently degrades (e.g. falls back from highlighted to plain text),
add a subtle on-screen indicator (tooltip + icon) so the failure is visible on device.

### 5. Write an Offline Verification Script
For package-level issues that don't require Flutter's `rootBundle`, write a
standalone `dart run` script that tests the package API directly:
```dart
import 'dart:convert';
import 'dart:io';
// Read JSON files from %PUB_CACHE%, parse, verify structure
```

### 6. Check Package Internals Against Usage
- Does the package have the assets/resources we assume? (check `pubspec.yaml` assets section)
- Does the version we depend on actually have the API surface we call?
- For `rootBundle.loadString(assetPath)`: verify the file exists in the package's asset directory

### 7. Fix Iteratively
1. Fix the **root cause** (remove invalid language entries → init succeeds)
2. Add **defensive code** (null-safe fallbacks) so future failures never produce
   silent invisible output
3. Verify with `flutter analyze` — only target zero new issues

### Concrete Example: Syntax Highlighting Dead
1. Symptom: code blocks display plain text, no error shown
2. Traced `_doInitialize` → `catch (_) {}` swallowed exception
3. Added `debugPrint` → saw `FlutterError: asset not found`
4. Read `syntax_highlight` source → `initialize()` loads
   `packages/syntax_highlight/grammars/$language.json` via `rootBundle`
5. Checked `%PUB_CACHE%/syntax_highlight-0.5.0/grammars/` → `cpp.json`, `c.json`,
   `ruby.json`, etc. don't exist
6. Wrote offline script → confirmed 6 of 20 listed languages have no grammar file
7. Fix: removed the 6 missing entries from `_supportedLanguages`; added logging;
   added orange ⚠ icon when init fails

## Key Decisions
- Removed key from IndexedStack (Bug 1: dynamic key destroyed tab state)
- Font family is single `'Inter'` not CSS stack (Bug 2: Flutter ignores CSS stacks)
- Extracted `ReadingSettingsPanel` to share between settings page and reader sheet
- `selectable: true` on SmoothMarkdown enables long-press copy
- `FocusManager.instance.primaryFocus?.unfocus()` before navigation dismisses keyboard
- Removed `isReferenced` check in `renameDocument` to allow renaming external files
- `badCertificateCallback` added because update server uses untrusted SSL certificate
- `INTERNET` permission added to main `AndroidManifest.xml` (debug has it, release didn't)
- APK ~10MB ARM64
- `ClickableLinkBuilder` registered as the 'link' builder so links stay clickable inside `selectable: true` (wraps a `Text` in `GestureDetector` with `HitTestBehavior.opaque`; the package's `renderInline` keeps non-text widgets as a `WidgetSpan`, so the `GestureDetector` survives the unwrap step that strips a plain `Text`)
- `TappableImageBuilder` registered as the 'image' builder (wraps cached network images or local assets in `GestureDetector` with `HitTestBehavior.opaque`; the package's inline renderer keeps it as a `WidgetSpan`, so the tap is captured even when the image is inline within a paragraph and `selectable: true` would otherwise route the gesture to the `SelectionArea`)
- "重命名" popup menu item is now always shown (not just for non-referenced files), since the rename service already supports external paths
- `BareUrlPlugin` registered as an inline parser plugin to autolink bare URLs (`http://`, `https://`, `ftp://`); trigger character is `h`, regex is `^(?:https?|ftp)://[^\s<>\[\]"`']+`; trailing `?!.,:*_~` is stripped per GFM autolink rule; returns a `LinkNode` so the existing `ClickableLinkBuilder` renders it as a tappable link
- Library `ListView` is wrapped in a `GestureDetector` with `HitTestBehavior.translucent` so tapping outside the search field dismisses focus (`FocusManager.instance.primaryFocus?.unfocus()`)
- Code highlighting uses `syntax_highlight` (serverpod) via custom `SyntaxHighlightCodeBlockBuilder`, replacing the built-in `EnhancedCodeBlockBuilder` (which used `flutter_highlight`/`highlight`); `useEnhancedComponents: false` since we register all builders manually
- `flutter_svg` used in `TappableImageBuilder` to render SVG images; network images are downloaded with a 15s timeout and cached under the app temp image cache before rendering
- `EmojiPlugin` from `flutter_smooth_markdown` registered for `:smile:` shortcode rendering; custom `EmojiBuilder` renders the resolved emoji character
- `IndentedOrderedListPlugin` parses indented ordered lists before the package default list parser, because `flutter_smooth_markdown` 0.7.2 trims list lines and otherwise flattens nested ordered sublists
- `syntax_highlight: ^0.5.0` added to `pubspec.yaml`
- `_supportedLanguages` must only contain languages with grammar files in `syntax_highlight-<version>/grammars/`; verify by checking `%PUB_CACHE%` — including a missing language causes `Highlighter.initialize()` to throw and silently disable ALL highlighting
- `_codeTextStyle()` derives fallback text color from `codeBlockDecoration` background luminance (`#E0E0E0` for dark bg, `#1E1E1E` for light bg) to prevent invisible code when highlighting fails
- `_initFailed` static flag + orange ⚠ `Tooltip` icon on code blocks so developers can visually identify when initialization silently failed
- Emoji shortcodes use `gemoji` database (`assets/emoji.json` from `github/gemoji`) with full aliases — loaded via `rootBundle.loadString` → `EmojiService.load()`; passed as `customEmojis` to the built-in `EmojiPlugin` constructor (which merges with defaults)
- `assets/` directory now contains both `poster.png` and `emoji.json`; assets section must list both in `pubspec.yaml`
- `file_paths.xml` now includes `<root-path>` to authorize FileProvider access to the entire app data directory (needed for APK install after download to `getApplicationDocumentsDirectory()`)
- `ScrollSafeMermaidBuilder` registered as `'mermaid'` builder; wraps `InteractiveViewer` in `Listener(HitTestBehavior.opaque)` so touch events inside the mermaid area do not propagate to the parent `SingleChildScrollView` — the `InteractiveViewer` handles pan/zoom without triggering page scroll
- File hot-reload uses `Timer.periodic(3s)` in `_MarkdownViewerState` to poll `lastModifiedSync()`; `_checkFileChanged` now logs errors and guards against deleted files

## Operation Boundaries

When the user says "只做这几件事" or explicitly scopes the task, do NOT perform any extra checks, fixes, or modifications beyond what was requested — even if you spot issues. This includes:

- Version checks (pubspec vs in-app display vs update URL)
- Code quality / linting / analysis
- Encoding fixes
- Changelog generation (only use user-provided changelog)
- Any git operation not explicitly listed

## Release Creation

- Prefer Dart script (`dart:io` `HttpClient` + `jsonEncode`) over `curl.exe` for creating releases with Chinese content — `curl.exe` / PowerShell have persistent UTF-8 encoding issues.
- Contributor defaults to `alexopenfan-xiaxin` unless otherwise specified.
