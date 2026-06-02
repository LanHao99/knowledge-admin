# study_manager.gd (StudyManager)

> **路径**: `res://scenes/business_logic/study_manager.gd`
> **继承**: `Manager`
> **类型**: 逻辑层

## 概述
管理 SRS（间隔重复）学习会话的完整生命周期：启动会话、翻卡、答题、跳过、推进队列以及结束统计。

## 公共方法

### `set_deck_manager(deck_manager: DeckManager) -> void`
**输入**: `deck_manager` (DeckManager) — 牌组业务管理器。
**输出**: 无。
**说明**: 注入 DeckManager。

---

### `set_card_manager(card_manager: CardManager) -> void`
**输入**: `card_manager` (CardManager) — 卡片业务管理器。
**输出**: 无。
**说明**: 注入 CardManager。

---

### `set_note_manager(note_manager: NoteManager) -> void`
**输入**: `note_manager` (NoteManager) — 笔记业务管理器。
**输出**: 无。
**说明**: 注入 NoteManager（可选）。

---

### `start_session(deck_id: int, new_limit: int = 20, review_limit: int = 100) -> Dictionary`
**输入**:
- `deck_id` (int) — 目标牌组 ID。
- `new_limit` (int) — 新卡上限，默认 20。
- `review_limit` (int) — 复习卡上限，默认 100。

**输出**: 返回标准字典。成功时 `data` 为 `{counts: {new, learning, review, total}}`。
**说明**: 开启学习会话。从 CardManager 获取学习队列，按 learning → new → review 顺序排列，发射 `session_started` 和第一张卡片的 `card_shown` 信号。

---

### `end_session() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典。成功时 `data` 为统计信息字典（含 `done`、`remaining`、`answers` 等）。
**说明**: 结束学习会话并清理内存状态。发射 `session_ended` 信号后重置所有运行时变量。

---

### `is_session_active() -> bool`
**输入**: 无。
**输出**: `bool` — 激活返回 `true`。
**说明**: 判断会话是否处于激活状态。

---

### `get_current_card() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典。成功时 `data` 为 `CardEntity` 或 `null`。
**说明**: 获取当前卡片。会话未激活或索引越界时返回 `null`。

---

### `show_answer() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典。成功时 `data` 为当前 `CardEntity`。
**说明**: 显示答案面（翻卡）。将会话状态置为 `_showing_back = true` 并发射 `card_shown` 信号。

---

### `answer(rating: int) -> Dictionary`
**输入**: `rating` (int) — 用户评分（1~4，对应 Again/Hard/Good/Easy）。
**输出**: 返回标准字典。成功时 `data` 为 `{next_card, counts, interval}`。队列为空时 `next_card` 为 `null` 并自动调用 `end_session()`。
**说明**: 回答当前卡片并推进队列。调用 CardManager 计算间隔，记录答题到会话统计，从队列移除当前卡片（Again 时重新追加），发射 `card_answered`、`queue_updated` 和下一张卡片的 `card_shown` 信号。

---

### `skip_card() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典。成功时 `data` 为下一个 `CardEntity` 或 `null`。
**说明**: 跳过当前卡片并推进到下一张。将当前卡片移至队列末尾，发射 `queue_updated` 和 `card_shown` 信号。队列为空时返回 `null`。

---

### `undo_last_answer() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典。当前固定返回失败。
**说明**: 撤销上一次答案（预留能力，当前返回未实现）。

---

### `get_session_progress() -> Dictionary`
**输入**: 无。
**输出**: `Dictionary` — `{total, done, remaining, new_seen, review_seen, elapsed_ms}`。
**说明**: 获取当前会话进度。会话未创建时返回全零字典。

## 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `session_started` | `deck_id: int, counts: Dictionary` | 学习会话已启动，附带队列分布统计 |
| `session_ended` | `stats: Dictionary` | 学习会话已结束，附带完整统计信息 |
| `card_shown` | `card: CardEntity, is_back: bool` | 卡片被展示；`is_back=true` 表示答案面 |
| `card_answered` | `card: CardEntity, rating: int, next_interval: String` | 用户对卡片做出评分回答 |
| `queue_updated` | `counts: Dictionary` | 学习队列分布发生变化 |
