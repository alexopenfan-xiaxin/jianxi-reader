# jianxi-reader
一个纯粹简洁的移动端Markdown&amp;HTML阅读器

## 特性

- **双格式支持** — 流畅阅读 Markdown（`.md`/`.markdown`）和 HTML（`.html`/`.htm`）文档
- **本地文档管理** — 导入外部文件或引用原始路径，自动扫描沙盒目录
- **阅读定制** — 三种字号（紧凑/标准/大字）和三种行高（紧凑/舒适/宽松）
- **主题切换** — 浅色/深色/跟随系统，自带护眼的 **Sepia** 棕色调
- **文本选择** — 长按选择文本并复制到剪贴板（Markdown 自动去除语法标记）
- **文档排序** — 按修改时间或文件名排序，支持搜索过滤
- **可重命名** — 支持重命名已导入的任何文档

## 截图

<!-- 可在此插入海报或截图 -->
<!-- ![海报](assets/poster.png) -->

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.32 |
| 语言 | Dart 3.8 |
| 状态管理 | Provider |
| Markdown 渲染 | `flutter_smooth_markdown` |
| HTML 渲染 | `webview_flutter` |
| 文件选择 | `file_picker` |
| 持久化 | `shared_preferences` |

## 构建

```bash
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

APK 输出至 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。

## 项目结构

```
lib/
├── main.dart                     # 入口
├── app.dart                      # Provider 注入 + MaterialApp
├── core/
│   ├── design_tokens.dart        # 颜色、间距、圆角、主题数据
│   ├── document_file_service.dart # 文件扫描、导入、重命名
│   ├── file_rules.dart           # 文档类型判断、文件名校验
│   ├── app_settings_controller.dart # 阅读设置状态管理
│   └── widgets/
│       ├── app_card.dart         # 通用卡片组件
│       ├── palette.dart          # 调色板 Provider
│       └── reading_settings_panel.dart # 字号/行高设置面板
├── features/
│   ├── shell/app_shell.dart      # 底部导航 + IndexedStack
│   ├── library/
│   │   ├── library_page.dart     # 文档列表、搜索、排序
│   │   ├── library_controller.dart
│   │   ├── document_entry.dart
│   │   └── document_actions.dart
│   ├── reader/
│   │   ├── reader_page.dart      # 阅读器 + 进度条 + 设置面板
│   │   ├── markdown_viewer.dart  # Markdown 渲染（可选文本）
│   │   └── html_document_view.dart
│   └── settings/
│       └── settings_page.dart    # 外观、阅读设置、关于
└── AGENTS.md                     # AI 辅助开发指南
```

## 许可

MIT
