# 简兮阅读器 (Jianxi Reader) 代码评审文档

**评审日期**: 2026-06-27  
**项目版本**: 2.7.6+176  
**评审范围**: 全项目代码库  
**技术栈**: Flutter 3.44+, Dart 3.8.0+, Provider

---

## 1. 项目概览

简兮阅读器是一款专注于 Markdown 和 HTML 文档阅读的移动端应用，采用 Flutter 开发，支持 Android 和 Windows 平台。项目具备以下核心功能：

- 文档库管理（扫描、导入、重命名、删除、标签管理）
- Markdown/HTML 渲染（支持代码高亮、Mermaid 图表、思维导图、Emoji）
- 阅读设置（主题、字号、行高、边距、字体）
- 文档内搜索、目录导航、阅读进度保存
- 应用内更新、缓存清理
- 液态玻璃视觉效果

### 项目结构

```
lib/
├── main.dart                          # 应用入口 + 全局错误处理
├── app.dart                           # 根组件 + Provider 配置
├── core/                              # 核心层
│   ├── design_tokens.dart             # 设计令牌（颜色、间距、动效）
│   ├── app_settings_controller.dart   # 应用设置状态管理
│   ├── document_file_service.dart     # 文档文件服务
│   ├── file_rules.dart                # 文件规则验证
│   ├── bookmark_service.dart          # 书签服务
│   ├── reading_progress_service.dart  # 阅读进度服务
│   ├── reading_history_service.dart   # 阅读历史服务
│   ├── search_index_service.dart      # 搜索索引服务
│   ├── collection_service.dart        # 合集服务
│   ├── emoji_service.dart             # Emoji 服务
│   ├── haptic_service.dart            # 触觉反馈服务
│   ├── document_identity.dart         # 文档身份标识
│   ├── library_metadata_store.dart    # 元数据存储
│   ├── metadata_migration.dart        # 元数据迁移
│   ├── document_error_describer.dart  # 错误描述
│   ├── spring_curve.dart              # 弹簧动画曲线
│   └── widgets/                       # 通用组件
│       ├── app_card.dart
│       ├── app_page_route.dart
│       ├── reading_settings_panel.dart
│       ├── liquid_glass.dart
│       └── glass_segmented_control.dart
└── features/                          # 功能层
    ├── shell/app_shell.dart           # 应用外壳（底部导航）
    ├── library/                       # 文档库模块
    ├── reader/                        # 阅读器模块
    │   ├── markdown/                 # Markdown 渲染
    │   │   ├── builders/             # 自定义构建器
    │   │   └── plugins/              # 自定义解析插件
    │   └── html_document_view.dart   # HTML 渲染（WebView）
    └── settings/                     # 设置模块
```

---

## 2. 架构设计评审

### 2.1 架构模式

**评分: ⭐⭐⭐⭐ (4/5)**

项目采用了清晰的分层架构：

| 层级 | 职责 | 实现方式 |
|------|------|----------|
| 表现层 | UI 组件、页面 | StatelessWidget/StatefulWidget |
| 状态层 | 状态管理、业务逻辑 | ChangeNotifier + Provider |
| 服务层 | 数据持久化、文件操作 | Service 类 |
| 领域层 | 数据模型 | Plain Dart Objects |

**优点:**
- ✅ 采用 Provider 进行状态管理，符合 Flutter 生态最佳实践
- ✅ 清晰的 feature-first 目录结构，功能模块内聚
- ✅ 核心服务通过抽象接口定义（如 `DocumentLibraryService`），便于测试和替换
- ✅ 设计令牌（Design Tokens）系统完善，支持主题切换
- ✅ 全局错误处理机制完善（`runZonedGuarded` + `FlutterError.onError` + 自定义 ErrorWidget）

**待改进:**
- ⚠️ 部分 Controller 承担了过多职责（如 `LibraryController` 同时管理文档列表、搜索、排序、标签）
- ⚠️ 服务层与 SharedPreferences 耦合较紧，缺少 Repository 抽象层

### 2.2 状态管理

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 正确使用 `ChangeNotifier` + `Consumer/Selector`，避免不必要的重建
- ✅ 使用 `Selector` 精确选择需要监听的状态片段（如 [app.dart:30-56](file:///workspace/lib/app.dart#L30-L56)）
- ✅ 计算属性缓存机制完善（如 `_cachedDocuments`、`_cachedDocumentsIgnoringSearch`）
- ✅ 状态变更前有相等性检查，避免无意义的 `notifyListeners()`

**待改进:**
- ⚠️ `ReaderPage` 中存在大量局部状态（超过 20 个状态变量），建议拆分
- ⚠️ 部分状态修改没有统一的入口，散落在各个方法中

### 2.3 依赖注入

**评分: ⭐⭐⭐ (3/5)**

**优点:**
- ✅ 通过 Provider 注入 Controller 和 Service
- ✅ [app.dart:12-15](file:///workspace/lib/app.dart#L12-L15) 支持注入 mock 服务用于测试

**待改进:**
- ⚠️ 部分服务直接使用静态方法（如 `ReadingProgressService.saveProgress()`），不利于单元测试
- ⚠️ 没有使用 get_it 等依赖注入框架，服务定位较为隐式

---

## 3. 代码质量评审

### 3.1 代码风格与规范

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 整体代码风格一致，符合 Dart/Flutter 规范
- ✅ 命名清晰，类名、方法名、变量名具有自描述性
- ✅ 合理使用空安全（Dart 3.0+ null safety）
- ✅ 使用了 `analysis_options.yaml` 启用 lints
- ✅ 常量构造函数使用得当，减少重建

**待改进:**
- ⚠️ 文件普遍偏长：
  - [document_file_service.dart](file:///workspace/lib/core/document_file_service.dart): 789 行
  - [markdown_viewer.dart](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart): 917 行
  - [reader_page.dart](file:///workspace/lib/features/reader/reader_page.dart): 1085 行
  - [about_settings.dart](file:///workspace/lib/features/settings/about_settings.dart): 812 行
- ⚠️ [about_settings.dart](file:///workspace/lib/features/settings/about_settings.dart) 使用 `part of` 但文件很长，建议拆分

### 3.2 错误处理

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 全局错误捕获完善（[main.dart:10-33](file:///workspace/lib/main.dart#L10-L33)）
- ✅ 提供了用户友好的错误卡片和重试按钮
- ✅ 异步操作普遍有 try-catch 保护
- ✅ 错误信息通过 `document_error_describer.dart` 转换为用户可理解的中文提示
- ✅ 方法通道调用有 `MissingPluginException` 处理

**待改进:**
- ⚠️ 部分 catch 块使用 `catch (_)` 或 `catch (error)` 后仅打印日志，没有向用户反馈：
  ```dart
  // document_file_service.dart:702-705
  } catch (error) {
    debugPrint('[DocumentFileService] remove old referenced mirror failed: $error');
  }
  ```
- ⚠️ [about_settings.dart:92-94](file:///workspace/lib/features/settings/about_settings.dart#L92-L94) 和 [117-119](file:///workspace/lib/features/settings/about_settings.dart#L117-L119) 使用空 catch 块静默忽略错误

### 3.3 类型安全

**评分: ⭐⭐⭐⭐⭐ (5/5)**

**优点:**
- ✅ 全面使用 Dart 空安全特性
- ✅ 合理使用 sealed classes / switch 表达式进行穷举检查
- ✅ 枚举使用完善（`ReadingTheme`、`ReadingFontFamily`、`LibrarySortMode` 等）
- ✅ 类型注解明确，没有滥用 `dynamic`

**示例：优秀的 switch 表达式使用**
```dart
// library_controller.dart:408-423
final result = switch (_sortMode) {
  LibrarySortMode.modifiedNewest => right.modifiedAt.compareTo(left.modifiedAt),
  LibrarySortMode.recentlyOpened => _compareNullableDateDesc(left.recentOpenedAt, right.recentOpenedAt),
  LibrarySortMode.name => left.name.toLowerCase().compareTo(right.name.toLowerCase()),
  // ...
};
```

---

## 4. 安全性评审

### 4.1 网络安全

**评分: ⭐⭐ (2/5) - 存在高风险问题**

**⚠️ 严重问题: SSL 证书验证被禁用**

在 [about_settings.dart:443-445](file:///workspace/lib/features/settings/about_settings.dart#L443-L445):

```dart
HttpClient _createUpdateClient() {
  final client = HttpClient();
  client.badCertificateCallback =
      (X509Certificate cert, String host, int port) => true;
  client.userAgent = 'JianxiReader/1.0';
  return client;
}
```

**风险:**
- `badCertificateCallback` 返回 `true` 会完全禁用 SSL 证书验证
- 应用更新功能容易受到中间人攻击（MITM）
- 攻击者可以替换 APK 文件，导致用户安装恶意应用

**建议修复:**
1. 使用受信任的 CA 颁发的证书
2. 实现证书锁定（Certificate Pinning）
3. 至少验证证书指纹或公钥

### 4.2 文件系统安全

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 文件名验证严格，防止路径遍历攻击（[file_rules.dart:44-56](file:///workspace/lib/core/file_rules.dart#L44-L56)）
- ✅ 拒绝 `.` 和 `..` 等保留名称
- ✅ 禁止非法文件名字符 `\ / : * ? " < > |`
- ✅ FileProvider 配置正确，`android:exported="false"`

**待改进:**
- ⚠️ AndroidManifest 中 Intent Filter 支持 `content://` scheme，需要确保对外部传入的 URI 进行充分验证

### 4.3 权限管理

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 仅申请必要权限：`INTERNET`、`REQUEST_INSTALL_PACKAGES`
- ✅ 安装未知应用有明确的权限请求流程（[about_settings.dart:327-362](file:///workspace/lib/features/settings/about_settings.dart#L327-L362)）
- ✅ 权限使用范围最小化

### 4.4 数据存储

**评分: ⭐⭐⭐ (3/5)**

**待改进:**
- ⚠️ 所有数据（包括阅读历史、书签）存储在 SharedPreferences 中，为明文存储
- ⚠️ 下载的 APK 直接存储在应用文档目录，没有完整性校验（如哈希校验）
- ⚠️ 更新检查应验证 APK 签名与当前应用一致

---

## 5. 性能评审

### 5.1 渲染性能

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 大文件分节渐进渲染（[markdown_viewer.dart:309-367](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart#L309-L367)）：
  - > 1MB 的 Markdown 文件自动分节
  - 初始渲染 3 节，滚动到 80% 时加载更多
- ✅ Markdown 解析在 isolate 中执行（`compute(_readMarkdownSnapshot, ...)`）
- ✅ 使用 `RepaintBoundary` 隔离重绘区域
- ✅ `const` 构造函数大量使用
- ✅ 搜索结果使用防抖（250ms debounce）
- ✅ 文件指纹检查（修改时间 + 文件大小）避免不必要的重新加载

**待改进:**
- ⚠️ [markdown_viewer.dart:654-667](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart#L654-L667) 搜索时重新解析整个 Markdown 文档，大文件可能卡顿
- ⚠️ 搜索匹配是简单的字符串匹配，没有使用更高效的算法（如 KMP）
- ⚠️ 文件监听同时使用了 `File.watch()` 和 5 秒轮询（[markdown_viewer.dart:180-184](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart#L180-L184)），存在冗余

### 5.2 内存管理

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 控制器、StreamSubscription、Timer 在 dispose 时正确取消
- ✅ 图片缓存有清理机制（缓存清理功能）
- ✅ `invalidateLibraryCache()` 及时释放缓存引用

**待改进:**
- ⚠️ `_headingKeys` Map 只在 TOC 变化时清理（`removeWhere`），可能遗留无用 key
- ⚠️ `_lastRefreshTimes` Map 没有大小限制或过期清理
- ⚠️ Emoji 数据库一次性加载到内存（emoji.json 可能较大）

### 5.3 列表性能

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 文档列表使用缓存机制，避免重复排序过滤
- ⚠️ 但未看到 `ListView.builder` 的具体使用，长列表可能需要进一步优化

---

## 6. 可维护性评审

### 6.1 代码复用

**评分: ⭐⭐⭐⭐ (4/5)**

**优点:**
- ✅ 设计令牌系统完善，颜色、间距、圆角、动效统一管理
- ✅ `AppCard`、`AppPageRoute`、`ReadingSettingsPanel` 等通用组件抽取合理
- ✅ Markdown 自定义构建器和插件模式扩展性强
- ✅ 错误描述统一在 `document_error_describer.dart` 管理

**待改进:**
- ⚠️ `_persist`、`_persistDouble` 等方法重复模式可以抽象
- ⚠️ 多个 fromName 方法（`_themeModeFromName`、`_readingThemeFromName` 等）逻辑高度重复，可泛型化
- ⚠️ 存在两份 `markdown_viewer.dart`（路径不同），容易混淆

### 6.2 可测试性

**评分: ⭐⭐⭐ (3/5)**

**优点:**
- ✅ 核心服务有接口抽象，支持 mock
- ✅ `JianxiReaderApp` 支持注入 mock 服务
- ✅ 有基础单元测试（文件规则、阅读进度、文档服务）

**待改进:**
- ⚠️ 测试覆盖率低：仅 4 个测试文件
- ⚠️ 没有 Widget 测试覆盖主要页面
- ⚠️ 静态方法（如 `ReadingProgressService.saveProgress`）难以 mock
- ⚠️ 大量 UI 逻辑在 State 类中，难以单独测试

### 6.3 文档与注释

**评分: ⭐⭐ (2/5)**

**待改进:**
- ⚠️ 代码中注释非常少，复杂算法没有解释
- ⚠️ 公共 API 缺少 dartdoc 文档注释
- ⚠️ `AGENTS.md` 存在但主要是开发指南，不是用户文档
- ⚠️ 没有架构决策记录（ADR）

**优点:**
- ✅ 部分关键逻辑有注释（如分节渲染、速率限制）

---

## 7. 具体问题清单

### 🔴 高优先级问题 (必须修复)

| # | 问题 | 位置 | 影响 |
|---|------|------|------|
| 1 | SSL 证书验证完全禁用 | [about_settings.dart:444](file:///workspace/lib/features/settings/about_settings.dart#L444) | 安全漏洞，更新可被中间人攻击 |
| 2 | switch 语句缺少 break（疑似逻辑错误） | [reader_page.dart:584-597](file:///workspace/lib/features/reader/reader_page.dart#L584-L597) | `bookmark` case 会穿透到 `rename` 和 `remove`，点击书签会同时弹出重命名或删除！ |
| 3 | 更新下载没有 APK 签名校验 | [about_settings.dart:205-325](file:///workspace/lib/features/settings/about_settings.dart#L205-L325) | 可能安装恶意篡改的 APK |

**问题 2 详细分析：**

```dart
// reader_page.dart:583-598
Future<void> _handleAction(_ReaderMenuAction action) async {
  switch (action) {
    case _ReaderMenuAction.bookmark:
      await _addBookmark();
      // 缺少 break; 或 return; 继续执行下一个 case！
    case _ReaderMenuAction.rename:
      final renamed = await showRenameDocumentDialog(context, _document);
      if (renamed != null && mounted) {
        setState(() => _document = renamed);
      }
      // 同样继续穿透
    case _ReaderMenuAction.remove:
      final removed = await removeDocumentFromLibrary(context, _document);
      if (removed && mounted) {
        Navigator.of(context).pop();
      }
  }
}
```

这是典型的 switch 穿透 bug！点击"添加书签"会依次执行 `_addBookmark()` → 弹出重命名对话框 → 弹出删除确认！

### 🟡 中优先级问题 (建议修复)

| # | 问题 | 位置 | 影响 |
|---|------|------|------|
| 4 | 空 catch 块静默吞错 | [about_settings.dart:92-94](file:///workspace/lib/features/settings/about_settings.dart#L92-L94) | 错误被隐藏，难以调试 |
| 5 | 部分文件过长（>700行） | 多个文件 | 可维护性下降 |
| 6 | 静态方法耦合 | `ReadingProgressService` 等 | 难以单元测试 |
| 7 | 文件监听冗余 | [markdown_viewer.dart:180-218](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart#L180-L218) | 同时用 Stream 和 Timer 轮询 |
| 8 | _fallbackBuildNumber 硬编码 | [about_settings.dart:70](file:///workspace/lib/features/settings/about_settings.dart#L70) | 版本号忘记更新会导致更新检查异常 |
| 9 | 没有日志持久化 | debugPrint 仅输出到控制台 | 无法收集用户侧错误 |
| 10 | SharedPreferences 无限制增长 | key 使用文件路径作为前缀 | 大量文档后可能变慢 |

### 🟢 低优先级问题 (可选优化)

| # | 问题 | 位置 |
|---|------|------|
| 11 | 魔法数字 | 多处硬编码数字（如 20、500ms、0.001）|
| 12 | 中文字符串硬编码在代码中 | 整个项目 |
| 13 | 重复的枚举 FromName 逻辑 | AppSettingsController |
| 14 | `about_settings.dart` 使用 part of 但过长 | about_settings.dart |
| 15 | 没有国际化支持 | 仅支持中文 |

---

## 8. 代码亮点 ✨

尽管存在上述问题，项目仍有许多值得称赞的优秀实践：

### 8.1 优秀的设计令牌系统
[design_tokens.dart](file:///workspace/lib/core/design_tokens.dart) 实现了完善的 Material 3 Theme Extension，暗色/亮色主题切换流畅，颜色、间距、圆角、动效曲线统一管理。

### 8.2 全局错误处理 + 应用重启
[main.dart:36-60](file:///workspace/lib/main.dart#L36-L60) 实现了优雅的错误边界和一键重启机制，用户体验良好：

```dart
class _RestartableApp extends StatefulWidget {
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartableAppState>()?.restart();
  }
  // ...
}
```

### 8.3 渐进式大文件渲染
[markdown_viewer.dart:309-367](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart#L309-L367) 针对 >1MB 的大文件实现了分节懒加载，避免 UI 卡顿。

### 8.4 完善的 Markdown 扩展能力
通过自定义 Builder 和 Plugin 系统，支持：
- 代码高亮（syntax_highlight）
- Mermaid 图表（带触摸事件隔离）
- 思维导图
- 下划线、高亮、上标、下标
- Bare URL 自动链接
- Emoji 短代码
- 可点击链接/图片

### 8.5 双阶段加载策略
[library_controller.dart:111-140](file:///workspace/lib/features/library/library_controller.dart#L111-L140) 先显示缓存立即响应，再后台刷新，用户体验流畅。

### 8.6 防抖+去重的状态更新
AppSettingsController 中所有 setter 都有相等性检查，避免无意义的持久化和通知。

### 8.7 液态玻璃视觉效果
[liquid_glass.dart](file:///workspace/lib/core/widgets/liquid_glass.dart) 实现了精致的毛玻璃效果，UI 品质高。

---

## 9. 改进建议

### 9.1 立即修复（高优先级）

1. **修复 switch 穿透 bug**：在 `_handleAction` 每个 case 末尾添加 `return;` 或使用独立的 if-else。

2. **改进 SSL 安全**：
   ```dart
   // 建议：至少固定证书公钥或SHA256指纹
   client.badCertificateCallback = (cert, host, port) {
     // 验证证书指纹
     final fingerprint = sha256.convert(cert.der).toString();
     return allowedFingerprints.contains(fingerprint);
   };
   ```

3. **添加 APK 完整性校验**：下载完成后校验签名或哈希值。

### 9.2 短期改进（中优先级）

4. **拆分大文件**：
   - `reader_page.dart` → 拆分出 `_ReaderAppBar`、`_ReaderBody`、`_ReaderSearch` 等
   - `document_file_service.dart` → 拆分出 Android 平台特定逻辑
   - `about_settings.dart` → 拆分更新、缓存清理为独立组件

5. **引入日志框架**：使用 `logger` 或 `f_logs` 替代直接 `debugPrint`，支持日志持久化和级别控制。

6. **抽象静态方法**：将 `ReadingProgressService` 等改为可注入的实例服务。

7. **移除冗余文件监听**：保留 `File.watch()` Stream 即可，错误时降级为轮询。

8. **版本号管理**：使用 `build_runner` 或从 `pubspec.yaml` 读取版本，避免硬编码 `_fallbackBuildNumber`。

### 9.3 长期演进

9. **引入路由库**：考虑使用 `go_router` 替代直接 `Navigator.push`，支持深度链接。

10. **增加国际化**：使用 `intl` 包实现多语言支持，字符串提取到 ARB 文件。

11. **提高测试覆盖率**：
    - 为核心 Controller 添加单元测试
    - 为主要页面添加 Widget 测试
    - 添加 Golden Test 验证 UI 一致性

12. **引入状态管理最佳实践**：考虑使用 `StateNotifier` + `freezed` 实现不可变状态，减少状态变更错误。

13. **添加崩溃报告**：集成 Sentry 或 Firebase Crashlytics 收集生产环境错误。

14. **数据库替换 SharedPreferences**：对于标签、书签、阅读历史等关系型数据，考虑使用 `isar` 或 `drift`。

---

## 10. 测试情况分析

### 现有测试
- [file_rules_test.dart](file:///workspace/test/file_rules_test.dart)：文件规则、错误描述、阅读进度、文档服务基础测试
- [app_settings_controller_test.dart](file:///workspace/test/app_settings_controller_test.dart)：设置控制器测试
- [library_page_test.dart](file:///workspace/test/library_page_test.dart)：文库页面测试
- [widget_test.dart](file:///workspace/test/widget_test.dart)：默认 Widget 测试

### 测试缺口
- ❌ Markdown 解析和渲染测试
- ❌ HTML 查看器测试
- ❌ 搜索功能测试
- ❌ 书签/历史服务测试
- ❌ 更新下载逻辑测试
- ❌ 平台通道（MethodChannel）测试
- ❌ 边缘情况测试（大文件、损坏文件、权限拒绝）
- ❌ 黄金测试（UI 一致性）

---

## 11. 总结与评分

| 维度 | 评分 (1-5) | 说明 |
|------|-----------|------|
| 架构设计 | ⭐⭐⭐⭐ | 分层清晰，模块划分合理 |
| 代码质量 | ⭐⭐⭐⭐ | 风格一致，类型安全，但部分文件过长 |
| 安全性 | ⭐⭐ | SSL 禁用是严重问题，需要立即修复 |
| 性能 | ⭐⭐⭐⭐ | 大文件渲染优化到位，有分节加载和isolate解析 |
| 可维护性 | ⭐⭐⭐ | 组件复用较好，但注释和测试不足 |
| 用户体验 | ⭐⭐⭐⭐⭐ | 动效精致，错误处理友好，液态玻璃效果出色 |
| **综合评分** | **⭐⭐⭐⭐ (3.6/5)** | 优秀的 Flutter 应用，修复关键安全问题后可投入生产 |

### 最终结论

简兮阅读器是一个**设计精良、功能完善**的 Flutter 阅读器应用。项目在 UI/UX 设计、Markdown 渲染扩展、性能优化（大文件分节、isolate 解析）等方面表现出色，代码整体质量较高。

**必须在发布前修复**：
1. 🔴 [reader_page.dart:584-597](file:///workspace/lib/features/reader/reader_page.dart#L584-L597) switch 穿透 bug（功能错误）
2. 🔴 [about_settings.dart:444](file:///workspace/lib/features/settings/about_settings.dart#L444) SSL 证书验证问题（安全漏洞）
3. 🔴 添加 APK 安装包完整性校验

修复上述关键问题后，项目具备生产发布的质量条件。建议后续版本重点改进测试覆盖率、错误日志收集和代码模块化拆分。

---

## 附录：关键文件快速索引

| 功能 | 文件 |
|------|------|
| 应用入口/全局错误处理 | [main.dart](file:///workspace/lib/main.dart) |
| 根组件/Provider配置 | [app.dart](file:///workspace/lib/app.dart) |
| 设计令牌/主题 | [design_tokens.dart](file:///workspace/lib/core/design_tokens.dart) |
| 应用设置 | [app_settings_controller.dart](file:///workspace/lib/core/app_settings_controller.dart) |
| 文档服务 | [document_file_service.dart](file:///workspace/lib/core/document_file_service.dart) |
| 文库控制器 | [library_controller.dart](file:///workspace/lib/features/library/library_controller.dart) |
| 阅读器页面 | [reader_page.dart](file:///workspace/lib/features/reader/reader_page.dart) |
| Markdown渲染器 | [markdown_viewer.dart](file:///workspace/lib/features/reader/markdown/markdown_viewer.dart) |
| 代码高亮构建器 | [syntax_highlight_code_block_builder.dart](file:///workspace/lib/features/reader/markdown/builders/syntax_highlight_code_block_builder.dart) |
| 应用更新/关于 | [about_settings.dart](file:///workspace/lib/features/settings/about_settings.dart) |
| 液态玻璃组件 | [liquid_glass.dart](file:///workspace/lib/core/widgets/liquid_glass.dart) |
