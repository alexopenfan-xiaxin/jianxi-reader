# jianxi-reader

简兮，一个纯粹简洁的移动端 Markdown / HTML 阅读器。


没有广告，没有后台同步，没有账号体系。打开即读，读完即走。所有文档停留在本地，不联网、不追踪、不打扰。

<p align="center">
  <img src="https://img.shields.io/github/v/release/alexopenfan-xiaxin/jianxi-reader?style=flat-square&labelColor=ffffff&color=007AFF" alt="最新版本" />
  <img src="https://img.shields.io/badge/Android-5.0%2B-34C759?style=flat-square&logo=android&logoColor=white" alt="Android 5.0+" />
  <img src="https://img.shields.io/badge/Flutter-3.32-40D0FD?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/License-MIT-FF3B30?style=flat-square" alt="MIT" />
  <img src="https://img.shields.io/github/stars/alexopenfan-xiaxin/jianxi-reader?style=flat-square&color=FF9500&labelColor=ffffff" alt="Stars" />
</p>

## QQ交流群

[点击加入QQ交流群](https://qm.qq.com/q/IcQIMYOaQg)

## 诞生背景

现在由于codex和claude code的流行，我们有了在移动端远程控制的需求，日常工作中积累了大量的 Markdown 笔记和技术文档，手机上看：`没法用，浏览器要翻目录，笔记 APP 太重。简兮阅读器的目标只有一个——把手机变成一个干净的文档浏览器。

## 设计原则

- **本地优先**：所有文档保留在你的设备上，不经过任何服务器
- **格式原貌**：不转格式、不锁文件，直接渲染你手中的 `.md` 和 `.html`
- **操作可预期**：导入就是引用，重命名就是改文件名，移出就是删引用或删文件——所见即所得
- **配置不丢**：主题、字号、行高持久化，下次打开还是你的习惯

## 功能

| 功能 | 说明 |
|------|------|
| 📂 **文档导入** | 从文件管理器选取文档，或引用原始路径（不复制文件） |
| 📖 **Markdown 渲染** | 代码高亮、图片预览、链接打开、Mermaid 图表、脚注、上下标 |
| 🌐 **HTML 渲染** | 基于 WebView，保留完整 CSS 样式 |
| 🔍 **搜索排序** | 按名称或修改时间排序，支持实时搜索过滤 |
| 🎨 **主题切换** | 浅色 / 深色 / 跟随系统，棕色调 Sepia 护眼模式 |
| 🔠 **阅读定制** | 三种字号（16/18/21px） × 三种行高（1.42/1.58/1.74） |
| ✂️ **文本选择** | 长按选择，复制时自动剥离 Markdown 语法标记 |
| 📋 **文档管理** | 重命名任意文档、移出/删除、阅读进度记录 |
| 📊 **阅读进度** | 顶部进度条显示当前阅读位置 |
| 🔄 **检查更新** | 自动检测新版本，一键跳转下载 |

## 下载与安装

| 项目 | 说明 |
| --- | --- |
| 最新版本 | [GitHub Releases](https://github.com/alexopenfan-xiaxin/jianxi-reader/releases/latest) |
| 系统要求 | Android 5.0+ / API 21+ |
| 推荐系统 | Android 12+，可获得更完整的体验 |
| CPU 架构 | ARM64（v8a），64 位设备 |

安装 APK 时可能需要允许"安装未知来源应用"。

## 应用实机

![简兮阅读器](assets/poster.png)

## 技术栈

| 层级 | 选型 |
|------|------|
| 框架 | Flutter 3.32 |
| 语言 | Dart 3.8 |
| 状态管理 | Provider |
| Markdown | `flutter_smooth_markdown`（带代码高亮、Mermaid） |
| HTML | `webview_flutter` |
| 文件选择 | `file_picker` |
| 持久化 | `shared_preferences` |

## 构建

```bash
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

APK 输出：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

项目结构

```
lib/
├── main.dart                     # 入口
├── app.dart                      # Provider 注入 + MaterialApp
├── core/
│   ├── design_tokens.dart        # 颜色、间距、圆角、主题
│   ├── document_file_service.dart # 文件扫描/导入/重命名
│   ├── file_rules.dart           # 文档类型判断与文件名校验
│   ├── app_settings_controller.dart # 阅读设置
│   └── widgets/
│       ├── app_card.dart         # 卡片组件
│       ├── palette.dart          # 调色板
│       └── reading_settings_panel.dart # 字号/行高面板
├── features/
│   ├── shell/app_shell.dart      # 底部导航
│   ├── library/                  # 文档库（列表/搜索/排序/导入）
│   ├── reader/                   # 阅读器（Markdown + HTML + 进度）
│   └── settings/                 # 设置页（主题/阅读/关于/更新）
└── AGENTS.md                     # AI 辅助开发指南
```

许可

MIT
