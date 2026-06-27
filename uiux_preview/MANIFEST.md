# 简兮阅读器 · UI/UX 优化方案视觉稿索引

> 本目录为 `UIUX优化计划.md` 的可视化交付物。
> 沙箱环境浏览器二进制下载受限，无法自动截图；**所有视觉设计请通过 `index.html` 在浏览器中查看**。

## 启动预览

```bash
cd /workspace/uiux_preview
python3 -m http.server 8123
# 然后访问 http://localhost:8123/
```

预览已就绪（服务由 `job-aa4e0d13dbf64bd9913d9c6221b2c34c` 启动在 8123 端口）。

## 章节定位表

预览页为单页长滚动布局，自上而下对应 `UIUX优化计划.md` 的章节：

| Section ID | 章节 | 内容 | 关键展示 |
|---|---|---|---|
| `.masthead` | 报头 | "简兮 UI/UX 界面优化方案" + 版本/日期元数据 | Fraunces 88pt 衬线大标题 + 罗马数字 0277 |
| `.lede` | 导语 | 一句话定位 + 设计系统 4 个维度 | 26pt 衬线正文 + 8 项 spec |
| `.index-grid` | 目录 | 6 章索引卡 | 数字 + 中文章节名 + 标签 |
| `#ch1` | **I · 书架** | Library 整页 + 文档卡组件对比 | **3 个并排手机框** |
| `#ch2` | **II · 阅读** | Reader 整页 + 目录抽屉组件对比 | **3 个并排手机框** |
| `#ch3` | **III · 设置** | Settings 整页对比 | **2 个并排手机框** |
| `#ch4` | **IV · 液态玻璃** | 浅色 / 暗色玻璃面对比 | 300×200 卡对比 |
| `#ch5` | **V · 排版** | Inter vs Noto Serif SC + Fraunces | 24px 标题 + 14px 正文 |
| `#ch6` | **VI · 色彩** | 12 色标签 + 3 主色 + 3 语义色 | 色板网格 |

## 设计令牌（在本预览中可直接验证）

| 令牌 | 值 | 用途 |
|---|---|---|
| `--paper` | `#F4EFE6` | 简牍米黄（主背景） |
| `--ink` | `#1A1714` | 墨色（主文字） |
| `--cinnabar` | `#B33A3A` | 朱砂（强调 / 进度 / 阅读指示） |
| `--bronze` | `#7A5C3E` | 青铜（次要强调） |
| `--jade` | `#4A6B4E` | 玉绿（成功 / 书签） |
| `--indigo` | `#2A3A5C` | 靛蓝（链接） |
| `--t-17` | 16px | 标题字号（Noto Serif SC） |
| `--s-6` | 24px | 主页面内边距 |
| `--r-3` | 14px | 主卡片圆角 |

## 字体映射

- **Display 西文**: Fraunces (variable, 9-144 opsz, italic for accent)
- **Display 中文**: Noto Serif SC (思源宋体) 700
- **UI 西文 / 数字**: Inter 400/500/600/700
- **Monospace / 元数据**: JetBrains Mono 400/600

## 关键组件对照（Before / After）

### I-1 Library 整页

| 维度 | Before | After |
|---|---|---|
| 顶栏 | 36×36 蓝渐变图标 + "书架" + 2×40×40 icon | 32×32 墨色"简"字 mark + 双行 eyebrow/title + 单 tune chip |
| 视图切换 | 无显式切换按钮 | List / Shelf Segmented pill（墨色激活） |
| 文档卡 | 48×48 类型徽标（MD/TXT/HTML） | 编号 `i. ii. iii.` + 标题 + 标签色块 + 3px ⋯ 菜单 |
| 标签 | 无 | 4 色：技术/文学/设计/编程（朱砂/靛蓝/玉绿/青铜） |
| FAB | 60×60 蓝色 + | 52×52 朱砂红 + 0.32 alpha glow |
| 底栏 | 2 tab + 20px 圆角 + 蓝灰激活 | 2 tab + 28px 圆角 + 文字 + 朱砂 dot 激活态 |
| 背景 | 白 | 简牍米黄 + 50px 竹简纹 |

### I-2 文档卡

| 字段 | Before | After |
|---|---|---|
| 类型徽标 | 48×48 蓝/粉/绿硬色 | 取消，改用衬线编号 |
| 标题 | Inter 15/600 | Noto Serif SC 15/600 |
| 状态点 | 与标题同行（被裁切） | meta 行内 · 与标签并列 |
| meta | 12px 灰 1 行 | 11px 灰 + 标签 chip + 进度 % |

### II-1 Reader 整页

| 维度 | Before | After |
|---|---|---|
| AppBar | 5 控件（back + title + 4 actions） | 3 控件（back + 章节标题 + 2 actions） |
| 标题区 | 1 行 Inter 14 | 双行：mono 小字 `CH · 08/12` + Noto Serif SC 14 |
| 进度条 | 3px 蓝 | 2px 朱砂 + 章节节点圆点 |
| 标题字号 | Inter 28/700 | Noto Serif SC 26/700 + meta line `CHAPTER Ⅷ` |
| 段落首字 | 无 | Drop cap 朱砂 42px 衬线（Fraunces 数字 / Noto Serif SC 中文） |
| 引用 | 无 | 3px 朱砂左竖线 + Fraunces italic 18 |
| 章节标记 | 无 | `§` 朱砂 italic + Noto Serif SC 19/700 |
| "上次阅读" | 顶部 17px 蓝底 2s 消失 | 底部墨底 5s+ 永驻，"忽略"/"继续"双按钮 |

### II-2 目录抽屉

| 维度 | Before | After |
|---|---|---|
| 高度 | 48px dense | 56px regular |
| 层级辨识 | 颜色（H1 黑、H2 灰、H3 浅灰） | 3px 左侧色条（H1 朱砂、H2 青铜、H3 浅灰） |
| 字体 | Inter 14/13/12 | Noto Serif SC H1 700 / Inter H2 13 / Inter H3 12 |
| 顶部 | 仅标题 | 标题 + eyebrow `CONTENTS · 12/30` + 24×4px 拖动条 |
| 底部 | 无 | 固定 "↑ 返回顶部" + mono 百分比 |

### III-1 Settings 整页

| 维度 | Before | After |
|---|---|---|
| 入口 | 3 个圆角白卡 | 5 个分组（外观 / 阅读 / 文档 / 存储 / 关于） |
| 顶栏 | 48×48 灰渐变齿轮 + "设置" + 48×48 笑脸 | 衬线数字 Ⅲ + "设置" + 副标题 "Preferences" + 2 个 iconbtn |
| 陪伴图标 | 48×48 笑脸（功能不明） | **删除** |
| 行内布局 | Card + icon 36×36 | 1px 圆角浅色 + icon 32×32 浅色底 |
| 分组标签 | 无 | JetBrains Mono 10px + 0.18em letter-spacing 朱砂色 |
| 背景 | #F2F2F7 灰 | 简牍米黄 + 1px 墨色顶部分割线 |

### IV-1 液态玻璃

| 维度 | Before | After |
|---|---|---|
| 浅色 backdrop | 0.4 alpha 白 + 蓝 0.05 渐变 | 0.72 alpha 纸色 + 顶光 + 内描边 + 8px 阴影 |
| 暗色 rim | 5 色（cyan/mint/rose/gold/blue） | 1 色 cyan（弱化） |
| 模糊 | blur(20px) | blur(28px) saturate(160%) |

### V-1 排版

| 维度 | Before | After |
|---|---|---|
| 中文 | Inter fallback（无衬线张力） | Noto Serif SC 700（思源宋体） |
| 西文标题 | Inter 700 | Fraunces 500/-0.015em (italic 强调) |
| 西文代码 | Inter | JetBrains Mono |

### VI-1 色彩

| 角色 | Before | After |
|---|---|---|
| 主背景 | #FFFFFF 纯白 | #F4EFE6 简牍米黄 |
| 主文字 | #000000 纯黑 | #1A1714 墨色 |
| 强调 | #0066CC 纯蓝 | #B33A3A 朱砂 |
| 二级强调 | #5856D6 紫 | #7A5C3E 青铜 |
| 成功 | #34C759 绿 | #4A6B4E 玉绿 |
| 链接 | #0066CC | #2A3A5C 靛蓝 |
| 标签色板 | 6 色 | 10 色语义化 |

## 拍摄 / 导出建议

如需将预览导出为 PNG / PDF，可：

1. **本地浏览器** (推荐)：Chrome 打开 `http://localhost:8123/` → DevTools → Toggle Device Toolbar → iPhone 13 Pro → 截屏
2. **全页 PDF**：Chrome → 打印 → 另存为 PDF
3. **单组件截图**：开发者工具 → 选中 `.phone-frame` → 节点截图
4. **若远程需 headless 截图**：在本地 `npx playwright install chromium` 后运行 `node snap.js`

snap.js 留作本机使用：

```js
// snap.js
const { chromium } = require('playwright');
// ... 已写好 13 个截图 (00-full, 01-masthead, 02-ch1-pair, ...)
```
