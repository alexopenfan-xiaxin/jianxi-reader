# 简兮阅读器 UI/UX 优化计划

> 版本基线：`2.7.7+177` · Flutter `^3.8.0` · 目标平台 Android（主）/Windows（次）
> 本文档基于对 `lib/` 全量代码、设计令牌 `lib/core/design_tokens.dart`、
> `lib/core/app_settings_controller.dart`、`design.txt` Apple 设计语言基线、
> 以及 `updatelog.md` 历史变更的系统性梳理，输出**问题清单 + 改进建议 + 落地路线图**。

---

## 0. 项目 UI/UX 现状速写

| 维度 | 现状 | 评价 |
| --- | --- | --- |
| 视觉模式 | 两套：`AppVisualMode.classic`（白底 + hairline + 轻投影）、`AppVisualMode.liquidGlass`（BackdropFilter + 渐变 + MetalFx 暗色特效） | ⭐⭐⭐⭐ 体系完整，但暗色 MetalFx 过度抢眼 |
| 色彩 | Action Blue `#0066CC`、Parchment `#F5F5F7`、Ink `#1D1D1F`；`AppColors` 静态类 + `AppPalette` 主题扩展 | ⭐⭐⭐⭐ 严格遵循 Apple 色彩基线 |
| 字体 | `Inter` (单字族) + 可选 `LXGWWenKai` | ⭐⭐ 缺少 SF Pro 的 OpenType `ss03` 替代处理；中文场景下应默认 CJK 字体栈 |
| 排版 | `TextTheme` 17/14/21/34/40 阶梯；`letterSpacing: -0.374` (Apple tight) | ⭐⭐⭐⭐ 与 Apple 基线一致 |
| 间距 | `AppSpacing {xxs, xs, sm, md, lg, xl, xxl}` = 4/8/12/17/24/32/48 | ⭐⭐⭐⭐ 8 为基底 + 17 主节奏，节奏成熟 |
| 圆角 | 8/11/18/pill | ⭐⭐⭐⭐ 严格遵循 `rounded.sm/md/lg/pill` |
| 阴影 | 仅 `AppCard`、Import FAB、Selected Nav Capsule 三处使用 | ⭐⭐⭐⭐ 克制 |
| 动效 | `AppMotion` 5 档 + `SpringCurve` 三档（bouncy / snappy / gentle） | ⭐⭐⭐⭐ 动效语义清晰 |
| 导航 | `IndexedStack` + `FloatingBottomNav`（液态玻璃双 tab）+ 顶栏 header | ⭐⭐ 仅有「首页 / 设置」两 tab，信息架构单薄 |
| 阅读 | AppBar + 3px 进度条 + Markdown/HTML 渲染 + 目录抽屉 + 智能滚动条 | ⭐⭐⭐⭐ 阅读场景成熟 |
| 模式引导 | 液态玻璃 / 主题模式 / 阅读预设均无引导，需要用户自己探索 | ⭐⭐ 可发现性弱 |

**总结：**
- **基础扎实**：色彩、字号、间距、圆角、动效令牌齐备，与 Apple 设计语言契合度高。
- **结构成熟**：Library / Reader / Settings 三大主页面 + 搜索/排序/标签/书签/进度等能力齐备。
- **主要短板**：
  1. **信息架构**单薄（2 tab 底部导航 + 顶部分散的 icon button 群）。
  2. **可发现性**差（液态玻璃、阅读模式、标签、排序、书签等"暗能力"没有引导）。
  3. **部分自绘图标与 Material 图标混用**，视觉一致度下降。
  4. **动效叠加较多**（Liquid Glass + Stagger + SliverTransition + SliverAnimatedList 同步触发），对中低端设备有压力。
  5. **暗色 MetalFx 模式 + 强制 classic 的散点逻辑**让视觉一致度有反复（见 §3.4）。

---

## 1. 信息架构与导航

### 1.1 当前结构

```
AppShell (IndexedStack)
 ├── LibraryPage (0)
 │   ├── _LibrarySearchPage (push)
 │   ├── _SortSheet (modal)
 │   ├── _GlassDocumentMenu (modal)
 │   ├── _TagEditorSheet (modal)
 │   └── ReaderPage (push)
 └── SettingsPage (1)
     ├── AppearancePage (push)
     ├── ReadingSettingsPage (push)
     └── AboutPage (push)
```

### 1.2 问题

| # | 问题 | 影响 | 证据 |
| --- | --- | --- | --- |
| 1.2.1 | 底部仅 2 个 tab，所有二级功能（标签、收藏、书架分组）只能通过 modal sheet 间接触达 | 不可发现性差 | `_FloatingBottomNav` 只渲染 home / settings 两项 |
| 1.2.2 | Library 顶栏右侧 `_HeaderIconButton` 连续两个 40×40 + 2px 间距，搜索/排序/导入三个能力互相挤压 | 触达效率低，拥挤 | `library_toolbar.dart:316-338` |
| 1.2.3 | Settings 是平铺的 3 个入口卡片（外观/阅读/关于），没有"账户"、"存储"、"实验功能"等扩展位 | 后续新增功能无处安放 | `settings_page.dart:41-48` |
| 1.2.4 | AboutPage 混入了「缓存清理」功能，与"关于"语义不匹配 | 信息分组混乱 | `about_settings.dart:648-672` |
| 1.2.5 | 顶部右侧 48px 高的「设置陪伴图标」（自绘小动物笑脸）出现原因不明，与功能无关 | 视觉噪音 | `settings_page.dart:283-370` |

### 1.3 建议

**A. 短期：保留 2 tab 但重塑 Library 顶栏**

- 把「搜索/排序/视图切换」从图标按钮收敛为一个统一的 `PopupMenuButton`（`Icons.tune_rounded`），并把最常用的"视图切换"提到顶栏右侧作 segmented control（与阅读显示页风格一致）。
- 移除"陪伴图标"，或改作一个真正可点击的小型入口（例：跳转到「实验功能 / 关于」二级页面）。
- 调整 `_HeaderIconButton` 间距从 `2px` → `AppSpacing.xs (8px)`，减小拥挤感。

**B. 中期：扩展为 3 tab**

引入"收藏 / 标签"作为筛选维度，而不是 tab。

或者更稳的方案：

```
LibraryPage (0)         — 文档列表 + 搜索
CollectionsPage (1)     — 收藏夹 / 标签分组（新增，可选）
SettingsPage (2)        — 设置
```

实现要点：

1. `LibraryController` 增加 `List<DocumentCollection>` 模型（用户自定义分组）。
2. Collections 页面用 `SliverGrid` 复刻 shelf 视觉。
3. 默认 2 tab 兼容老用户；通过"实验室"开关开启 3 tab。

**C. 远期：Drawer 化**

如果未来真的增加到 5+ 一级入口（Library / Collections / Search / Bookmarks / Settings），改用侧滑抽屉 + 主内容 `IndexedStack`，与 iBooks / Apple Books 体验一致。

---

## 2. Library 页面深度优化

### 2.1 列表/书架双视图

#### 现状

- `library_list_view.dart` + `library_shelf_view.dart` 是 `library_page.dart` 的 `part of` 分片。
- 列表视图：`SliverAnimatedList` + 12 项以内的 `StaggeredFadeIn`（基于 `AnimationController`）。
- 书架视图：2/3 列 `SliverGrid` + 6 套 `CoverStyle` 渐变 + 18px 书脊。
- 两种视图通过 `AppSettingsController.libraryViewMode` 切换，无过渡动画。

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 2.1.1 | 列表/书架切换是硬切，没有交叉淡入或 morph 过渡 | `_LibrarySliverTransition` 只对 `switchKey` 变化淡入，未对 viewMode 切换做形变 |
| 2.1.2 | 书架封面色对比度过高（深色封面 + 白字），小屏（如 360 宽）看不清封面类型标签 | `_ShelfTypeMark` 白字 + 0.18 透明背景，4-5 个字符溢出风险 |
| 2.1.3 | 书架 `childAspectRatio: 0.72` 在窄屏（< 360）导致封面信息被裁切（"全部文档"标题只显示一行） | `library_shelf_view.dart:20` |
| 2.1.4 | 列表视图 "最近阅读" 与 "全部文档" 分组在搜索时仍显示（`_RecentReadingSliver` 在 `searchQuery.isEmpty` 时才隐藏） | `library_list_view.dart:101` |
| 2.1.5 | 列表项的"多选 ✓/○ 图标"绝对定位在右上角，selected 态会顶开右侧 `IconButton(more_horiz)`，选中时无菜单 → OK；但未选时菜单和选中圈重叠区域有 12×12 视觉冲突 | `library_list_view.dart:594-605` |

#### 建议

1. **加入 cross-view 过渡**：在切换 viewMode 时，把 `controller.documents` 渲染两次（旧视图 fade out，新视图 fade in），200ms `AppMotion.normal`。
2. **降低封面饱和度**：`_CoverStyle._styles` 当前 6 套都是深色，可以新增 1 套浅色（米黄、淡青），按文档 `tags.hashCode % 7` 选。这样书架整体观感更接近 Apple Books（冷暖交替）。
3. **响应式 aspect ratio**：窄屏用 0.65（更瘦高，给标题留 3 行），宽屏 0.78。
4. **统一"多选"操作区**：选中态出现时，把右侧 `more_horiz` 替换为"已选 N" 计数（保持单行高度不变），用 `AnimatedSwitcher` 做过渡。
5. **书架 "最近阅读" 与"全部文档"分组策略**：搜索 query 存在时，把整个 shelves 收起成单一结果列表，避免视觉混乱。

### 2.2 文档卡片（List Tile）

#### 现状（`_DocumentTile`）

- 48×48 类型徽标 + 标题（最多 2 行）+ 标签 + 时间摘要
- hover/press 缩放 0.98 (`_hoverController`)
- Hero 动画用 `doc_badge_${path}` 跳转到阅读页（同 icon）

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 2.2.1 | 标题 `titleMedium` 17px，置顶/外链图标放在行内，2 行省略时图标常常被裁掉 | `library_list_view.dart:530-565` |
| 2.2.2 | 标签摘要行用 `Wrap + Expanded` 抢占时间摘要空间，标签 >2 时时间被压到看不见 | `_DocumentMetaRow:1087-1118` |
| 2.2.3 | hover 缩放 `0.98` 在液态玻璃模式下视觉抖动明显（缩放时 backdrop 重计算） | `_DocumentTileState:469-471` |
| 2.2.4 | 长按进入"多选"，但多选模式无文字提示（只在 Semantics hint 里有"长按多选"） | `library_list_view.dart:489-492` |

#### 建议

1. **标题行 + 状态图标分行**：标题独占一行，置顶/外链图标在副标题（meta）行，与标签并列。
2. **meta 行重新分配空间**：标签固定 1 行 + 省略（>2 时显示 `+N`），时间摘要固定右对齐，最多 1 行；如果冲突，时间摘要优先（用户最关心的"最近阅读"信息）。
3. **hover 缩放改用 `transform: scale(0.985)` + 更短时长 (120ms)**，减少液态玻璃 backdrop 重算成本。
4. **多选首次触发**时弹出一次性 Snackbar 提示「长按其他文档可连续多选」，3 秒后自动消失。这是 Apple Music / Photos 通用做法。

### 2.3 头部（`_FixedLibraryHeader` / `_SelectionHeader`）

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 2.3.1 | 头部使用自绘 `_DocumentTypeIconPainter` + `_LibraryHomeIcon` (48×48) + "首页" 标题，单独看略显空旷，但与"设置页" 头部用同结构（48×48 + 标题）保持一致 — 这点**做对了** | `library_toolbar.dart:218-248` |
| 2.3.2 | 多选头部 `_SelectionHeader` 的"批量清除阅读进度"图标 `history_toggle_off_rounded` 与"清缓存"图标视觉接近，新用户难区分 | `library_toolbar.dart:177-180` |
| 2.3.3 | 多选头部只显示"已选择 N 个"，无"全选 / 反选"快捷入口 | `library_toolbar.dart:158-165` |

#### 建议

1. **多选头部加"全选"按钮**：右侧 4 个图标按钮改成「标签、刷新、清进度、删除 + 全选"全部"` 5 个，溢出部分收进 `PopupMenuButton`。
2. **图标替换**：
   - "批量清除阅读进度" → `Icons.bookmark_remove_rounded`（更直观）
   - "批量刷新" → `Icons.cloud_download_rounded`（区分于列表项的 `refresh_rounded`）

### 2.4 浮动导入按钮（`_FloatingImportButton`）

#### 现状

- 60×60 圆形 FAB，液态玻璃模式下使用 `LiquidGlassSurface` 包裹。
- 位置：右下角，距底 86px（避开底栏）。
- 导入中显示 `CircularProgressIndicator`（白色 2.4 stroke）。

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 2.4.1 | FAB 在小屏（360 宽）会与"全部文档"列表项的水平 padding 24px 冲突，视觉上贴在边缘 | `library_page.dart:140-145` |
| 2.4.2 | 液态玻璃 FAB 的 `borderColor: Colors.white.withOpacity(0.34)` 在浅色背景下几乎不可见，FAB 与背景"分离感"减弱 | `library_toolbar.dart:402-413` |

#### 建议

1. **液态玻璃模式 FAB 边框加 1px 内描边 + 0.06 黑色阴影**（`boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: Offset(0, 10))]`）来强化层次。
2. **多选模式自动隐藏 FAB**（已有逻辑 `if (!_selectionActive)` 保留即可）。
3. **FAB 长按弹菜单**（不增加视觉占位）：单次点击 = 导入；长按 = 弹出「从最近打开 / 从系统选择 / 从 URL 导入」三选（其中"从 URL"预留）。

### 2.5 搜索页（`_LibrarySearchPage`）

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 2.5.1 | 搜索是独立页面（push），而非内联展开（用户需"返回"才能看到列表） | `library_search_page.dart` |
| 2.5.2 | 搜索页"全部 / 标签" 切换在搜索结果下方，搜索结果为空时，"全部 / 标签"位置孤悬在屏幕中间 | `library_search_page.dart:86-103` |
| 2.5.3 | 搜索结果直接复用 `_SearchResultTile`（一种紧凑 tile），但与主列表的 `_DocumentTile` 视觉差异大（无类型徽标、无更多菜单） | `library_search_page.dart:273-309` |

#### 建议

1. **搜索改内联展开**：把搜索框与"最近阅读 / 全部文档"放在同一 SliverList 中，点击搜索框进入 inline `searchDelegate` 模式（`SliverPersistentHeader`）。
2. **如果保留独立搜索页**：
   - 顶部加 `SegmentedButton`：「按文件名 / 按内容 / 按标签」三选项。
   - 内容搜索基于 `SearchIndexService`（项目已有但需确认使用），无结果时给"清除筛选"快捷按钮。
3. **统一搜索结果 tile 视觉**：复用 `_DocumentTile`，去掉长按多选、保留 more menu。

### 2.6 标签系统

#### 现状

- 标签列表来自 `LibraryController.tags`。
- 创建/删除/置顶：`_TagEditorSheet`（modal bottom sheet）。
- 颜色：用 `codeUnits` 哈希到 6 色调色板，固定映射。

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 2.6.1 | 用户**首次进 App**完全不知道标签怎么用；无引导 | — |
| 2.6.2 | 6 色调色板对 4 标签以上用户颜色重复感强 | `_tagColor()` |
| 2.6.3 | 标签可置顶（pinned），但 Library 主列表并不展示 pinned 标签，置顶仅在搜索页/标签编辑器可见，置顶的实际价值低 | `library_controller.dart` |

#### 建议

1. **首次进入 Library 时显示 banner 提示**「长按文档 · 设置标签」（点击关闭，仅显示一次），把"长按"这个核心交互明确化。
2. **扩展为 12 色调色板**（增加"紫罗兰、珊瑚、青绿、琥珀"4 套），按 `hash % 12`，色相对比更大。
3. **置顶标签作为"虚拟收藏夹"**：在 Library 顶栏的 `SegmentedButton` 中加入"我的收藏"过滤项（基于 `pinnedTags`），让置顶有真实使用场景。
4. **删除标签二次确认**已经在 `_TagEditorSheet._deleteTag` 中实现 ✓，但 snackbar 错误信息可以更友好（"该标签正在被 3 个文档使用，仍要删除吗？"）。

---

## 3. Reader 页面深度优化

### 3.1 顶部 AppBar

#### 现状

- 固定 toolbarHeight 52px（竖屏 `kToolbarHeight`）。
- 进入滚动后透明 + 液态玻璃模糊（`LiquidGlassSurface`）。
- 标题区域：搜索模式切输入框，否则显示 `Hero(doc_badge) + 文档名`。
- Actions：目录 / 搜索 / 阅读显示 / 文档操作（液态玻璃模式用 IconButton，否则 PopupMenuButton）。

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 3.1.1 | Action 4 个 + Back 1 个，AppBar 拥挤，尤其在窄屏 (360 宽) | `reader_page.dart:339-409` |
| 3.1.2 | 标题区 `Icon + 8px + Expanded(Text)` 没有"次要信息"（如章节、字数） | `reader_page.dart:313-336` |
| 3.1.3 | 文档操作在液态玻璃模式下用 `IconButton(more_horiz)`，在经典模式下用 `PopupMenuButton` — 体验不一致 | `reader_page.dart:377-408` |
| 3.1.4 | 文档操作菜单项只有"添加书签 / 重命名 / 移出"，缺失"分享、复制标题、跳到行号"等扩展 | `_ReaderMenuAction` 仅 3 项 |
| 3.1.5 | `_handleAction` switch 中 `bookmark` 用 `try/catch` 包了 `DocumentIdentityService.getOrCreateId`，但错误信息直接吐给用户 — 应该 fallback 到本地路径 id | `reader_page.dart:603-634` |

#### 建议

1. **精简 AppBar actions**：
   - 保留：目录、阅读显示、更多
   - 搜索：移到 AppBar **下方一行**（变成 inline search bar，节省右侧空间）
   - 文档操作：始终用 `IconButton(more_horiz)` 触达 bottom sheet，与 Library 一致。
2. **标题区升级**：
   - 第一行：文档名（粗体）
   - 第二行：当前章节名（来自 `_tocEntries` 中 activeIndex，`labelMedium` 灰色），点击跳目录。
3. **文档操作菜单扩展**：
   - 添加书签（已有）
   - 重命名（已有）
   - 移出（已有）
   - **新增**：分享（拷贝路径/标题）、在文件管理器中打开、跳到行号、复制 Markdown 纯文本。
4. **书签 fallback**：当 `DocumentIdentityService.getOrCreateId` 失败时，用 `document.path.hashCode` 作为稳定 id，并 `debugPrint` 记录异常，不向用户报错。

### 3.2 进度条与"上次阅读到这里"

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 3.2.1 | 进度条 3px 太细，对长文档（> 10 屏）几乎没有视觉反馈 | `reader_page.dart:702-741` |
| 3.2.2 | "上次阅读到这里" 浮窗 2 秒后自动消失，用户来不及点击 | `reader_page.dart:194-204` |
| 3.2.3 | 进度保存间隔 500ms + 离开页 `_saveProgressNow()` 双写，频繁写 SharedPreferences | `reader_page.dart:162-182` |

#### 建议

1. **进度条升级**：
   - 默认 3px（保持克制）
   - 长按 AppBar 区域时，临时展开成 6px + 章节节点（圆点），松开后回到 3px。
2. **"上次阅读"延长**：
   - 默认 5 秒消失
   - 用户未操作时，"上次阅读"浮窗旁边增加"忽略"小按钮
   - 浮窗移到屏幕**底部**（与系统返回手势避免冲突，且不挡目录/搜索图标）
3. **节流优化**：
   - 进度保存间隔 500ms → 1500ms
   - 离开页立即保存，但加 `if (changed) await save()` 守卫
   - 节流用 `Timer? + lastWriteAt` 双层控制

### 3.3 目录抽屉（`TocDrawer`）

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 3.3.1 | 抽屉高度按内容自适应，**不显示滑动手柄**（`drawer: Drawer` 没有 `showDragHandle`） | `toc_drawer.dart:84-87` |
| 3.3.2 | 顶部 padding 24px (AppSpacing.lg) 过大，让文档名只能 1 行 | `toc_drawer.dart:91-119` |
| 3.3.3 | 列表项 `ListTile(dense: true)` 高度 48px 固定，多级目录视觉差异小（H2 / H3 / H4 都是 16/14 灰度变化） | `toc_drawer.dart:161-200` |
| 3.3.4 | "返回顶部"按钮放在顶部，但当 TOC 很短时，按钮离 list 太远 | `toc_drawer.dart:120-127` |

#### 建议

1. **加入顶部滑动手柄**：`Drawer` 改为 `Dismissible` 包裹自定义 `DrawerHeader`，或直接用 `Container` + `BottomSheet`。
2. **顶部 padding 24→16** (AppSpacing.md)，让标题可显示 2 行。
3. **目录层级可视化**：
   - 缩进：每级 +12px
   - 颜色：H1 ink + w700，H2 inkMuted80 + w600，H3 inkMuted48 + w500，H4 inkMuted48 + w400
   - 激活态：左侧 3px 蓝色实心条 + primary background
4. **"返回顶部"放底部**：与 list 一起 `bottomSheet` 风格固定。

### 3.4 智能滚动条（`SmartScrollbar`）

#### 现状

- Markdown 用 Flutter 原生 `Scrollbar`，HTML WebView 用自定义 overlay。
- 滚动速度 > 2500 px/s 进入"快速模式"，3 秒后回到默认隐藏。
- 快速模式：thumb 4→8px，track 显示，色值加深。

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 3.4.1 | 快速模式判断是瞬时速度，移动设备上 2500 px/s 阈值偏激进（很多滚动场景下都会触发） | `smart_scrollbar.dart:47-50` |
| 3.4.2 | 拖动 thumb 时直接 `_onScrollbarDragStart` → scrollbar 不会实际跟随手指移动（因为没接管 ScrollController 的 jumpTo） | `smart_scrollbar.dart:165-177` |
| 3.4.3 | 自定义 overlay（HTML 模式）的 thumb 颜色对比度过低（0.22 alpha on light） | `smart_scrollbar.dart:243-249` |

#### 建议

1. **提高阈值到 4000 px/s**，并加 100ms 滑动平均窗口（避免瞬时跳变触发）。
2. **thumb 拖动接管滚动**：使用 `Listener` + `onPointerMove` + `ScrollController.position.jumpTo(thumbTop / maxTop * maxScroll)`。
3. **thumb 颜色加深到 0.4 alpha**，并加 1px hairline border 提升可见度。

### 3.5 阅读显示设置（`showReadingDisplaySheet`）

#### 现状

- `DraggableScrollableSheet` + `ReadingSettingsPanel` (含预览)。
- 设置项：阅读主题（默认/纸张/护眼）、页边距、字号、行距、字体、恢复默认。

#### 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 3.5.1 | 预览卡片字号、行距、字体都跟随设置实时变化，但**没有同步切换阅读主题** — 用户切换"纸张"后预览仍是默认色 | `reading_settings_panel.dart:225-308` |
| 3.5.2 | 字号滑块的 `_ReadingValueSlider` 预设（紧凑/标准/宽松）始终用 `readingScalePresets` (3 个固定值)，但**行距**滑块也用同一组预设，行距预设 = 字号预设（不同行高），容易误解 | `reading_settings_panel.dart:155-189` |
| 3.5.3 | 字号范围 14-28，行距 1.2-2.0，但**没有跨设置联动**（行距没随字号自适应） | `AppSettingsController` |

#### 建议

1. **预览卡片实时切换阅读主题**：在 `_ReadingPreviewPanel` 包一层 `ReadingTheme` aware 的 decoration。
2. **字号 / 行距预设分离**：字号 14/16/18/21/24、行距 1.4/1.55/1.7/1.85/2.0。
3. **联动**：行距滑块 = 字号 × 0.06 + 0.85（线性插值），用户仍可手动覆盖。

### 3.6 阅读中的导航能力（缺失项）

- [ ] **大纲快速跳转**：长按 TOC 抽屉的某一项 → 直接跳到下一个同级。
- [ ] **页内书签**：长按某行 → 添加书签到该位置（不是当前位置）。
- [ ] **划线 / 高亮**：Markdown 段落长按后弹"高亮 / 注释"，存储为本地笔记。
- [ ] **图片预览**：点击图片后弹全屏（`TappableImageBuilder` 已注册，但还没看到全屏预览 UI）。
- [ ] **目录 / 进度迷你条**：右下角小浮窗"2/12 章节"。

---

## 4. Settings 页面深度优化

### 4.1 现状概览

- 顶栏 48×48 自绘设置图标 + "设置" 标题 + 48×48 自绘"陪伴"图标（笑脸）。
- 3 个入口卡片：外观与动画 / 阅读体验 / 关于应用。
- 卡片宽度：竖屏单列，横屏 (≥ 640) 双列。

### 4.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 4.2.1 | "陪伴图标"（笑脸）功能不明，视觉上像 logo 又有违和感 | `settings_page.dart:283-370` |
| 4.2.2 | 三个卡片入口**跳转深度太浅**（点开就直接是完整设置页），可探索性差 | `settings_page.dart:42-48` |
| 4.2.3 | 外观设置（visualMode / appFontFamily / themeMode / libraryViewMode / predictiveBack）混杂在同一个"外观与动画"页里 — 分类边界模糊 | `appearance_settings.dart:99-232` |
| 4.2.4 | 关于页混入了"缓存清理"，语义错位 | `about_settings.dart:648-672` |

### 4.3 建议

**A. 重构 Settings 一级入口（短期）**

```
设置 (首页)
 ├── 外观
 │    ├── 主题（浅色 / 深色 / 跟随系统）
 │    ├── 视觉模式（经典 / 液态玻璃）         ← 移到独立页
 │    └── 字体（系统 / 落霞孤鹜）
 ├── 阅读
 │    ├── 阅读主题（默认 / 纸张 / 护眼）
 │    ├── 页边距 / 字号 / 行距 / 字体
 │    └── 恢复默认
 ├── 文档
 │    ├── 首页视图（列表 / 书架）
 │    └── 预测性返回手势
 ├── 存储
 │    ├── 缓存大小（已存在）
 │    └── 清理缓存
 ├── 关于
 │    ├── 应用版本
 │    ├── 开源地址
 │    └── QQ 交流群
 └── 实验功能（hidden by default）
      └── Collections Tab 预览
```

**B. 中期：让"液态玻璃"独立可见**

- 在 Settings 首页的"外观"卡片**右上角**加一个 shimmer 角标，提示"新模式可用"，点击直达"视觉模式"页。

**C. 删除"陪伴图标"**

- 把它替换成 Settings 入口的"快捷操作"小按钮：`PopUpMenuButton` 包含"实验功能 / 反馈"等二级入口。

### 4.4 关于页（About）优化

- 现状：`AppCard` 堆叠版本信息、QQ 群、开源地址、邮箱、缓存清理、版本检查。
- 建议：拆分为「关于（只展示元信息）」「存储（缓存 + 清理）」「更新（手动检查）」三页。

---

## 5. 液态玻璃模式（Liquid Glass）统一性

### 5.1 现状

- `LiquidGlassSurface` 是统一的玻璃面板组件，参数化 `borderRadius / color / borderColor / blurSigma / boxShadow / innerHighlight / tintPrimary / chromaticEdge / edgeHighlight / metalFxDarkEffect`。
- `LiquidGlassTokens` 定义了 Android 模糊参数、MetalFx 暗色色板、各类容器 alpha。
- 暗色模式 + 液态玻璃 + `metalFxDarkEffect: true` → 启用 `metalFxCyan / Mint / Rose / Gold / Blue` 5 色 rim/reflection 效果。

### 5.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 5.2.1 | 浅色 + 液态玻璃的"光泽感"较暗色弱很多，视觉上更接近"半透明白卡"，与"液态玻璃"品牌感不符 | `liquid_glass.dart:84-115` |
| 5.2.2 | 暗色 MetalFx 的 chromatic edge 用了 `cyan/rose/gold/blue` 4 色 rim，转角处可能出现"赛博朋克"感，与"简兮"品牌风格（克制、水墨）冲突 | `liquid_glass.dart:18-25` |
| 5.2.3 | 多个液态玻璃面板叠加（AppBar + BottomNav + Drawer）时，BackdropFilter 链造成 GPU 压力 — 中低端设备滚动有卡顿 | 项目内未做性能基准 |
| 5.2.4 | `liquidGlassHeaderColor / liquidGlassContainerColor / liquidGlassCardColor` 等辅助函数散落在 `liquid_glass.dart` 末尾，调用方众多（`AppCard` / `_FixedLibraryHeader` / `_SelectionHeader` / `glass_segmented_control.dart` / `_SortSheet` / `_TagEditorSheet` / `ReaderPage`），但**没有统一预览** — 设计师难验证 | — |
| 5.2.5 | 部分组件**强制回退**到 classic：`_DocumentTileState` 中 `forceClassicCard = liquidGlass && Theme.brightness == dark` — 即"暗色 + 液态玻璃"下文档卡片用 classic，**但同时**其他卡片（如 `_RecentDocumentCard`）仍用液态玻璃，**视觉不统一** | `library_list_view.dart:486-488` |

### 5.3 建议

1. **浅色液态玻璃增强**：
   - `boxShadow` 默认 `blurRadius: 24, offset: (0, 12), color: black.withOpacity(0.08)`
   - `innerHighlight: true` 默认开（当前已经默认，但 alpha 0.38 偏低，可提到 0.45）
   - 加 `topHighlight`（从顶部 1px 白到 0.7alpha），强化"水光"反射。
2. **暗色 MetalFx 降饱和**：
   - 把 5 色 rim 收敛到 1 色 `metalFxCyan`（蓝绿），其他色降级为点缀（仅在拖动时闪现）。
   - `metalFxDarkRingWidth` 1.4 → 1.0，弱化强轮廓。
3. **性能预算**：
   - **预算**：每帧最多 2 个 `BackdropFilter`。
   - 实现：在一个页面用 `RepaintBoundary` 把"已结束动画"的玻璃面板单独绘制，避免每帧重算。
   - 实施：用 Flutter DevTools 测 60fps 占比，作为验收标准。
4. **统一预览页（开发用）**：
   - 内部 `/_liquid_glass_lab` 页面，列出所有 `LiquidGlassSurface` 变体（浅色/暗色 × light/highlight/chromatic 等组合），开发自测 + 设计走查用。
5. **移除 `forceClassic` 硬编码**：
   - 把"暗色 + 液态玻璃卡片用 classic"逻辑改为"暗色 + 液态玻璃卡片用更弱的 alpha + 0 hairline border"。
   - 让所有卡片风格统一。

---

## 6. 排版 / 字体 / 间距 一致性

### 6.1 现状

- 字体：`Inter` (默认) / `LXGWWenKai` (中文)。
- 字号梯度：`displayLarge 40, headlineLarge 34, titleLarge 21, titleMedium 17, bodyLarge 17, bodyMedium 14, labelLarge 17, labelMedium 14`。
- 间距：`AppSpacing.xxs/xs/sm/md/lg/xl/xxl` = 4/8/12/17/24/32/48。
- 圆角：`AppRadii.sm 8 / md 11 / lg 18 / pill 9999`。

### 6.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 6.2.1 | `headlineLarge 34` 在仓库内**几乎未使用**（只在 `TextTheme` 定义），造成字号梯度有断点 | 全仓搜索 |
| 6.2.2 | `displayLarge 40` 同上 | 全仓搜索 |
| 6.2.3 | 大量手写 `fontSize: 11 / 12 / 14 / 17 / 20 / 21 / 22` 散布在 `library_list_view.dart` / `library_toolbar.dart` / `appearance_settings.dart` / `about_settings.dart` / `library_shelf_view.dart` / `toc_drawer.dart` / `_RecentDocumentCard` 等 |  |
| 6.2.4 | 圆角 12 / 13 / 14 / 18 / 30 / 42 / pill 散落 |  |
| 6.2.5 | 间距 10 / 11 / 12 / 16 / 24 / 32 / 38 / 64 / 82 / 86 / 92 / 100 混用 |  |

### 6.3 建议

1. **建立 `AppTextStyle` 速查表**（与 `AppRadii` / `AppSpacing` 同样为静态类），把字号的"用途"显式命名：
   - `AppTextStyle.cardTitle` 17/600/-0.374
   - `AppTextStyle.cardSubtitle` 12/700/0
   - `AppTextStyle.sectionHeader` 20/800/0
   - `AppTextStyle.dockLabel` 11/600/0
   - `AppTextStyle.menuItem` 17/700/0
   - … 共 15 个
2. **圆角收敛到 `AppRadii`**：
   - 删除 12（→ `sm=8` 或 `md=11`）
   - 13（→ `md=11`）
   - 14（→ `md=11`）
   - 30 / 42（→ `lg=18` 或 `xxl=24`）
   - 24/32（→ `lg=18` 或 `pill=9999`）
3. **间距收敛到 `AppSpacing`**：
   - 10 → `xs=8` 或 `sm=12`
   - 11 → `sm=12`
   - 38 → `xl=32` 或 `xxl=48`
   - 64 → `xxl=48` × 1.33（创建 `AppSpacing.huge=64`）
   - 82 → `xxl + xs` 组合（顶栏预留高度）
4. **清理无用的 `headlineLarge` / `displayLarge`**：删除或保留作为"产品页 hero"预留。

---

## 7. 颜色 / 主题一致性

### 7.1 现状

- `AppColors` (静态) + `AppPalette` (ThemeExtension) 双层。
- 浅色 canvas: #FFFFFF, parchment: #F5F5F7, dark canvas: #0A0A0C, dark parchment: #000000。
- 暗色 ink: #FFFFFF, muted: #CCCCCC, 浅色 ink: #1D1D1F, muted: #7A7A7A。

### 7.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 7.2.1 | 暗色 `parchment: #000000` 与 `canvas: #0A0A0C` 几乎不可分，造成列表与背景边界感弱 | `design_tokens.dart:171-183` |
| 7.2.2 | 暗色 `card: #1C1C1E` 比 `canvas #0A0A0C` 亮 12%，AppBar 透明 + 模糊时**视觉上**反而比列表项更深 — 反直觉 | 同上 |
| 7.2.3 | 标签 `tagColor` 6 套硬编码颜色（`#2F6BFF / #0F8B6B / #9A5A00 / #C2415B / #6D5BD0 / #087EA4`）没有与 `AppColors` 关联 | `library_list_view.dart:1153-1167` |
| 7.2.4 | 书架封面 `_CoverStyle._styles` 6 套深色渐变硬编码，没有语义关联 | `library_shelf_view.dart:317-375` |

### 7.3 建议

1. **暗色 parchment 提到 `#0E0E10`**，与 `canvas #0A0A0C` 形成微差。
2. **暗色 `card` 用 `#1C1C1E` 但 `parchment` 改为 `#101012`**，让 AppBar 浮在内容之上。
3. **抽出 `AppSemanticColor.tagPalette` / `AppSemanticColor.coverPalette`**：
   - tagPalette 12 色（含语义化命名 `tagBlue / tagGreen / tagAmber / tagCoral / tagViolet / tagTeal` + 浅深各一）
   - coverPalette 8 套（4 浅 + 4 深），按文档 hash 选取。
4. **暗色模式下的"金属效果"色板**也移到 `AppColors` 命名空间：`metalFxCyan` 等已经是 `LiquidGlassTokens` 私有，考虑提升到 `AppColors` 让设计走查可见。

---

## 8. 动效与性能

### 8.1 现状

- 5 档 `AppMotion` (110/160/240/320/420ms) + 6 条 `Curves`。
- 3 档 `SpringCurve` (bouncy / snappy / gentle)。
- `LiquidGlassSurface` 用 `BackdropFilter` + 多次 `DecoratedBox` + 自绘 `_MetalFxDarkReflection` / `_LiquidGlassChromaticEdge` / `_LiquidGlassEdgeHighlight` / `_MetalFxDarkRim`。

### 8.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 8.2.1 | Library 首屏同时触发 4 个动画层：Sliver 切换淡入 + StaggeredFadeIn（前 12 项） + SliverAnimatedList + AppBar liquid glass 模糊 | `library_list_view.dart:67-115` |
| 8.2.2 | 液态玻璃 AppBar 的 `BackdropFilter` 紧贴屏幕顶部，但**底栏/底栏指示器也用 `BackdropFilter`**，三个滤镜同时存在时 GPU 压力叠加 | `app_shell.dart:147-150`, `reader_page.dart:286-298` |
| 8.2.3 | `_StaggeredFadeIn` 限制 12 项，但当 Library 一次有 30+ 文档且切到列表视图时，仍有 12 项同时动画 — 仍可能掉帧 | `library_list_view.dart:16-19` |
| 8.2.4 | 自绘图标（`_DocumentTypeIconPainter` / `_SettingsHomeIconPainter` / `_SettingsCompanionIconPainter` / `_LibraryStateIllustrationPainter`）每次重绘都新建 Paint 对象 — 性能次优 | `library_toolbar.dart:250-313` |

### 8.3 建议

1. **动画分阶段**：
   - 阶段 1 (0-200ms): Sliver 切换淡入
   - 阶段 2 (200-500ms): StaggeredFadeIn
   - 阶段 3 (500ms+): SliverAnimatedList 增量条目
   - 现在是同时触发，视觉上"卡"的感觉会被放大。
2. **液态玻璃缓存**：
   - 顶栏的 LiquidGlassSurface 内部加 `RepaintBoundary`，且 `ImageFilter` sigma 减半（24→16）以减少模糊计算量。
3. **StaggeredFadeIn 限 8 项**，每项延迟 0.04s（更快更同步），避免长尾。
4. **Paint 复用**：所有 `CustomPainter` 把 `Paint()` 移到 `static const`，或在 `shouldRepaint` 返回 false 时复用。

---

## 9. 可发现性 / 空状态 / 错误

### 9.1 现状

- 空状态：`_EmptyState`（"未有简牍" + 导入按钮）、`_NoResultsState`（"未寻得匹配文档"）、`_SearchEmptyState`。
- 错误状态：`_ErrorBanner`（红色 ⚠ + 文本）、`_ReaderError`（AppCard + 错误文字）、`_GlobalErrorCard`（全屏 Material，含重试按钮）。
- Loading：`_LoadingState`（居中 CircularProgressIndicator）。

### 9.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 9.2.1 | "未有简牍" 状态有**两个**导入入口（空状态按钮 + 右下角浮动 FAB），用户首次进入会困惑 | `library_empty_state.dart:232-239` + `library_toolbar.dart:340-422` |
| 9.2.2 | Reader 错误状态文案"读取文档失败：$e"对普通用户不友好 | `reader_page.dart:517-522` |
| 9.2.3 | Library `_ErrorBanner` 没有"重试"按钮 | `library_empty_state.dart:29-53` |
| 9.2.4 | 全局错误 `_GlobalErrorCard` 用 Material `#F8F1E6` 背景，**与 AppPalette 完全脱钩** | `main.dart:70-119` |
| 9.2.5 | "上次阅读到这里"浮窗 2 秒自动消失，但用户点击后没有明显的"已跳转"反馈 | `reader_page.dart:194-204` |

### 9.3 建议

1. **空状态只保留 1 个导入入口**（FAB），空状态中央放说明性文字 + 副 CTA「从示例库导入」（提供几个内置示例文档）。
2. **错误状态友好化**：
   - 把"读取文档失败"按错误码翻译成 3 类文案（文件不存在 / 编码不支持 / 权限不足）
   - 统一重试按钮位置（卡片右上角）
3. **ErrorBanner 加重试**。
4. **全局错误卡**改用 `context.palette.card` 背景 + 文字色，保持与 AppTheme 一致。
5. **"上次阅读"点击后**，触发轻量 `HapticService.successFeedback()` + 0.4s 闪烁（`AnimatedContainer` 闪白），给用户"已响应"反馈。

---

## 10. 可访问性（Accessibility）

### 10.1 现状

- 关键组件有 `Semantics(label / hint / button / selected)`：`_DocumentTile`、`_RecentDocumentCard`、`_ShelfDocumentCard`、搜索框、TOC tile。
- 触控目标：FAB 60×60、底部 tab 104×52、Header icon 40×40（**小于 44 建议**）、Chip chip 28px 圆点。

### 10.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 10.2.1 | Header 右侧 icon button 仅 40×40 — 小于 iOS HIG 44×44 / Android Material 48×48 建议 | `library_toolbar.dart:329-336` |
| 10.2.2 | TOC drawer 的 `_TocTile` ListTile dense 模式是 48px，但多行 `Text(maxLines: 2)` 实际占用更高 — 不够触达 | `toc_drawer.dart:176-200` |
| 10.2.3 | Reader 进度条只有 3px，TalkBack 用户无法感知"已读 50%" | `reader_page.dart:702-741` |
| 10.2.4 | 自绘 icon (`_DocumentTypeIconPainter` / `_SettingsHomeIconPainter`) 没有 `Semantics(label: '文档' / '设置')` | — |
| 10.2.5 | Reader 搜索结果计数 `_ReaderSearchCount` 文字"0/0"对屏幕阅读器没有语义 | `reader_page.dart:790-816` |

### 10.3 建议

1. **Header icon button 40→44px**（最小可触达）。
2. **TOC tile 高度 48→56px**（多行标题 + 触达余量）。
3. **进度条长按时**弹出 6px 圆点章节条 + 屏幕阅读器播报"已读 35%"。
4. **所有自绘 painter 包 `ExcludeSemantics(child: Semantics(label: '...'))`**。
5. **Reader 搜索计数**改为 `"当前 1 个匹配，共 5 个"`。

---

## 11. 响应式 / 多窗口 / 平板

### 11.1 现状

- 横屏（landscape）：Library 用 `_LandscapeNavigationRail` (72 宽) + 主内容；Reader / Settings 在横屏下用 `LayoutBuilder` 限制 maxWidth 900。
- 书架 grid：宽 ≥ 620 → 3 列，否则 2 列。
- Settings 卡片：宽 ≥ 640 + landscape → 2 列。

### 11.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 11.2.1 | 平板（800+）和桌面窗口（如折叠屏展开）的响应式断点不充分 — Library 列表/书架没有"三列 + 边栏"布局 | `library_list_view.dart` 无断点逻辑 |
| 11.2.2 | Reader 在 ≥ 900 宽时 maxContent 900，但**目录抽屉**仍是全屏 Drawer，**没有分栏**布局 | `reader_page.dart` 无 master-detail |
| 11.2.3 | Windows 平台：触屏手势（长按多选、滑动）正常，但 hover 状态没有视觉反馈 | — |

### 11.3 建议

1. **大屏 Library 分栏**：
   - ≥ 840: 左侧 280px 文档列表 + 右侧 200px 元信息（标签、时间、进度）+ 中央主内容
   - ≥ 1200: 同上 + 右侧元信息加宽到 280
2. **Reader 分栏（≥ 1024 宽）**：
   - 左侧 320 TOC 抽屉**常驻**
   - 中央主内容（maxWidth 720）
   - 右侧 280 元信息（书签、笔记）
3. **Windows hover**：
   - `_DocumentTile` 在 `MouseRegion.onHover` 中显示"更多信息"小浮窗（标签、修改时间）
   - 底栏 tab 在 hover 时高亮（保持点击色高亮，hover 用 primary.withOpacity(0.08)）

---

## 12. 国际化（i18n）

### 12.1 现状

- `MaterialApp.locale: Locale('zh', 'CN')` + `supportedLocales: [Locale('zh', 'CN')]`。
- 全部文案**硬编码中文**在 widget 树中。

### 12.2 问题

| # | 问题 | 证据 |
| --- | --- | --- |
| 12.2.1 | 完全没有 `intl` / `flutter_localizations` 翻译机制 — 仅声明 supportedLocales 是空的 | `app.dart:40-46` |
| 12.2.2 | 文案散落在 100+ 个 widget 中，提取到 ARB 文件的工作量很大 |  |
| 12.2.3 | 错误描述 `document_error_describer.dart` 也硬编码中文 | — |

### 12.3 建议

1. **引入 `flutter_localizations` + `intl`**：
   ```yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: ^0.19.0
   ```
2. **生成 ARB 文件** `lib/l10n/app_zh.arb` + `app_en.arb`。
3. **优先级**：先做关键路径（Library / Reader / Settings 首页），错误描述放第二阶段。
4. **添加英文 fallback**：在 `MaterialApp.localeResolutionCallback` 中，未命中 zh_CN 时回退到 en。

---

## 13. 测试与质量保障

### 13.1 现状

- 3 个测试文件：`app_settings_controller_test.dart` / `file_rules_test.dart` / `library_page_test.dart` / `widget_test.dart`。
- 无 `pumpAndSettle` 端到端测试；无 visual regression。

### 13.2 建议

1. **补 Reader 页面测试**：搜索 → 跳转 → 加书签 → 跳到行号。
2. **补 Library 多选测试**：长按 → 多选 → 批量删 → SnackBar 验证。
3. **Visual Regression**：用 `golden_toolkit` 在 CI 上跑关键页面截图对比（Library 列表 / 书架 / Reader / Settings 经典 + 液态玻璃 + 暗色 = 6 个 golden）。
4. **A11y 测试**：`Semantics` matcher 校验关键元素 label / hint。

---

## 14. 改进路线图

### Phase 0 (1 周) — 视觉一致性快赢
- 收敛字号到 `AppTextStyle` 速查表，替换 50+ 处手写 `fontSize`。
- 收敛圆角到 `AppRadii`。
- 移除"陪伴图标"笑脸。

### Phase 1 (2 周) — 信息架构与可发现性
- Library 顶栏右收紧为 1 个 tune 按钮 + 1 个 segmented control 视图切换。
- Settings 拆分为 5 个一级入口（外观 / 阅读 / 文档 / 存储 / 关于）。
- 添加首次启动 Onboarding（液态玻璃模式 / 长按多选 / 阅读主题 三段）。

### Phase 2 (2 周) — 液态玻璃性能与一致性
- 顶栏 / 底栏 LiquidGlassSurface 加 RepaintBoundary + 减小 blurSigma。
- 删除 `forceClassic` 硬编码，统一暗色 + 液态玻璃卡片样式。
- 暗色 MetalFx 5 色 rim 收敛到 1 色 cyan。

### Phase 3 (2 周) — Reader 体验
- AppBar 精简为 3 actions，搜索移到第二行。
- 进度条长按弹章节节点。
- "上次阅读"延长到 5 秒 + 底部定位 + 跳转反馈。
- 目录抽屉分栏（≥ 1024 宽）。

### Phase 4 (2 周) — 大屏与可访问性
- Library ≥ 840 三栏（列表 / 元信息 / 内容）。
- Reader ≥ 1024 master-detail。
- Windows hover 状态。
- Header icon button 40→44px。

### Phase 5 (持续) — 国际化与测试
- 引入 `intl` + `flutter_localizations`，生成 ARB。
- 添加关键路径 widget + golden test。
- 视觉回归 baseline。

---

## 15. 关键决策记录

| 决策 | 理由 | 影响 |
| --- | --- | --- |
| 保留液态玻璃作为可切换模式 | 品牌差异化，但用户对模糊性能敏感 | 增加 ~10% GPU 预算；中低端设备需手动默认 classic |
| 文档卡片 list + shelf 双视图 | 满足"按文件名扫"和"按封面挑"两种心智 | 双倍 UI 维护成本 |
| 阅读进度本地存储 | 简单、隐私 | 多设备同步需另接 |
| LiquidGlassSurface 参数化 | 让单个组件服务多场景 | 参数表变长，文档不全 |
| 自绘部分 icon | 与 Apple 风更契合 | 一致性 + 性能双挑战 |

---

## 16. 风险与待确认

| 风险 | 影响 | 建议 |
| --- | --- | --- |
| 液态玻璃在小米 / 华为中端机上 BackdropFilter 性能未基准化 | 滚动掉帧，影响评分 | 上线前在 3 款真机做 60fps 基准 |
| 设计语言部分自创（_LibraryStateIllustration、_DocumentTypeIcon）与 Apple 严格遵循存在偏离 | 视觉风格分裂 | 决定是否保留"水墨" 视觉分支 |
| 标签/书签数据没有云同步 | 多设备不一致 | 评估是否需要接入 Firebase / WebDAV |
| "上次阅读"逻辑使用 `path` 作为 key，文档移动/重命名后失效 | 用户体验降级 | 已通过 `DocumentIdentityService.getOrCreateId` 缓解，但需要确认迁移是否完成 |

---

## 17. 立即可推进的 5 件事

1. **删除 `forceClassic` 硬编码**，统一卡片视觉。
2. **Header icon button 40→44px**（一行改动）。
3. **Library 顶栏 tune 按钮合并**（用 `PopupMenuButton` 收纳搜索/排序）。
4. **Reader 进度保存间隔 500ms → 1500ms**，减少 SharedPreferences 写。
5. **液态玻璃 AppBar / 底栏加 RepaintBoundary**，性能基线。

每项预估 1-2 小时内可完成，零业务风险。

---

*文档生成时间：2026-06-27*
*对应版本：`2.7.7+177`*
