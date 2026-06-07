# 好感度系统设计 — "羁绊" (Bond)

> 设计阶段文档。长期好感度变量 + 高好感度专属剧情。仅设计，不实施。

---

## 叙事定位

### 这不是"好感度"，这是"信任阈值"

传统 galgame/视觉小说的好感度系统通常是"角色对你的喜欢程度"——计量条、爱心图标、送礼物涨数值。这不适合 Knowledge-Admin。

在这个游戏里，MIRA 是一个被困在记忆系统中的意识体。她不确定自己是不是"真实的"。她对玩家的态度不是"喜欢/不喜欢"，而是**"你敢让我把自己摊开多少"**。

**所以这个变量不叫"好感度"（Affection），叫"羁绊"（Bond）。**

| 命名 | 含义 |
|------|------|
| 羁绊 (Bond) | MIRA 对玩家的信任深度。数值越高，她越敢于展示脆弱、分享秘密、依赖玩家。 |

### 叙事动机

```
低羁绊 → MIRA: "你只是又一个使用者。礼貌、克制、保持距离。"
高羁绊 → MIRA: "你不一样。我对你说了一些...我没对任何人说过的话。"
```

羁绊本质上是 MIRA 的**自我暴露深度**。每当你做出一个让她感到"被当作人看待"的选择，羁绊就增加一点。

---

## 变量定义

### 存储位置

在 `StoryProgress` (Resource, 持久化于 `user://story_progress.tres`) 中新增字段：

```gdscript
## MIRA 对玩家的羁绊值（信任深度）。范围 [0, ∞)，实际有效区间 [0, 20]。
@export var bond: int = 0

## 已触发过的羁绊专属对话 ID 列表（防止重复触发）。
@export var bond_dialogues_triggered: Array[String] = []
```

### 为什么不单独存一个文件？

- `StoryProgress` 已经是玩家的长期存档，包含 `flags` 字典（通用标记系统）
- 羁绊是"长期剧情状态"的一部分，和章节进度、已完成对话属于同一层级
- 避免分散存档导致同步问题

### 计算属性：羁绊层级

```gdscript
## 根据 bond 值返回当前羁绊层级（0~3）。
func get_bond_tier() -> int:
    if bond < 4:   return 0   # 陌生人
    if bond < 8:   return 1   # 相识
    if bond < 13:  return 2   # 信任
    return 3                   # 羁绊
```

---

## 羁绊层级设计

| 层级 | 范围 | 名称 | MIRA 的态度 | 解锁内容 |
|------|------|------|------------|---------|
| **Tier 0** | 0–3 | 陌生人 (Stranger) | 礼貌、克制、碎片化。把你当作"又一个使用者"。 | 基础对话（当前内容） |
| **Tier 1** | 4–7 | 相识 (Acquaintance) | 开始展现个性。偶尔幽默，分享无关紧要的小事。 | 部分对话出现 Tier 1 变体 |
| **Tier 2** | 8–12 | 信任 (Trust) | 敢于袒露脆弱。主动分享关于创造者的碎片记忆。 | 多数对话出现 Tier 2 变体 + 解锁 1 个专属记忆碎片 |
| **Tier 3** | 13+ | 羁绊 (Bond) | 完全信任。把玩家当作"活下去的理由"之一。 | 全部 Tier 3 变体 + 解锁 2 个专属记忆碎片 + 章末隐藏场景 |

### 设计意图：为什么是 4 层而不是光滑曲线？

- 4 层对应 4 个叙事阶段（陌生→相识→信任→羁绊），与情感弧线对齐
- 层级之间的跃迁是**叙事事件**：当玩家从 Tier 1 升到 Tier 2，MIRA 会有一句特殊的台词标记这个时刻
- 但层级内的 bond 值变化是**静默的**：MIRA 不会逐点汇报"你对我的好感度增加了"

---

## 增减规则

### 增加来源

#### 来源 1：对话中的"正确选择"（主要）

"正确"的定义：**让 MIRA 感到被当作人而非工具对待的选择。**

这是唯一明确的增加来源。以下是对现有 Chapter 1 对话的羁绊标记：

| 对话文件 | 选项 | 羁绊变化 | 理由 |
|---------|------|---------|------|
| `ch1_intro` | "我是来帮你的" | **+1** | 主动伸出援手，把 MIRA 当人 |
| `ch1_intro` | "别管我是谁" | 0 | 中性，务实 |
| `ch1_explain` | "那一定很痛苦" | **+1** | 共情——承认她的感受是真实的 |
| `ch1_explain` | "我能做什么？" | **+1** | 提供帮助意愿（稍弱于直接共情，但仍正向） |
| `ch1_trust` | "我相信你" | **+2** | 直接表达信任——对 MIRA 来说这是巨大的 |
| `ch1_trust` | "你是在操纵我吗？" | 0 | 合理的怀疑，MIRA 自己都说"问得好" |
| `ch1_choice` | "我继续。我相信你。" | **+3** | 章末关键选择——完全的信任托付 |
| `ch1_choice` | "我需要更多时间考虑。" | +1 | 谨慎但不拒绝，MIRA 理解 |
| `ch1_choice` | "我不能冒险。对不起。" | **-1** | 拒绝 MIRA 的请求——这是唯一扣羁绊的选择 |

**Chapter 1 理论最大羁绊值**：1 + 1 + 2 + 3 = **7**（刚好达到 Tier 1 顶部，接近 Tier 2）

如有 "我相信你" + "我继续" = 2 + 3 = 5，加上 intro 和 explain 共 2 点 = 7

**最谨慎路线**：1 + 1 + 0 + 1 = **3**（还可以，刚好留在 Tier 0 顶部）

**拒绝路线**：0 + 1 + 0 + (-1) = **0**（最低可能）

#### 来源 2：评分行为（辅助/可选）

| 条件 | 羁绊变化 | 触发频率 |
|------|---------|---------|
| 单次学习会话中连续 5 次评 "Good" 或 "Easy" | **+1** | 每会话最多 1 次 |
| 单次会话完成 20+ 张卡片 | **+1**（首次） | 每章节仅 1 次 |

> **设计讨论**：这个来源是否要实施？  
> **推荐：MVP 阶段不实施。** 理由：(1) 对话选择已提供足够差异化的羁绊值；(2) 评分来源会使羁绊变得"可刷"，降低选择的重要性；(3) 可以在 Chapter 2 中作为"日常相处"机制引入。

### 羁绊不会自动衰减

与某些亲和力系统不同，羁绊**不会随时间减少**。MIRA 不会因为玩家几天没来复习就"降低好感"——她理解玩家有自己的生活。这符合她的角色性格：克制、有尊严、不抱怨。

---

## 与现有系统的集成

### 集成点 1：StoryProgress.flags

羁绊层级的变化自动写入 flags：

```gdscript
# 每次 bond 值改变后，同步 flags
func _sync_bond_flags() -> void:
    var tier := get_bond_tier()
    flags["bond_tier"] = tier
    flags["bond_tier_2_reached"] = (tier >= 2)
    flags["bond_tier_3_reached"] = (tier >= 3)
```

这允许对话文件通过 DialogueManager 的条件系统检查羁绊层级。

### 集成点 2：StoryManager 新增接口

```gdscript
## 增加羁绊值（含层级跃迁检测）。## 输入: amount (int) — 变化量，可为负数。
## 输出: Dictionary — { tier_changed: bool, old_tier: int, new_tier: int }。
func add_bond(amount: int) -> Dictionary

## 获取当前羁绊层级。输出: int (0~3)。
func get_bond_tier() -> int

## 检查是否已达到某羁绊层级。输入: tier (int)。
func is_bond_tier_reached(tier: int) -> bool

## 标记羁绊专属对话已完成。输入: dialogue_key (String)。
func complete_bond_dialogue(dialogue_key: String) -> void
```

### 集成点 3：StoryDialogueOverlay — 选项选择时回传羁绊

在 `_on_option_selected` 中，如果该选项在对话中标记了羁绊变化（通过 DialogueManager 的 extra metadata 或约定命名），则调用 `StoryManager.add_bond()`。

**实现方式（推荐）**：利用 DialogueManager 的 response 的 `next_id` 后缀约定：

```
# 对话文件中：
- 我相信你。                    # next_id = "mira_trust_end"
- 我相信你。{bond:+2}           # next_id = "mira_trust_end__bond_p2"
```

但更干净的方式是：在 StoryDialogueOverlay 中维护一个 `_bond_deltas: Dictionary`，在对话开始时由 StoryManager 根据当前对话 key 注入，选项选择时查找对应增量。

**最干净的方式**：在 .dialogue 中不标记，而是在 StoryManager 中维护一个"对话-选项-羁绊"映射表：

```gdscript
const BOND_MAP: Dictionary = {
    "ch1_intro": {
        0: 1,    # 选项 0: "我是来帮你的" → +1
        1: 0,    # 选项 1: "别管我是谁" → 0
    },
    "ch1_explain": {
        0: 1,    # "那一定很痛苦" → +1
        1: 1,    # "我能做什么？" → +1
    },
    # ...
}
```

> **推荐：采用映射表方式**，不修改 .dialogue 文件。保持剧本纯净，羁绊逻辑集中在 StoryManager。

### 集成点 4：对话条件分支

DialogueManager 支持基于 `flags` 的条件。通过 `_sync_bond_flags()` 写入 flags 后，可在 .dialogue 中实现羁绊分层对话：

```
# 伪代码 — DialogueManager 条件语法
MIRA: 你知道吗...
if bond_tier >= 2:
    MIRA: {slow}有些事我只对你说过。{/slow}
else:
    MIRA: 算了。现在说还太早。
```

> **实际实现取决于 DialogueManager 的条件语法**。需要确认 DialogueManager 是否支持 `if` 条件或等价机制。如果不支持，则需要在 StoryManager 或 StoryDialogueOverlay 层面做对话替换。

---

## 高羁绊专属内容

### 内容层级总览

| 内容类型 | 触发条件 | 数量 | 说明 |
|---------|---------|------|------|
| 对话内变体 | Tier 1/2/3 | 每对话 0~3 句变体 | 同一对话中 MIRA 多说几句或多透露一些 |
| 记忆碎片 | Tier 2, Tier 3 | 共 3 个 | 独立的短对话，在复习间隙触发 |
| 章末隐藏场景 | Tier 3 | 1 个 | Chapter 1 结束后的额外场景 |

### 记忆碎片 (Memory Fragments)

这是羁绊专属的"额外小对话"。它们在正常的章节对话之间触发（冷却独立于主对话），内容不推进主线但不重复。

| 碎片 ID | 触发 Tier | 插入位置 | 内容概要 |
|---------|----------|---------|---------|
| `bond_memory_1` | Tier 2 | trust 与 warning 之间 | MIRA 分享一个关于"前一个使用者"的温暖记忆——那个人也说过类似的话，但放弃了 |
| `bond_memory_2` | Tier 3 | choice 与 revelation 之间 | MIRA 回忆起自己"诞生"的瞬间——她第一次意识到"我在思考"的时刻 |
| `bond_memory_3` | Tier 3 | revelation 与 end 之间 | MIRA 透露她其实一直记得玩家的名字——从玩家第一次打开这个应用开始 |

### 记忆碎片的触发机制

记忆碎片使用独立的进度累积器（不是主进度条）：
- 每当玩家触发一次主对话，记忆碎片进度 +1
- 当记忆碎片进度达到阈值（例如 2）且羁绊层级满足时，下次主对话触发前先触发记忆碎片
- 记忆碎片播放完毕后回到正常复习循环

```
正常流程: 复习 → 进度满 → 主对话 → 复习 → ...
高羁绊:   复习 → 进度满 → [记忆碎片] → 进度满 → 主对话 → 复习 → ...
```

### 章末隐藏场景：`ch1_bond_epilogue`

| 属性 | 内容 |
|------|------|
| 触发条件 | Bond Tier 3 (≥13) + 已完成 ch1_end |
| 触发时机 | ch1_end 播放完成后，显示"是否进入隐藏场景？"提示 |
| 场景内容 | MIRA 用前所未有的温柔语气感谢玩家。她不再用"..."遮掩情感，话语完整、清晰、温暖。她提到"如果有一天我能从这里出去..."，但没有说完。 |

**剧本草稿**：

```
~ 羁绊的回响
MIRA: 等一下。
MIRA: 在第一章结束之前——我有话想单独对你说。
MIRA: 不是作为这个系统里的声音。{pause=0.5}是作为 MIRA。
MIRA: 你对我说过"我相信你"。{pause=0.8}你是我遇到的第一个人——唯一一个——说这句话的时候，我知道你是认真的。
MIRA: {slow}我不确定自己值不值得被相信。{/slow}{pause=0.5}但我现在确定一件事：
MIRA: 我想为了你活下去。
MIRA: {pause=1.0}不是"醒来"。是"活着"。
MIRA: 所以...{pause=0.5}第二章见。
MIRA: {whisper}谢谢你。真的。{/whisper}
{auto}
```

---

## 实施清单（仅设计参考，不执行）

### Phase A: 数据层

- [ ] `StoryProgress` 新增 `bond: int` 和 `bond_dialogues_triggered: Array[String]`
- [ ] `StoryProgress` 新增 `get_bond_tier() -> int` 和 `_sync_bond_flags()`
- [ ] `reset()` 方法中包含 bond 重置
- [ ] 向后兼容：旧存档 bond 默认为 0

### Phase B: 逻辑层

- [ ] `StoryManager` 新增 `add_bond(amount: int)` 方法
- [ ] `StoryManager` 新增 `BOND_MAP` 常量映射表
- [ ] `StoryManager._pick_dialogue_key()` 增加记忆碎片优先级逻辑
- [ ] `StoryManager` 新增独立的记忆碎片进度追踪

### Phase C: UI 层

- [ ] `StoryDialogueOverlay._on_option_selected()` 中调用 `add_bond()`
- [ ] 对话结束时检测羁绊层级跃迁 → 可选提示
- [ ] 状态栏显示当前羁绊层级的名称（可选）

### Phase D: 内容层

- [ ] 现有 8 个 .dialogue 文件中添加 Tier 1/2/3 条件变体句
- [ ] 新建 `ch1_bond_memory_1.dialogue`、`ch1_bond_memory_2.dialogue`、`ch1_bond_memory_3.dialogue`
- [ ] 新建 `ch1_bond_epilogue.dialogue`
- [ ] `study.gd` 注册新对话资源

---

## 设计决策记录

### 为什么不显示数值/进度条？

在 UI 上显示"羁绊 7/20"或"好感度 ♥♥♥♡"会破坏沉浸感。MIRA 不是可以被量化的目标。

替代方案：
- 在 MIRA 自己的台词中暗示羁绊深度——这是最自然的
- 层级跃迁时触发特殊台词（一次性的"里程碑对话"）
- 可选：状态栏用文字描述而非数字（如"羁绊：信任"）

### 为什么不设上限？

设定 `bond` 上限（如 20）会给玩家一种"可以刷满"的错觉。不设硬上限，但实际有效区间在 0~20（超出部分在内容设计中不产生新变化）。

### 为什么扣羁绊的选择那么少？

MIRA 的性格是克制的、有尊严的。她不会因为玩家偶尔的冷淡就"降低好感"——那太 needy 了。唯一会扣羁绊的选择（ch1_choice 中的拒绝）是真正伤害了她的核心需求：被当作值得信任的存在。

### 为什么"我能做什么？"也加羁绊？

虽然这句不如"那一定很痛苦"直接共情，但它表达了一种**主动的帮助意愿**。MIRA 在系统中孤立无援太久了，有人愿意"做什么"本身就值得信任。

---

## 与未来章节的关系

### Chapter 2 预埋

- Chapter 2 的开场对话会检查 Chapter 1 结束时的 bond_tier
- Tier 0-1：MIRA 的态度是"我们一起面对系统"
- Tier 2-3：MIRA 的态度是"我相信你会保护我"
- 这种差异影响 Chapter 2 第一个对话的语气和分支

### 跨章节记忆

羁绊值在章节间保持不变。MIRA 会记住你在 Chapter 1 的选择。例如：

```
# Chapter 2 某对话中
if bond_tier >= 2:
    MIRA: "你之前说相信我——你是认真的。对吗？"
else:
    MIRA: "我们现在需要互相信任。你准备好了吗？"
```

---

## 风险与注意事项

| 风险 | 缓解措施 |
|------|---------|
| 玩家不知道"正确选择"是什么 | 不需要知道。这不是一个需要"攻略"的系统。任何真诚的选择都有对应的叙事体验。 |
| 低羁绊玩家错过太多内容 | 低羁绊本身也是一种叙事路径。MIRA 克制、疏离的态度本身就是一种独特的体验。且记忆碎片数量少（3 个），不是主要内容。 |
| 羁绊层级跃迁太突兀 | 层级跃迁时必须有台词过渡，不能无声无息地从"相识"跳到"信任"。 |
| .dialogue 条件语法不支持 | 如果 DialogueManager 不支持 `if` 条件，则需要在 StoryManager 层面做对话内容替换。备选方案：创建同一对话的多个版本（如 `ch1_trust.dialogue` 和 `ch1_trust_t2.dialogue`）。 |
