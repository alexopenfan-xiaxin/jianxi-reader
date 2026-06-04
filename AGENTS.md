# 简兮阅读器 — Agent Guide

## Project Overview
Flutter mobile reader for Markdown and HTML documents. Library management, reading settings, text selection.

## Key Architecture
- **State management**: Provider (`LibraryController` in `lib/features/library/`)
- **Routing**: Direct `Navigator.push` (no routing library), `PageRouteBuilder` with slide transitions
- **Theme**: `AppTheme` in `lib/core/design_tokens.dart` — `getLightPalette()` / `getDarkPalette()`, `AppColors`, `AppSpacing`, `AppRadii`
- **Design tokens singleton**: `AppColors` (static colors), palette via `BuildContext` extension (`context.palette`)
- **Cards**: `AppCard` widget in `lib/core/widgets/app_card.dart`

## Project Structure
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── design_tokens.dart         # Colors, spacing, radii, fontFamily, theme data
│   ├── file_rules.dart
│   └── widgets/
│       ├── app_card.dart          # Reusable card (Material + InkWell)
│       └── reading_settings_panel.dart  # Shared font-size/line-height settings
│       └── app_icon.dart
│       └── palette.dart           # PaletteProvider + context.palette extension
├── features/
│   ├── shell/app_shell.dart       # IndexedStack (no key) + FloatingBottomNav
│   ├── library/
│   │   ├── library_page.dart      # Library list, search, sort, empty/error states
│   │   ├── library_controller.dart
│   │   ├── document_entry.dart
│   │   └── document_actions.dart
│   ├── reader/
│   │   ├── reader_page.dart       # AppBar + LinearProgressIndicator + DraggableScrollableSheet
│   │   ├── markdown_viewer.dart   # SmoothMarkdown (selectable: true)
│   │   └── html_document_view.dart
│   └── settings/
│       └── settings_page.dart     # Reading settings + about card
```

## Conventions
- No CSS-style font-family strings — use single font name (`'Inter'`)
- `IndexedStack` must NOT have a `key` parameter (preserves tab state)
- Modal bottom sheets should use `DraggableScrollableSheet` + `isScrollControlled: true`
- `SmoothMarkdown` uses `selectable: true` for text selection
- All navigation uses `PageRouteBuilder` with 300ms `easeOutCubic` slide

## Build & Run
```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Key Decisions
- Removed key from IndexedStack (Bug 1: dynamic key destroyed tab state)
- Font family is single `'Inter'` not CSS stack (Bug 2: Flutter ignores CSS stacks)
- Extracted `ReadingSettingsPanel` to share between settings page and reader sheet
- `selectable: true` on SmoothMarkdown enables long-press copy
- `FocusManager.instance.primaryFocus?.unfocus()` before navigation dismisses keyboard
- APK ~10MB ARM64
