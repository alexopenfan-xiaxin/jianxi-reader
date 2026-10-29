# 字体说明

## 文件

| 文件 | 来源 | 说明 |
|---|---|---|
| `JianxiWenKai-Regular.ttf` | [LXGW WenKai](https://github.com/lxgw/LxgwWenKai) Regular | 子集化后的副本，见下文 |
| `OFL.txt` | 上游同名字体授权文本 | SIL Open Font License 1.1，含 Reserved Font Name 与附加许可 |

## 我们对字体做了什么

生成脚本：`tool/subset_font.py`（`python3 tool/subset_font.py`）。

1. **子集化**：只保留 GB2312 全部 6763 个汉字、ASCII、中英文标点、应用界面与文档里出现的全部字符。体积从 25,575,676 字节降到约 3.7 MiB，覆盖范围之外的字形由系统字体兜底。
2. **改名**：这是 OFL 的要求，不是偏好。OFL.txt 里声明了 Reserved Font Name（`霞鹜`、`霞鶩`、`落霞孤鹜`、`落霞孤鶩`、`LXGW`），其附加许可只覆盖"网页字体投递"场景；子集化后嵌入 APK 属于 Modified Version，不能再使用这些保留名。因此内部 family / PostScript 名改为 `JianxiWenKai` / `JianxiWenKai-Regular`，与 `pubspec.yaml` 的 `family` 一致。
3. 字形轮廓、版权声明（name ID 0）与授权声明（name ID 13/14）原样保留。

## 改字体时要一起改的地方

- `pubspec.yaml` 的 `family` 与 `asset` 路径
- `lib/core/app_settings_controller.dart` 中 `ReadingFontFamily.wenkai` 与 `AppFontFamily.lxgw` 的 fontFamily 字符串

界面上仍然显示字体的中文名「落霞孤鹜」。
