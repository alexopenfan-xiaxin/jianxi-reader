# 更新日志

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
