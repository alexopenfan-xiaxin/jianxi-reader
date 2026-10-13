# Liquid Glass 组件库替换计划

> 适用组件库：`liquid_glass_widgets` 0.30.2  
> 计划基线：`2.9.7+197`  
> 状态：规划文档。执行时按阶段拆 PR，不做一次性大爆炸替换。

## 0. 结论摘要

- 可行：组件库 0.30.2 的现成组件覆盖了项目当前几乎所有玻璃用法。
- 不建议把 `GlassScaffold` 当成总开关。它是页面结构层（appBar/bottomBar/body/背景/edge fade/安全区/z-order），不是材质替换层。
- 推荐路径：统一适配层 → 叶子控件 → 容器/卡片 → 浮层 → chrome/header → 可选的 `GlassScaffold`。
- 组件库的集中解析链让“统一替换”可行：
  - `GlassThemeHelpers.resolveSettings`：widget explicit → 最近的 `AdaptiveLiquidGlassLayer` 继承设置 → `LiquidGlassWidgets.globalSettings` → `GlassThemeData` → 默认值。
  - `GlassThemeHelpers.resolveQuality`：widget explicit → 继承层 quality → `GlassAdaptiveScope` 设备上限 → theme quality → 组件类默认值。
- 本次 build 197 已完成的 pre-work：
  - 液态玻璃底部 tab 使用 `GlassTabBar.bottom`；
  - 底部 tab 宽度恢复到 2.9.5 的 160px（`tabWidth: 80` × 2、`horizontalPadding: 0`、外层 `SizedBox(width: 160)`）；
  - 删除自定义玻璃强度滑杆，玻璃强度固定为 `AppSettingsController.liquidGlassIntensityDefault`（0.72）。
- 不动的部分：经典模式 fallback、Markdown 渲染/选区/滚动锚定、TOC、搜索索引、阅读器内容路径。

## 1. 目标与非目标

### 1.1 目标

1. 液态玻璃模式下，玻璃材质优先使用组件库现成组件，而不是继续维护自研 `LiquidGlass*` 实现。
2. 保留项目现有视觉语言、交互和可访问性；允许对组件做尺寸、颜色、圆角、间距和部分参数的微调。
3. 保留经典模式（`AppVisualMode.classic`）的现有 Material/fallback 外观。
4. 为后续评估和接入 `GlassScaffold` 留出结构，但不把它作为第一阶段目标。
5. 保持 `premium` 只用于静态 chrome；任何在 tab/page transition、滚动、拖拽中的玻璃 surface 使用 `standard`，避免黑闪和性能问题。

### 1.2 非目标

1. 不改 Markdown 解析、渲染、选区、滚动锚定、TOC 修正、per-section 搜索索引。
2. 不改文档 ID、书签、历史、元数据存储。
3. 不引入组件库大版本升级；当前仍按 0.30.2 设计。
4. 不做发行流程、不打 tag、不创建 Release。
5. 不要求一次性把所有页面改成 `GlassScaffold`。

## 2. 当前玻璃用法盘点

### 2.1 共享玻璃层（优先级最高）

| 文件 | 现有内容 | 角色 |
|---|---|---|
| `lib/core/widgets/liquid_glass.dart` | `LiquidGlassSurface`、`LiquidGlassPanel`、`LiquidGlassSheetPanel`、`LiquidGlassDialog`、`LiquidGlassChip`、`LiquidGlassIconTile`、`LiquidGlassTextFieldFrame`、`LiquidGlassTokens`、`LiquidGlassIntensity` | 统一材质与包装层 |
| `lib/core/widgets/app_card.dart` | 经典卡片与玻璃卡片分支 | 列表/入口卡片 |
| `lib/core/widgets/glass_segmented_control.dart` | 自研玻璃分段控件 | 设置/阅读选项 |
| `lib/core/widgets/reading_settings_panel.dart` | 阅读设置面板、`LiquidGlassChip`、`LiquidGlassSurface` | 阅读设置 |
| `lib/core/widgets/success_check.dart` | `BackdropFilter` 反馈层 | 成功反馈 |
| `lib/core/widgets/glass_intensity_slider.dart` | 自定义玻璃强度滑杆 | 已在 build 197 删除 |

### 2.2 直接调用点

| 文件 | 玻璃用法 | 目标迁移阶段 |
|---|---|---|
| `lib/features/shell/app_shell.dart` | `GlassTabBar.bottom`、`GlassIsolationScope`、经典模式 `BackdropFilter` | Phase 0/4 |
| `lib/features/library/library_toolbar.dart` | 玻璃头部、`LiquidGlassSurface`、`LiquidGlassPanel`、sheet | Phase 2/4 |
| `lib/features/library/library_page.dart` | `LiquidGlassDialog`、`LiquidGlassSheetPanel` | Phase 3 |
| `lib/features/library/library_search_page.dart` | `LiquidGlassTextFieldFrame`、`LiquidGlassChip` | Phase 1/3 |
| `lib/features/library/library_list_view.dart` | chip、dialog、sheet、text field、`BackdropFilter` | Phase 1/3 |
| `lib/features/library/document_actions.dart` | dialog、text field | Phase 3 |
| `lib/features/settings/settings_page.dart` | 玻璃头部、`LiquidGlassSurface`、`BackdropFilter` | Phase 4 |
| `lib/features/settings/appearance_settings.dart` | `LiquidGlassIconTile`、`GlassSegmentedControl` | Phase 1/2 |
| `lib/features/settings/about_settings.dart` | dialog、`LiquidGlassSurface` | Phase 2/3 |
| `lib/features/reader/reader_page.dart` | 玻璃 app bar、dialog、sheet、text field | Phase 4/3 |
| `lib/features/reader/markdown/markdown_viewer.dart` | `LiquidGlassDialog` | Phase 3 |

### 2.3 必须保留的约束

- `IndexedStack` 必须保持 keyless，tab 状态不能因替换而丢失。
- 头部/工具栏若仍在 `_TabEntrance` 或页面转场中，必须保持 `standard` quality。
- 浮层拖拽中的 sheet 必须保持 `standard`；静态 dialog/panel 才可 `premium`。
- Modal bottom sheet 继续使用 `DraggableScrollableSheet` + `isScrollControlled: true`，除非明确验证组件库 sheet 行为可替代。
- 玻璃强度固定 0.72；自定义强度滑杆已删除，不要重新引入“自定义模式”分叉。

## 3. 组件库能力与关键机制

### 3.1 现成组件清单（0.30.2）

- Containers：`GlassCard`、`GlassContainer`、`GlassGroupedSection`、`GlassListTile`、`GlassDivider`、`GlassStepper`
- Input：`GlassTextField`、`GlassTextArea`、`GlassFormField`、`GlassSearchBar`、`GlassPasswordField`、`GlassPicker`
- Interactive：`GlassButton`、`GlassIconButton`、`GlassChip`、`GlassSegmentedControl`、`GlassSlider`、`GlassSwitch`、`GlassBadge`、`GlassButtonGroup`、`GlassPullDownButton`
- Overlays：`GlassDialog`、`GlassActionSheet`、`GlassMenu`、`GlassSheet`、`GlassModalSheet`、`GlassPopover`、`GlassToast`
- Surfaces：`GlassScaffold`、`GlassPage`、`GlassAppBar`、`GlassToolbar`、`GlassLargeTitle`、`GlassTabBar`、`GlassBottomBar`
- Feedback/Effects：`GlassProgressIndicator`、`ProgressiveBlur`

### 3.2 材质解析链

`GlassThemeHelpers.resolveSettings`：

1. widget 显式 `settings`
2. 最近的 `AdaptiveLiquidGlassLayer` 继承设置
3. `LiquidGlassWidgets.globalSettings`
4. `GlassThemeData.settingsFor(context)` 的 partial override
5. 组件默认值

执行建议：使用完整 `LiquidGlassSettings`（不是 `GlassThemeSettings`）承载强度适配，因为 `GlassThemeSettings` 没有 `ambientRim`、`whitenStrength`、`whitenGated` 等字段，会丢当前材质通道。

### 3.3 质量解析链

`GlassThemeHelpers.resolveQuality`：

1. widget `quality`
2. 继承 `AdaptiveLiquidGlassLayer` quality
3. `GlassAdaptiveScope` 设备上限
4. `GlassThemeData` variant quality
5. 组件类默认值

执行建议：静态 chrome 显式 `premium`；动画/滚动/转场中的 surface 显式 `standard`；需要强制上限时使用 `GlassAdaptiveScope`。

### 3.4 组合规则：Glass is a platter, not a wrapper

- `GlassCard` / `GlassContainer` 是基础表面，会给子树设置 `avoidsRefraction: true`。
- 不要把 `GlassSegmentedControl`、`GlassSlider`、`GlassSwitch`、`GlassButton` 等交互玻璃控件嵌进 `GlassCard` / `GlassContainer`。
- 正确结构：
  - `GlassCard` / `GlassContainer` 内只放 `Text`、`Icon`、`ListTile`、标准 Flutter 表单控件。
  - 交互玻璃控件自己管理表面，外层不要再套玻璃容器。
  - 设置分组使用 `GlassGroupedSection` + `GlassListTile` + `GlassDivider`。
- 迁移时不要机械一对一；先判断“基础表面”还是“交互控件”。

### 3.5 内部默认/旁路组件

这些组件不遵循上面的主题/继承 settings，需要显式传参或接受默认值：

| 组件 | 行为 | 迁移策略 |
|---|---|---|
| `GlassTabBar.bottom` | `settings ?? kBottomBarGlassDefaults` | 已是默认观感；若要跟强度适配，需要显式传 settings |
| `GlassToolbar` | `settings ?? _defaultSettings`，quality fallback premium | 头部替换时显式传 settings/quality |
| `GlassAppBar` | 本身是透明布局容器，玻璃效果来自内部 `GlassButton`/`GlassIconButton` | 不要把它当作玻璃条；玻璃条用 `GlassToolbar` |
| `GlassDialog` | `GlassDialog.show` 默认 `quality: standard`，默认 `maxWidth: 280` | 迁移时按内容调 `maxWidth`、settings、quality |
| `GlassSheet` | 自带 drag/stretch/scroll，`show` 默认 standard | 与现有 `DraggableScrollableSheet` 行为要逐项验证 |

## 4. 替换映射表

| 现有 | 目标 | 直接/微调 | 注意事项 |
|---|---|---|---|
| `LiquidGlassSurface`（通用） | `AdaptiveGlass` 或 `GlassContainer` / `GlassCard` | 微调 | 自定义 chrome 用 `AdaptiveGlass`；基础表面用 Container/Card；不要嵌套玻璃控件 |
| `LiquidGlassPanel` | `GlassContainer` / `GlassCard` | 直接 | 传完整 settings；注意圆角/内边距 |
| `LiquidGlassDialog` | `GlassDialog` + `GlassDialogAction` / `GlassDialog.show` | 微调 | 1–3 actions、默认 maxWidth 280、content 支持自定义；barrier/动画可能与 Material `showDialog` 不同 |
| `LiquidGlassSheetPanel` + `DraggableScrollableSheet` | `GlassSheet.show` / `GlassModalSheet` / `GlassActionSheet` / `GlassMenu` | 微调 | 按行为拆分；若保留现有 host，则内部换 `GlassContainer` |
| `LiquidGlassChip` | `GlassChip` | 直接 | 检查 selected/删除交互 |
| 自研 `GlassSegmentedControl` | `GlassSegmentedControl` | 微调 | 泛型 `GlassSegment<T>` 需适配 |
| `LiquidGlassTextFieldFrame` | `GlassTextField` / `GlassTextArea` / `GlassFormField` | 微调 | controller、校验、autofocus、键盘行为要逐项验证 |
| `LiquidGlassIconTile` | `GlassIconButton` / `GlassButton` | 直接 | 尺寸/布局微调 |
| 自定义玻璃强度滑杆 | 无（固定 0.72） | 已删除 | 不要再恢复 custom 模式 |
| 头部/工具栏 | `GlassToolbar` + `GlassButton`；`GlassAppBar` 仅透明导航 | 微调 | `GlassToolbar` 有 surface；`GlassAppBar` 不是玻璃条；动画头部保持 standard |
| 卡片/设置分组 | `GlassCard` / `GlassGroupedSection` / `GlassListTile` / `GlassDivider` | 微调 | 遵守反嵌套规则 |
| Shell/底栏 | `GlassTabBar.bottom`（已用）；`GlassScaffold` 后期可选 | 分阶段 | 见第 7 节 |
| 经典模式 `BackdropFilter` | 保留 | 不动 | 只服务 classic 模式，不属于液态玻璃迁移 |

## 5. 目标架构

### 5.1 AppGlassSettings 适配层

新增一个共享适配器（示意）：

```dart
enum AppGlassRole {
  staticChrome,
  animatedChrome,
  staticPanel,
  draggedSurface,
  interactiveControl,
  groupedCard,
}

LiquidGlassSettings buildAppGlassSettings(
  BuildContext context, {
  required AppGlassRole role,
}) {
  final intensity = context
      .select<AppSettingsController, double>((s) => s.liquidGlassIntensityValue);
  // 使用 LiquidGlassIntensity 的缩放函数 + LiquidGlassTokens，
  // 返回完整 LiquidGlassSettings（包含 ambientRim/whiten 等通道）。
}
```

注入方式优先级：

1. 优先在页面/壳顶层传 `GlassPage.settings` 或 `GlassScaffold.settings`，让后代继承；
2. 次选 `LiquidGlassWidgets.globalSettings`（app 级 fallback）；
3. 需要覆盖的单个组件显式传 `settings`；
4. 不要同时维护多份“材质来源”，否则很难排查视觉差异。

### 5.2 Surface role 与 quality 策略

| Role | 示例 | quality | 备注 |
|---|---|---|---|
| staticChrome | 底部 tab、静态 toolbar | premium | 不能有滑动祖先 |
| animatedChrome | `_TabEntrance` 内头部、转场中的 toolbar | standard | 防 premium 黑闪 |
| staticPanel | dialog、静止 panel | premium | 可承受较高成本 |
| draggedSurface | DraggableScrollableSheet、可拖拽面板 | standard | 每帧重捕获 |
| interactiveControl | segmented control、slider、chip | standard | 动画/物理反馈 |
| groupedCard | 卡片、设置分组 | standard | 避免高成本 + 反嵌套 |

### 5.3 Wrapper 策略

不要在每个业务页面直接改成组件库命名组件；优先重写共享包装：

- `LiquidGlassSurface` → `AppGlassSurface`（内部选 `AdaptiveGlass`/`GlassContainer`）
- `LiquidGlassPanel` → `AppGlassPanel`（`GlassContainer`/`GlassCard`）
- `LiquidGlassDialog` → `AppGlassDialog`（内部 `GlassDialog`）
- `LiquidGlassSheetPanel` → `AppGlassSheetPanel`（内部 `GlassSheet` 或 `GlassContainer`）
- `LiquidGlassChip` → `AppGlassChip`（`GlassChip`）
- `LiquidGlassTextFieldFrame` → `AppGlassTextField`（`GlassTextField`）
- 自研 `GlassSegmentedControl` → `AppGlassSegmentedControl`（`GlassSegmentedControl`）

每个 wrapper 内部按 `liquidGlassEnabled` 分支：液态玻璃模式用组件库组件；经典模式保持现有 Material/fallback。这样业务调用点基本不动，也方便逐 surface 回滚。

### 5.4 不要做的事

- 不要全局把 `LiquidGlassSurface` 都换成 `GlassCard`：很多 surface 是自定义 chrome，不是 card。
- 不要在 `GlassCard`/`GlassContainer` 内继续放玻璃控件。
- 不要为了“统一”把底部 tab 再改成 full-width；当前 160px 是 2.9.5 的恢复值。
- 不要在经典模式使用组件库玻璃组件；保持 classic fallback。
- 不要在没有验证 SnackBar/键盘/横屏前把 shell 根 `Scaffold` 换成 `GlassScaffold`。

## 6. 分阶段执行计划

### Phase 0：适配层与基线（本阶段先做）

**目标**：不改视觉，只建立统一 settings/quality 注入点。

- 新增 `AppGlassSettings` / `AppGlassRole`。
- 在 `main.dart` 的 `LiquidGlassWidgets.wrap` 处接入 theme 或 globalSettings。
- 增加 role → quality 的策略映射。
- 保持底部 tab 现有 `GlassTabBar.bottom` 默认材质；宽度仍为 160px。
- 验收：
  - 现有界面视觉与 build 197 基线一致；
  - 强度固定 0.72；
  - `flutter analyze --fatal-infos`、`flutter test` 通过；
  - 不新增 premium 黑闪。
- 回滚：适配层只新增不删除，删除即可回到现状。

### Phase 1：叶子控件

**范围**：segmented control、chip、text field、button/icon button。

- `glass_segmented_control.dart` → `GlassSegmentedControl` 适配。
- `LiquidGlassChip` → `GlassChip`。
- `LiquidGlassTextFieldFrame` → `GlassTextField` / `GlassTextArea`。
- `LiquidGlassIconTile` → `GlassIconButton` / `GlassButton`。
- 验收：
  - 设置页 segmented control 选中态/动效正常；
  - 文库搜索/标签输入法、键盘、focus 正常；
  - 文档操作对话框的输入/校验/autofocus 正常；
  - 无玻璃嵌套反模式。
- 风险：组件 API 参数差异、键盘 inset、dialog 宽度。
- 回滚：wrapper 内部按 surface 开关回退旧实现。

### Phase 2：容器/卡片/设置分组

**范围**：`LiquidGlassSurface`、`LiquidGlassPanel`、`app_card.dart`、设置卡片。

- 基础表面 → `GlassContainer` / `GlassCard`。
- 设置分组 → `GlassGroupedSection` + `GlassListTile` + `GlassDivider`。
- 自定义 chrome（头部等）继续用 `AdaptiveGlass`，不要硬塞 card。
- 验收：
  - 列表滚动性能不退化；
  - 卡片圆角/阴影/内边距符合设计；
  - 反嵌套规则通过 code review；
  - classic 模式外观不变。
- 风险：`avoidsRefraction` 导致内部玻璃控件退化；卡片 own-layer clip 裁 jelly。
- 回滚：`AppGlassSurface` 切回 `AdaptiveGlass` 或旧 `LiquidGlassSurface`。

### Phase 3：浮层（dialogs / sheets / menus）

**范围**：`LiquidGlassDialog`、`LiquidGlassSheetPanel`、文库/阅读器菜单。

- `LiquidGlassDialog` → `GlassDialog` / `GlassDialog.show`。
- 文档菜单 → `GlassMenu` / `GlassActionSheet`。
- 底部 sheet：
  - 优先保留现有 `showModalBottomSheet` + `DraggableScrollableSheet` host，内部换 `GlassSheet` / `GlassContainer`；
  - 或者单独验证 `GlassSheet.show` 的 drag/stretch/scroll 后迁移。
- 验收：
  - 1–3 actions 的 dialog 布局正常；
  - sheet 拖拽、键盘、返回手势、barrier 行为正常；
  - 不破坏 `isScrollControlled`/`DraggableScrollableSheet` 约束。
- 风险：`GlassSheet.show` 用 `showGeneralDialog` + 自己的 stretch/scroll；和现有交互差异大。
- 回滚：保留原 host，仅替换面板内容。

### Phase 4：chrome / header

**范围**：文库头部、设置头部、阅读器 app bar、工具栏。

- 玻璃条 → `GlassToolbar(settings:, quality:)` + `GlassButton` / `GlassIconButton`。
- 透明导航 → `GlassAppBar` + 玻璃按钮（注意 `GlassAppBar` 本身不是玻璃条）。
- 动画 tab 内的头部继续用 `standard`；静态 chrome 可 `premium`。
- 验收：
  - tab 切换无 premium 黑闪；
  - 阅读器滚动显隐、返回、书签、菜单正常；
  - 浅色/深色玻璃可读性正常。
- 风险：`GlassAppBar` 语义和现有自定义头部不同；`GlassToolbar` 默认 settings 需要显式覆盖。
- 回滚：保留现有头部，只把内部按钮换成组件库按钮。

### Phase 5：GlassScaffold（可选，最后做）

**范围**：先独立页面（关于页/设置子页），再 shell。

- 先在一个页面用 `GlassScaffold + GlassToolbar/GlassAppBar + body` 试点。
- 解决 SnackBar、键盘、返回、Android/web/windows 验证后，再评估 shell 级替换。
- 验收：
  - SnackBar/ScaffoldMessenger 仍正常；
  - `resizeToAvoidBottomInset` / `viewInsets` 正确；
  - 横屏 `NavigationRail` 不回归；
  - 经典/液态玻璃模式切换不导致 `IndexedStack` 重挂载。
- 风险：`GlassScaffold` 内部是 `CupertinoPageScaffold`，不是 Material `Scaffold`；这是本计划中风险最高的阶段。

## 7. GlassScaffold 专项评估

### 7.1 能提供什么

- `GlassPage` 背景/玻璃层/状态栏；
- appBar/bottomBar/body 的 z-order；
- 自动 edge fade、body 边缘留白、SafeArea；
- appBar/bottomBar 外层的 `GlassIsolationScope(isolated: true, defaultQuality: premium)`；
- `header`、`bodyOverlays`、`contentAwareBrightness`、`edgeToEdge` 等。

### 7.2 对本项目的阻塞项

1. **SnackBar/ScaffoldMessenger**：`GlassScaffold` 使用 `CupertinoPageScaffold`。项目有大量 `ScaffoldMessenger.of(context).showSnackBar(...)`，换根后 shell 层级 SnackBar 可能没有可注册的 Material Scaffold。
2. **per-tab 动画头部**：头部目前在 `_TabEntrance` + `IndexedStack` 内，必须 `standard`；`GlassScaffold.appBar` 是静态槽位，并默认 premium 隔离，直接搬入会改变动效并引入黑闪风险。
3. **模式切换**：经典模式根是 Material `Scaffold`；玻璃模式若换成 `GlassScaffold`，根 widget 类型变化会重挂载 `IndexedStack`，可能丢 tab 状态。
4. **键盘/安全区/弹窗**：`CupertinoPageScaffold` 的 `resizeToAvoidBottomInset`/`viewInsets` 与 Material `Scaffold` 行为不同，Android/web/windows 都要 QA。
5. **横屏 rail**：`GlassScaffold` 没有 rail 槽位；保留在 body Row 里即可，但 bottomBar 横屏要置空。
6. **底部导航**：当前已在 shell 用 `GlassIsolationScope` + SafeArea 包了 `GlassTabBar.bottom`，GlassScaffold 对底栏的增量只剩 edge fade/自动 padding，性价比不高。

### 7.3 推荐用法

- 不要一步替换 shell 根 `Scaffold`。
- 先在独立页面/子页面使用 `GlassScaffold + GlassToolbar/GlassAppBar` 试点。
- 保留 Material `Scaffold` 作为 SnackBar/键盘兼容层，或改用 `GlassToast` 替代 SnackBar。
- 等 Phase 1–4 稳定后再评估 shell 级 `GlassScaffold`。

## 8. 测试与验收矩阵

| 维度 | 检查 |
|---|---|
| 格式 | `dart format --output=none --set-exit-if-changed lib test` |
| 分析 | `flutter analyze --fatal-infos` |
| 单测 | `flutter test` |
| Widget | tab 切换、模式切换、IndexedStack 状态保持、dialog/sheet 打开关闭 |
| 视觉 | Android 真机浅色/深色、premium 黑闪、玻璃头部、底栏 160px |
| 输入 | 搜索框、文档名输入、标签输入、键盘 inset、autofocus |
| 浮层 | dialog、DraggableScrollableSheet、菜单、返回键/手势 |
| 性能 | 列表滚动、tab 切换、sheet 拖拽、内存/掉帧 |
| 平台 | Android、Web、Windows；注意 Windows/Linux adaptive quality 可能 cap 到 standard |
| 可访问性 | semantics、TalkBack/VoiceOver、动态字体、对比度 |
| 回归 | 经典模式不变、Markdown 选择/锚点/TOC/搜索不回归、版本号/fallback build 同步 |

## 9. 风险与回滚

| 风险 | 影响 | 缓解/回滚 |
|---|---|---|
| 玻璃嵌套反模式 | 折射退化、jelly 裁剪 | 先做角色分类；容器只放非玻璃内容 |
| premium 黑闪 | 转场/滑动头部发黑 | 头部/动画 surface 一律 standard；必要时 GlassAdaptiveScope |
| settings 覆盖错误 | 视觉不一致、强度失效 | 单一 AppGlassSettings 来源；组件显式 override 要注释原因 |
| sheet 行为差异 | 拖拽/键盘/返回异常 | 保留原 host；组件只做面板内容 |
| GlassScaffold 根替换 | SnackBar/键盘/状态重挂载 | 最后阶段；保留 Material Scaffold 兼容层 |
| 测试 shader warm-up | `pumpAndSettle`/shader 初始化问题 | 复用现有测试策略；必要时在测试 setUp 初始化 |
| 组件库升级 | API/默认值漂移 | 锁 0.30.2；升级单独 PR + 视觉回归 |

## 10. 文件级 TODO 清单

- [x] `lib/core/widgets/liquid_glass.dart`：新增 `AppGlassRole`/`AppGlassSettings` 单一 material/quality 解析链；`LiquidGlassSurface` 仍用 `AdaptiveGlass` 作自定义 chrome 回退，panel/icon tile/text field/chip/dialog 已接组件库。
- [x] `lib/core/widgets/app_card.dart`：玻璃分支接 `GlassCard`。
- [x] `lib/core/widgets/glass_segmented_control.dart`：玻璃模式接 `GlassSegmentedControl`；经典模式保留原 Material/backdrop 实现。
- [x] `lib/core/widgets/reading_settings_panel.dart`：chip 与 segmented control 已走组件库；预览面板保留 `AdaptiveGlass`。
- [x] `lib/features/shell/app_shell.dart`：保持 `GlassTabBar.bottom` 160px 与库默认材质；Phase 5（GlassScaffold）本次不执行。
- [x] `lib/features/library/library_toolbar.dart`：头部 glass surface 保留 `AdaptiveGlass`，操作按钮接 `GlassIconButton`；排序菜单接 `showGlassActionSheet`。
- [x] `lib/features/library/library_page.dart`：dialog 接 `GlassDialog`；sheet 保留原 host，面板接组件库 `AdaptiveGlass` 原语。
- [x] `lib/features/library/library_search_page.dart`：text field frame 接 `GlassContainer`，chip 走 `LiquidGlassChip`→`GlassChip`。
- [x] `lib/features/library/library_list_view.dart`：文档菜单接 `showGlassActionSheet`；chip/dialog/text field frame 接组件库。
- [x] `lib/features/library/document_actions.dart`：dialog 接 `GlassDialog`；text field 保留标准 `TextField` + `GlassContainer` frame。
- [x] `lib/features/settings/settings_page.dart`：子页面 app bar 接 `GlassToolbar`。
- [x] `lib/features/settings/appearance_settings.dart`：segmented control/icon tile 接组件库；强度卡片已删除。
- [x] `lib/features/settings/about_settings.dart`：更新/权限 dialog 接 `GlassDialog`；进度 dialog 保留无 action 的 `LiquidGlassDialog`（内部 `GlassCard`）。
- [x] `lib/features/reader/reader_page.dart`：文档菜单接 `showGlassActionSheet`；dialog/sheet/text field frame 接组件库；液态玻璃模式下 app bar 返回键与操作按钮接 `GlassIconButton`，经典模式/滚动临时玻璃条保留 Material `IconButton`。
- [x] `lib/features/reader/markdown/markdown_viewer.dart`：外链 dialog 接 `GlassDialog`。
- [x] `test/app_glass_settings_test.dart`：覆盖 role→blur/quality 策略与 intensity 全通道缩放。

## 11. 决策记录

- 2026-10-13 build 197：
  - 删除自定义玻璃强度滑杆和 custom mode；
  - 强度固定 0.72；
  - 底部 tab 宽度恢复 160px；
  - 本计划文档创建。
- 2026-10-14 build 198（Phase 0–4 一次交付，Phase 5 保留为可选项）：
  - 新增 `AppGlassRole`/`AppGlassSettings`；所有 app 玻璃 surface 经它解析完整 `LiquidGlassSettings`，role 决定 blur 预算与 quality 策略；
  - `GlassCard`/`GlassContainer`/`GlassChip`/`GlassSegmentedControl`/`GlassDialog`/`GlassToolbar`/`GlassIconButton` 已接入；每个独立 surface 使用 `useOwnLayer: true` + 显式 settings，沿用迁移前的分层行为；
  - dialog 统一走 `showDialog` + `GlassDialog` widget，quality 固定 `standard`；因为 dialog 路由本身有入场动画，`premium` 有黑闪风险；
  - sheet 保留 `showModalBottomSheet`/`DraggableScrollableSheet` host，面板使用组件库 `AdaptiveGlass`（与 `GlassSheet` 内部同一原语）；不迁移 `GlassSheet.show`，避免 drag/stretch/键盘行为差异；
  - 输入框保留标准 Material `TextField`，外层换 `GlassContainer`；不换成 Cupertino 底层的 `GlassTextField`，以保持键盘、选区、校验与 autofocus 行为；
  - 分段控件玻璃模式改用组件库实现后不再渲染 `selectedIcon`（组件库用指示器 + 文本色表达选中态），调用点已移除该参数；
  - 头部：tab 内的圆角头部保留 `AdaptiveGlass` 自定义 chrome（组件库 `GlassToolbar` 是通栏形状，会改变现有视觉语言），操作按钮改 `GlassIconButton`；设置子页通栏 app bar 改 `GlassToolbar`；
  - 版本 2.9.8+198；`build-apk.yml` 产物名同步；
  - 验证走 GitHub CI/`Build APK` workflow（本机不运行 Flutter 命令），APK 从 workflow artifact 取回桌面；不打 tag、不建 Release。
- 2026-10-14 build 199（Phase 3 菜单与 Phase 4 阅读器 chrome 补齐）：
  - 文库文档菜单、文档排序菜单、阅读器文档菜单改 `showGlassActionSheet`；选择结果通过局部捕获变量返回，因为组件库 action sheet 会在回调后自行 `pop`，不能再在回调里 `pop` 值；
  - 阅读器 app bar 在液态玻璃模式下返回键与操作按钮改 `GlassIconButton`（standard）；经典模式与滚动临时玻璃条继续用 Material `IconButton`；
  - 版本 2.9.9+199；`build-apk.yml` 产物名同步；
  - 真机验证项：action sheet 的弹出/取消/返回、7 项排序列表滚动、阅读器 4 个玻璃操作按钮与标题空间。
- Phase 5 决策：本次不执行 shell 级 `GlassScaffold`。§7.2 已列出的状态重挂载、SnackBar/键盘差异与横屏 rail 阻塞项未验证，保留现有 Material `Scaffold` 根。
- 已解决/收敛的 Open questions：
  - 底部 tab 不跟随统一强度，保持 `GlassTabBar.bottom` 默认材质；
  - 头部采用“tab 内自定义 `AdaptiveGlass` surface + 组件库按钮；设置子页 `GlassToolbar`”的组合；
  - sheet 保留现有 host，不迁移 `GlassSheet.show`；
  - `GlassScaffold` 评估保持为独立 Phase 5，本次不做。