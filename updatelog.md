# 更新日志

## 3.0.0-alpha.1 (build 290) — 3.0 Phase 0 止血

> 仅内部/小范围测试，不含 3.0 的新能力（文档包、阅读痕迹、全文搜索）。详细计划见 `docs/3.0-readiness.md`。

### 发布与供应链
- **签名硬失败** — 缺少 `key.properties`/签名 secret 时，Gradle 与 `publish.yml` 都直接失败，不再回退 debug 签名。
- **产物可验证** — 发布前用 `apksigner` 校验证书 SHA-256（`b76b05e9…`），APK 附 `SHA256SUMS`，Release 说明里带摘要与指纹。
- **版本单一来源** — 版本只写在 `pubspec.yaml`；artifact 名由它派生，CI 校验 `_fallbackBuildNumber` 与之一致。
- **通道守卫** — alpha/beta 版本不能用 stable 通道发布，避免预发布包推给全部用户。

### 更新链路
- **摘要校验** — 要求服务端返回 `x-apk-sha256`，边下载边计算并在安装前比对；缺失或不匹配一律拒绝。
- **fail-closed 版本判断** — 响应缺少版本头时按“已是最新”处理，不再默认有新版本。
- **跳转限制** — 只允许跳回更新主机自身，避免被引到第三方下载源。

### 数据
- **损坏隔离** — 书签、阅读历史、文档 ID 表逐条容错；整文件损坏先复制为 `*.corrupt-<ts>`，不再清空后覆盖。
- **进度不再被误清** — 只有本次会话真正读过（或从提示跳转）才保存进度；“接近顶部”不再等同于清除，清除改用 `clearProgress()`。
- **移出可撤销** — 单个“移出”先确认，之后 10 秒内可在提示条里撤销；被移出的文件暂存在 `.trash/` 而不是直接删除，启动时清理超过 24 小时的残留。
- **加载不再卡死** — 文档库并发加载时 `isLoading` 必定回落。

### 隐私与合规
- **关闭系统备份** — `allowBackup=false`，导入的文档镜像与阅读记录不再进入系统云备份。
- **收敛文件关联** — 移除 `text/plain` 的 VIEW 声明，简兮不再出现在所有 `.txt` 的“打开方式”里。
- **字体授权与体积** — 随包附上 LXGW WenKai 的 OFL 1.1 授权文本；字体子集化到 GB2312 全字集 + 界面字符（24.4 MiB → 3.6 MiB），并按 OFL 的保留字体名条款改名 `JianxiWenKai`（`assets/fonts/README.md` 记录改动）。

### 工程
- **CI 门禁** — 新增 Android release 构建与清单断言（versionCode/versionName/allowBackup/minSdk），以及版本元数据脚本检查。

### 数据地基（内部，无界面变化）
- **元数据 schema v1** — 文档元数据、标签、书签收进 `metadata/library.json`，每条文档记录带稳定 id；标签/置顶/最近打开不再散落在偏好设置里。
- **单一写入者 + 事务** — 所有变更排队写入，并发导入/重命名/删除不再互相覆盖。
- **迁移与快照** — 启动时从 2.x 布局迁移，迁移前把 `metadata/` 备份到 `metadata/backups/`；迁移幂等，损坏文件先隔离再重建。

## 2.9.9 (build 199) — 2026-10-28

> 2.9.5 之后直接以 2.9.9+199 发布；build 196–198 只存在于仓库，未单独出包，也无独立 tag。

### 体验优化
- **液态玻璃组件库迁移** — 阅读器 chrome、菜单与排序面板接入组件库，回退到圆角玻璃面板实现，玻璃强度固定在 0.9。
- **底部导航** — 改用 `GlassTabBar` 默认观感，移除强度滑杆并恢复底部 tab 宽度。

### 修复
- **HTML 文档** — 补齐外链失败处理，移除死解析路径；导入时传播引用源 URI，修正导入竞态与缓存节流。
- **数据恢复** — 完善 mindmap、TOC 与损坏数据的恢复路径。

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
