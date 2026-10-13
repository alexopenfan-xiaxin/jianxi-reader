# 更新日志

## 2.9.5 (build 195)

### 修复
- **阅读设置拖动卡顿** — 字号/行距滑杆改为拖动预览、松手提交，避免每一帧重载 HTML、清空 Markdown 缓存或反复写入偏好设置。
- **文档库重复扫描** — 修正缓存未命中时连续扫描两次的问题，并移除从阅读页返回后的全量重扫。
- **搜索高亮** — 修复匹配数量达到上限时文本尾部可能重复的问题。
- **数据清理与容错** — 删除文档时同步清理书签/历史；损坏的 identity、书签和历史 JSON 不再永久卡死服务。
- **导入稳定性** — 单个文件扫描/导入失败不再中断整批；SAF 大文件复制移到后台线程。
- **本地图片** — Markdown 相对路径图片现在按文档目录解析，支持本地 SVG、data:image 和查询参数形式的 SVG。
- **文件名校验** — 禁止 Windows 保留名和末尾点/空格，重命名时避免重复扩展名。
- **无障碍与生命周期** — 修正“轻点/双击”语义、上下标文字缩放、自定义滑杆与分段控件语义，以及若干 dispose 后的异步回调。
- **文档同步** — 版本更新为 `2.9.5+195`，同步应用内 fallback build number。


## 2.4.1 (build 141) — 2026-06-11

### 优化
- **阅读页进入动画性能** — 移除文档卡片到阅读标题的 Hero 飞行动画，改用轻量 fade/slide 页面过渡，避免进入阅读页时同时布局两端复杂 widget。
- **阅读内容首屏稳定性** — 文档刷新可提前进行，但正文渲染会等页面转场稳定后再切入，减少转场中途大面积重绘造成的卡顿感。
- **Markdown 加载性能** — Markdown 文件读取和预处理移到 isolate，降低大文档打开时主线程压力。
- **滚动与列表动效降负载** — 阅读进度条改为低成本宽度绘制，首页列表入场动画限制在首屏附近条目，避免滚动和长列表场景堆叠动画。

### 调整
- **版本同步** — 应用版本更新为 `2.4.1+141`，更新检查参数同步为 `local=141`。

## 1.1.5 (build 14) — 2026-06-06

### 新增
- **Android SAF 文档选择器** — 通过原生 `Intent.ACTION_OPEN_DOCUMENT` 实现系统文件选择器，支持从任意位置选取 Markdown/HTML 文件，自动复制到本地镜像并保持内容 URI 引用，支持实时刷新。
- **阅读前刷新文档** — 打开文档时自动从原始源刷新内容，确保始终显示最新版本。

### 修复
- **修复编码问题导致的中文乱码** — 修正 `document_file_service.dart` 和 `reader_page.dart` 中因编码错误导致的乱码字符串。
- **阅读页面状态增强** — 新增加载指示器和错误状态页面，在文档准备期间显示加载动画，读取失败时显示错误信息。
- **代码块/标题渲染还原** — 恢复为 v1.0.3 时代的 `EnhancedCodeBlockBuilder` 样式以提升稳定性。

## 1.0.3 (build 4) — 2026-06-05

### 修复
- **Markdown 链接点击恢复** — 重写 `ClickableLinkBuilder`,改用 `GestureDetector`(`HitTestBehavior.opaque`)包裹 `Text` 而非 `Text.rich` + `TapGestureRecognizer`。原因是 `selectable: true` 时包外的 `SelectionArea` 会在手势仲裁中吞掉 span 级 `TapGestureRecognizer`,表现为「链接点击无反应」,而上个版本(1.0.1)未复现纯属巧合(实际编译/运行环境差异)。`GestureDetector` 是 `Widget` 而非 `Text`/`RichText`/`SelectableText`,包内的 `renderInline` 会将其保留为 `WidgetSpan`,因此点击事件可正常触发,文本仍可通过长按选中。
- **Markdown 图片点击恢复** — 注册 `TappableImageBuilder` 替换包内默认 `ImageBuilder`。同样用 `GestureDetector`(`HitTestBehavior.opaque`)包裹 `Image.network`/`Image.asset`,保证「单图段落」与「段落内联图片」两种场景下点击均能回调 `onTapImage`,从而弹出图片预览。

### 备注
- 链接/图片选中态(蓝色高亮、文本可选)行为不变,长按拖拽仍由 `SelectionArea` 处理。
- 1.0.2 的「裸 URL 自动识别」与「首页点击外部取消搜索焦点」特性在本版本保留。

## 1.0.2 (build 3) — 2026-06-05

### 新增
- **Markdown 裸 URL 自动识别** — 注册 `BareUrlPlugin`(`InlineParserPlugin`,触发字符 `h`,正则 `^(?:https?|ftp)://[^\s<>\[\]"`]+`,按 GFM 规则剥离尾部 `?!.,:*_~`),将文本中的裸链接转成 `LinkNode`,复用 `ClickableLinkBuilder` 渲染为可点击链接。
- **首页点击外部取消搜索焦点** — `_LibraryTools` 外层 `ListView` 包裹 `GestureDetector(behavior: HitTestBehavior.translucent, onTap: FocusManager.instance.primaryFocus?.unfocus())`,文档卡片的 `InkWell` 手势不受影响。

## 1.0.1 (build 3) — 2026-06-05

### 新增
- **Markdown 链接可点击** — 注册 `ClickableLinkBuilder` 替换包内默认 `LinkBuilder`。
- **被引用文件支持重命名** — 文档列表「重命名」菜单项对引用(外部)文件也会显示。

### 修复
- **兼容 Flutter 3.32 的 `InlineSpan` 类型变更** — `SmoothMarkdown` 的 `widget.textSpan` / `widget.text` 返回类型放宽,`_extractSpan` 中强制转换为 `TextSpan?`。

## 1.0.0 (build 2) — 2026-05

- 首个发布版本。基础 Markdown / HTML 阅读、文档库管理、阅读设置、明暗主题、关于页、内置更新检查。
