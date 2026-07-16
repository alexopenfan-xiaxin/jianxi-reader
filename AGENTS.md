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
- Target Flutter compatibility is **Flutter 3.44** unless the user explicitly says otherwise. Do not use APIs introduced after that version.
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
- `pubspec.yaml`: `2.4.1+141` (versionName = 2.4.1, versionCode = 141)
- Update check URL: `https://alexxia.5imh.xyz/update/index.php?request&local=141`
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

## Task Completion
- After completing a task that changes repository files, commit the completed changes and push them to `origin/test` unless the user explicitly requests another destination or says not to commit/push.
- Never force-push. If `origin/test` has advanced, integrate the task commit on top of the latest remote branch before pushing.
- Keep unrelated working-tree changes out of the task commit unless the user explicitly asks to include all changes.

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
- Code highlighting uses `highlight` via custom `SyntaxHighlightCodeBlockBuilder`; `useEnhancedComponents: false` since all builders are registered manually
- `flutter_svg` used in `TappableImageBuilder` to render SVG images; network images are downloaded with a 15s timeout and cached under the app temp image cache before rendering
- `EmojiPlugin` from `flutter_smooth_markdown` registered for `:smile:` shortcode rendering; custom `EmojiBuilder` renders the resolved emoji character
- `IndentedOrderedListPlugin` parses indented ordered lists before the package default list parser, because `flutter_smooth_markdown` 0.7.2 trims list lines and otherwise flattens nested ordered sublists
- `flutter_highlight: ^0.7.0` and `highlight: ^0.7.0` are direct dependencies; the parser registers its bundled language grammars synchronously
- Common Markdown fence aliases are normalized before highlighting (`sh`, `jsonc`, `postgresql`, `c++`, `csharp`, `ps1`, etc.)
- `_codeTextStyle()` derives fallback text color from `codeBlockDecoration` background luminance (`#E0E0E0` for dark bg, `#1E1E1E` for light bg) to prevent invisible code when highlighting fails
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

## Standard Workflow: Pull → Push → Build → Release → Upload

When the user says "run" or "拉取远端test分支来更新本地项目（同时推送到远端main），然后打包为apk发布为发行版，并上传到更新服务器", execute:

### 1. Fetch & Review
```
git fetch origin test
git log --oneline HEAD..origin/test
```
Check version in `pubspec.yaml`.

### 2. Pull & Merge
```
git pull origin test --no-edit
```
Resolve any merge conflicts (typically `pubspec.yaml` and `about_settings.dart` — take the incoming version).

### 3. Bump Version (if not already bumped by remote)
- `pubspec.yaml`: version line
- `android/local.properties`: `flutter.versionName` + `flutter.versionCode`
- `lib/features/settings/about_settings.dart`: `_fallbackBuildNumber`

Convention: patch +1 per release (e.g. 2.7.7+177 → 2.7.8+178). If remote bumps minor, keep that.

### 4. Commit & Push
```
git add -A
git commit -m "feat/fix/chore: description (build NNN)"
git push origin main
git push origin HEAD:test
```
If push fails with `Invalid username or token`, ask user for a new PAT and update remote URL:
```
git remote set-url origin https://<token>@github.com/alexopenfan-xiaxin/jianxi-reader.git
```

### 5. Build APK
```
flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation
```
Output: `build/app/outputs/flutter-apk/app-release.apk` (~34.9MB).

If build fails with Dart compilation error (`catch (Object error)` etc.), fix the syntax error and rebuild.

### 6. Tag
```
git tag -a v<version> -m "v<version>+<build> <short summary>"
git push origin v<version>
```

### 7. GitHub Release (Dart script)
Create a temporary Dart script with:
- Token from remote URL (or ask user)
- Changelog in Chinese with emoji categories (🚀 ⚡ 🐛 🔧)
- Tag name and APK asset upload (filename: `app-arm64-v8a-release.apk`)
- Use `badCertificateCallback` for HTTPS

### 8. Upload to Update Server
```
curl.exe -X POST -F "apk=@<apk_path>" -F "version=<build_number>" "https://alexxia.5imh.xyz/update/index.php?push&key=4NxP5oxQB4gBMSHAXOOzgjfWTr9QEDXF" --ssl-no-revoke --connect-timeout 30
```
Expected: `{"success":true}`
