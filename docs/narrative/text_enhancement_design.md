# 文字表现系统增强方案

> 将现有的静态 RichTextLabel 对话升级为带有打字机动画、情绪效果和节奏控制的动态文字表现系统。

---

## 设计目标

| 目标 | 当前状态 | 目标状态 |
|------|---------|---------|
| 文字出现方式 | 整段显示 | 逐字打字机效果（可变速） |
| 情绪表达 | 仅 BBCode 颜色 | 抖动、闪烁、渐入、暂停、语速变化 |
| 对话节奏 | 统一点击推进 | 自动推进 + 手动推进混合，暂停标记 |
| MIRA 碎片状态 | 无 | 故障效果（glitch）、字符随机跳动 |
| 性能 | 无动画 | 60fps 稳定，低性能设备可降级 |

---

## 系统架构

```
StoryDialogueOverlay (CanvasLayer)
  └── ContentLabel (RichTextLabel)
        └── TextAnimationController (Node)
              ├── typewriter 效果: 逐字显示
              ├── shake 效果: 文字抖动
              ├── glitch 效果: 故障风格
              ├── wave 效果: 波浪起伏
              └── pause 控制: 延迟/等待
```

### 新增文件

| 文件路径 | 职责 |
|---------|------|
| `res://game/dialogue/text_animation_controller.gd` | 文字动画控制器 |
| `res://game/dialogue/text_effects.gd` | 独立文字特效（shake/glitch/wave） |

### 修改文件

| 文件路径 | 修改内容 |
|---------|------|
| `game/dialogue/story_dialogue_overlay.gd` | 集成 TextAnimationController |
| `game/dialogue/story_dialogue_overlay.tscn` | 添加动画控制器节点 |

---

## 对话标记语言（Dialogue Markup Tags）

在 .dialogue 文件中使用自定义标记来控制文字表现：

### 基础标记

```
[速度标记]
{fast}文字{/fast}     — 快速显示（适合激动/紧急）
{slow}文字{/slow}     — 慢速显示（适合沉思/沉重）
{pause=0.5}          — 暂停 0.5 秒后继续
{auto}                — 此句结束后自动推进到下一句（无需点击）

[情绪标记]
{shake}文字{/shake}   — 文字抖动（震惊/恐惧/系统不稳定）
{glitch}文字{/glitch} — 故障效果（MIRA 碎片状态）
{fade}文字{/fade}     — 文字渐入（温柔/回忆）
{whisper}文字{/whisper} — 缩小字号 + 灰色（悄悄话）

[角色标记]
{system}文字{/system} — 系统风格的文字（等宽字体、绿色）
```

### 使用示例（.dialogue 文件）

```
~ 初次相遇
系统: {system}检测到学习进度异常...正在建立连接...{/system}

???: 你...{pause=0.8}好。
???: {slow}我叫 MIRA。我已经在这套记忆系统里待了...{pause=1.0}很久。{/slow}
???: {fast}等等——你在评分？你在{shake}真的{/shake}在评分！{/fast}
```

---

## TextAnimationController 设计

### 核心参数

```gdscript
# 打字机速度
var default_speed: float = 0.03        # 默认每字 30ms
var fast_speed: float = 0.01           # 快速每字 10ms
var slow_speed: float = 0.08           # 慢速每字 80ms

# 标点符号自动暂停
var punctuation_pauses: Dictionary = {
    "。": 0.3,  # 句号停 300ms
    "，": 0.15, # 逗号停 150ms
    "！": 0.25, # 感叹号停 250ms
    "？": 0.25, # 问号停 250ms
    "…": 0.4,  # 省略号停 400ms
    ".": 0.3,
    ",": 0.15,
    "!": 0.25,
    "?": 0.25,
}

# 动画开关
var enable_typewriter: bool = true     # 打字机总开关
var enable_effects: bool = true        # 特效总开关
var enable_auto_advance: bool = false  # 自动推进总开关
```

### 公共方法

```gdscript
## 开始播放一行对话（带打字机效果）。## 输入:
##   raw_text (String) - 包含标记的原始文本。
##   on_complete (Callable) - 打字机完成后的回调。
## 输出: 无。
func play_line(raw_text: String, on_complete: Callable = Callable()) -> void

## 立即完成当前打字机动画（跳过动画直接显示全部文字）。## 输入: 无。
## 输出: 无。
func skip_to_end() -> void

## 检查当前是否正在播放动画。## 输入: 无。
## 输出: bool。
func is_playing() -> bool

## 设置全局打字机速度倍率（用于设置中的速度调节）。## 输入: multiplier (float)。
func set_speed_multiplier(multiplier: float) -> void
```

### 信号

```gdscript
signal typewriter_completed()           # 打字机完成
signal effect_triggered(effect: String) # 特效触发
```

---

## 标记解析流程

```
.dialogue 原始文本
        │
        ▼
┌─────────────────────┐
│  标记解析器          │
│  分离: 纯文本 +      │
│  标记位置 + 效果类型  │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│  RichTextLabel       │
│  设置完整 BBCode     │  ← 先隐藏，逐字 reveal
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│  打字机引擎           │
│  逐字增加 visible_    │
│  characters，遇到     │
│  标点自动暂停          │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│  特效引擎             │
│  遇到标记时触发对应    │
│  Tween 动画           │
└─────────────────────┘
```

---

## 实现策略

### 打字机效果核心思路

Godot 的 RichTextLabel 有一个 `visible_characters` 属性。通过 Tween 逐帧增加这个值即可实现打字机效果：

```gdscript
# 核心思路（伪代码）
var tween := create_tween()
tween.tween_method(
    func(v): rich_label.visible_characters = int(v),
    0.0,  # 从 0 开始
    float(total_chars),  # 到总字符数
    total_chars * default_speed  # 总时长
)
```

对于标记控制的速度变化，需要解析文本中的速度标记，分段处理。

### MIRA 故障效果

```gdscript
# glitch 效果：随机字符替换 + 抖动
func apply_glitch(char_range: Vector2i, duration: float) -> void:
    # 每隔 0.05s 随机替换 1-2 个字符为乱码
    # 同时给 RichTextLabel 加上位置抖动 Tween
```

### 性能降级方案

```gdscript
# 在 project.godot 或设置中
var performance_mode: String = "auto"  # "auto" | "high" | "low"

# low 模式: 关闭打字机效果，文字直接显示
# auto 模式: 检测帧率，低于 30fps 自动降级
```

---

## 与现有系统集成

### story_dialogue_overlay.gd 修改点

```gdscript
# 新增节点引用
@onready var _text_animator: TextAnimationController = $TextAnimationController

# 修改 _show_line() 
func _show_line(line) -> void:
    # ... 设置角色名 ...
    
    # 原来: _content_label.text = tr(line.text)
    # 改为: 启动打字机动画
    _text_animator.play_line(
        tr(line.text, "dialogue"),
        func(): _on_typewriter_done(line)
    )
    
    # 在打字机播放期间，点击卡片面板 = 跳过动画
    # 打字机完成后，点击卡片面板 = 推进到下一句

func _on_typewriter_done(line) -> void:
    # 如果是 {auto} 标记的行，自动推进
    if line.text.contains("{auto}"):
        await get_tree().create_timer(1.0).timeout
        _advance_dialogue()
```

### ClickHint 改进

打字机播放期间显示"点击跳过 →"，打字机完成后显示"点击继续 →"。

---

## 批量标记替换工具

为了减少手写标记的工作量，提供一个编辑器工具脚本：

```gdscript
# res://game/dialogue/dialogue_markup_tool.gd
# 功能:
# 1. 选中 .dialogue 文本 → 右键菜单 → 快速插入标记
# 2. 批量给 MIRA 的省略号添加 {pause} 标记
# 3. 预览打字机效果
```

---

## 可访问性

```gdscript
# 设置选项
var text_speed: float = 1.0         # 0.5x ~ 3.0x
var disable_animations: bool = false # 完全关闭动画（无障碍模式）
var disable_shake: bool = false      # 关闭抖动（晕动症友好）
```
