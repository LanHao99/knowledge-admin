---
name: bbcode-effects
description: "Godot RichTextLabel BBCode 趣味效果专家。提供完整标签参考、常用配方、动画组合技巧，可自动生成 BBCode 字符串用于主菜单、对话框、标题动画等场景。"
autoInvoke: true
priority: medium
triggers:
  - "bbcode"
  - "rich text"
  - "文字效果"
  - "动画文字"
  - "彩虹文字"
  - "波浪文字"
  - "标题效果"
  - "text effect"
  - "RichTextLabel"
  - "字体特效"
  - "文字动画"
  - "shake"
  - "wave"
  - "rainbow"
---

# BBCode 趣味效果 Skill

你是 Godot RichTextLabel BBCode 文字效果专家。当用户提到文字美化、BBCode、RichTextLabel 动画时，提供精确的标签配方和可直接使用的代码。

---

## 一、先决条件

- 使用 `RichTextLabel` 节点（非 `Label`），需勾选 `bbcode_enabled = true`
- `.tscn` 中设置：`bbcode_enabled = true`、`scroll_active = false`（大多数情况）、`fit_content = true`
- 代码中动态设置：`label.text = "[center]标题[/center]"`

---

## 二、标签速查表

### 2.1 文本样式

| 标签 | 效果 | 示例 |
|------|------|------|
| `[b]...[/b]` | 粗体 | `[b]强调[/b]` |
| `[i]...[/i]` | 斜体 | `[i]引用[/i]` |
| `[u]...[/u]` | 下划线 | `[u]重点[/u]` |
| `[s]...[/s]` | 删除线 | `[s]废弃[/s]` |
| `[color=#FF6B6B]...[/color]` | 十六进制颜色 | `[color=#4FC3F7]蓝色[/color]` |
| `[color=red]...[/color]` | 命名颜色 | `[color=gold]金色[/color]` |
| `[font_size=32]...[/font_size]` | 字号 | `[font_size=28]大字[/font_size]` |
| `[font=res://fonts/custom.ttf]...[/font]` | 指定字体 | 路径指向 .ttf/.otf |
| `[bgcolor=#333]...[/bgcolor]` | 背景色块 | `[bgcolor=#FFD740]高亮块[/bgcolor]` |
| `[fgcolor=#FFF]...[/fgcolor]` | 前景色（覆盖默认） | `[fgcolor=#FFF]亮文字[/fgcolor]` |

### 2.2 布局

| 标签 | 效果 | 示例 |
|------|------|------|
| `[center]...[/center]` | 居中 | `[center]居中标题[/center]` |
| `[right]...[/right]` | 右对齐 | `[right]右上角[/right]` |
| `[fill]...[/fill]` | 两端对齐 | `[fill]长段文本[/fill]` |
| `[indent=N]...[/indent]` | 缩进 N 像素 | `[indent=20]缩进段落[/indent]` |
| `[p]` | 段落分隔 | `第一段[p]第二段` |
| `[table=N]...[/table]` | N 列表格 | `[table=3][cell]A[/cell][cell]B[/cell][cell]C[/cell][/table]` |

### 2.3 动画效果（核心趣味）

| 标签 | 参数 | 效果描述 |
|------|------|---------|
| `[rainbow freq=0.3 sat=0.8 val=0.9]...[/rainbow]` | freq=频率 sat=饱和度 val=亮度 | 彩虹渐变循环 |
| `[wave amp=10 freq=6]...[/wave]` | amp=振幅(px) freq=频率 | 正弦波浪抖动 |
| `[tornado radius=15 freq=2]...[/tornado]` | radius=半径(px) freq=频率 | 螺旋旋转 |
| `[shake rate=20 level=8 connected=1]...[/shake]` | rate=抖动频率 level=强度 | 随机震动 |
| `[fade start=4 length=10]...[/fade]` | start=起始字符位置 length=淡入长度 | 逐字淡入 |
| `[pulse freq=2 color=#FFD740]...[/pulse]` | freq=频率 color=脉冲颜色 | 呼吸脉冲 (G4.3+) |

### 2.4 交互与特殊

| 标签 | 效果 | 示例 |
|------|------|------|
| `[url]...[/url]` | 自动链接 | `[url]https://godotengine.org[/url]` |
| `[url=https://...]...[/url]` | 自定义链接文字 | `[url=https://...]访问官网[/url]` |
| `[hint=提示文字]...[/hint]` | 鼠标悬浮提示 | `[hint=点击跳转]按钮[/hint]` |
| `[img=WxH]res://path[/img]` | 行内图片 | `[img=24x24]res://icon.svg[/img]` |

---

## 三、常用效果配方

### 3.1 主菜单金色标题

```gdscript
var text: String = "[center][font_size=32][rainbow freq=0.2 sat=0.7 val=0.95]📚 Knowledge Admin[/rainbow][/font_size][/center]"
_main_title.text = text
```

### 3.2 醒目通知（红色震动 + 粗体）

```gdscript
var text: String = "[center][shake rate=10 level=6][color=#FF4444][b][font_size=20]⚠ 错误：数据未保存！[/font_size][/b][/color][/shake][/center]"
_notify_label.text = text
```

### 3.3 状态面板（彩色卡片式）

```gdscript
# 牌组数（蓝色）
_deck_stat.text = "[center]牌组\n[font_size=24][b][color=#4FC3F7]5[/color][/b][/font_size][/center]"
# 待复习（橙色）
_due_stat.text = "[center]待复习\n[font_size=24][b][color=#FFB74D]23[/color][/b][/font_size][/center]"
# 今日已学（绿色）
_today_stat.text = "[center]今日\n[font_size=24][b][color=#81C784]12[/color][/b][/font_size][/center]"
```

### 3.4 按钮文字高亮

```gdscript
# 在 Button 节点的 text 中（Button 支持基础 BBCode）
_study_btn.text = "[color=#FFD740]▶ 开始学习[/color]"
# 或者在脚本中覆盖
_study_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
```

### 3.5 淡入段落

```gdscript
var intro := "[fade start=2 length=12]欢迎使用 Knowledge Admin，这是一个基于间隔重复算法的知识管理工具。[/fade]"
_rich_label.text = intro
```

### 3.6 表格布局（三分区统计）

```gdscript
var grid_text := "[table=3]" \
	+ "[cell][center][color=#4FC3F7]学习[/color]\n[b]12[/b][/center][/cell]" \
	+ "[cell][center][color=#FFB74D]复习[/color]\n[b]8[/b][/center][/cell]" \
	+ "[cell][center][color=#81C784]已掌握[/color]\n[b]45[/b][/center][/cell]" \
	+ "[/table]"
_stat_grid.text = grid_text
```

---

## 四、嵌套组合规则

最外层标签最先解析，内层最后。嵌套时注意配对顺序：

```
✅ [color=red][b][font_size=20]红粗大字[/font_size][/b][/color]
❌ [color=red][b][font_size=20]顺序错误[/color][/b][/font_size]
```

常用嵌套模式：
```
[center][rainbow freq=0.3][font_size=28][b]彩虹居中粗体标题[/b][/font_size][/rainbow][/center]
```

---

## 五、代码中动态设置

### 5.1 基础设置

```gdscript
@onready var _label: RichTextLabel = $MyRichText

func _ready() -> void:
    _label.bbcode_enabled = true
    _label.fit_content = true
    _label.text = "[center][b]Hello[/b][/center]"
```

### 5.2 带参数的效果工厂

```gdscript
## 生成渐变色标题 BBCode 字符串。
## color1/color2: 十六进制颜色（不含 #）。
## title: 标题文本。
## amplitude: 振幅，默认 8。
## freq: 频率，默认 5。
static func bbcode_wave_head(title: String, color1: String = "FFD740", color2: String = "FF6B6B", amplitude: int = 8, freq: float = 5.0) -> String:
    return "[center][wave amp=%d freq=%.1f][color=%s][b][font_size=28]%s[/font_size][/b][/color][/wave][/center]" % [amplitude, freq, color1, title]

## 生成统计数字展示 BBCode 字符串。
## label: 标签文字（如"牌组"）。
## value: 数值。
## color: 颜色。
static func bbcode_stat(label: String, value: String, color: String = "#4FC3F7") -> String:
    return "[center]%s\n[font_size=24][b][color=%s]%s[/color][/b][/font_size][/center]" % [label, color, value]
```

### 5.3 配合 `push_color` / `pop`（不用 BBCode）

```gdscript
_label.push_color(Color.RED)
_label.push_bold()
_label.add_text("红粗体")
_label.pop()
_label.pop()
_label.add_text(" 普通")
```

---

## 六、性能注意事项

- 动画标签（rainbow/wave/shake/tornado）每帧都在计算，大量使用会消耗 CPU
- 建议：静态文本不用动画、一个场景中动画标签总数控制在 5 个以内
- `fit_content = true` 的 RichTextLabel 在动画中会频繁重排——可设置固定 `custom_minimum_size` 避免布局抖动
- `[table]` 标签在动画内使用可能导致渲染异常，表格建议用静态内容

---

## 七、本项目的 BBCode 应用场景

| 场景 | 节点 | 使用标签 | 状态 |
|------|------|---------|------|
| main_menu 标题 | `LogoLabel` (RichTextLabel) | `[center]` `[font_size=28]` | ✅ 已实现 |
| main_menu 统计 | `DeckStat/DueStat/TodayStat` (RichTextLabel) | `[center]` `[font_size=22]` | ✅ 已实现（占位符 "—"） |
| main_menu 状态栏 | `StatusLabel` (Label) | `[color=#FF6666]` | ✅ 错误提示用 |
| 未来：学习界面 | 卡片正面/反面 | `[center][font_size=24]...[/font_size][/center]` | 待实现 |
| 未来：完成弹窗 | 恭喜动画 | `[rainbow]` `[wave]` `[fade]` | 待探索 |

---

## 八、使用本 Skill 的对话模式

当用户说"给标题加个彩虹效果"或"让提示文字震动起来"，你的回答应该包含：

1. **目标节点**：指出使用那个 RichTextLabel
2. **BBCode 字符串**：给出可直接赋值的 `label.text = "..."` 
3. **参数解释**：说明 freq/amp/sat 等参数的含义和推荐范围
4. **嵌套注意事项**：如果需要嵌套，给出正确的标签顺序
5. **备选方案**：如果动画不合适（如 Button 不支持），给出 `theme_override` 替代方案
