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
- `pubspec.yaml`: `1.0.0+2` (versionName = 1.0.0, versionCode = 2)
- Update check URL: `https://alexxia.5imh.xyz/update/?request&local=2`
  - 204 No Content → already latest
  - 200 OK → new version available, download via browser

## GitHub
- Remote: `https://github.com/alexopenfan-xiaxin/jianxi-reader.git`
- Auth: Personal Access Token (via remote URL or GitHub API)
- Tag: `v1.0.0` → Release with APK asset

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
- `ClickableLinkBuilder` registered as the 'link' builder so links stay clickable inside `selectable: true` (default `LinkBuilder` wraps a `GestureDetector` in `WidgetSpan` which loses taps to `SelectionArea`; custom builder returns a `Text.rich` with `TapGestureRecognizer` on the span)
- "重命名" popup menu item is now always shown (not just for non-referenced files), since the rename service already supports external paths
