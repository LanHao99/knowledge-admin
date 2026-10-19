# card_db.gd (CardDB)

> **路径**: `res://src/data_access/card_db.gd`
> **继承**: `DBManager`
> **类型**: 数据层

## 概述
卡片数据访问层，封装卡片（cards 表）的 CRUD、到期查询、复习记录、批量移动与暂停恢复等操作，所有方法返回标准 `Dictionary`（含 `success`/`error`/`data` 字段）。

## 公共方法

### `create_card(note_id: int, deck_id: int, template_order: int, now_timestamp: int) -> Dictionary`
**输入**: note_id（关联笔记 ID）、deck_id（归属牌组 ID）、template_order（模板序号）、now_timestamp（软件 Unix 秒数，用于初始到期日）。
**输出**: 返回标准字典。成功时 `data` 为 CardEntity。
**说明**: 创建一张新卡片并返回创建后的实体对象。

### `get_card_by_id(card_id: int) -> Dictionary`
**输入**: card_id（卡片 ID）。
**输出**: 返回标准字典。成功时 `data` 为 CardEntity；未找到时为 null。
**说明**: 根据 ID 查询单张卡片。

### `update_card(card: CardEntity) -> Dictionary`
**输入**: card（待更新实体，要求 id > 0）。
**输出**: 返回标准字典。成功时 `data` 为 null。
**说明**: 更新整张卡片记录。

### `delete_card(card_id: int) -> Dictionary`
**输入**: card_id（卡片 ID）。
**输出**: 返回标准字典。成功时 `data` 为 null。
**说明**: 删除单张卡片。

### `delete_cards_by_note(note_id: int) -> Dictionary`
**输入**: note_id（笔记 ID）。
**输出**: 返回标准字典。成功时 `data` 为 int（删除数量）。
**说明**: 删除某个笔记下的全部卡片。

### `update_cards_deck_by_note(note_id: int, new_deck_id: int) -> Dictionary`
**输入**: note_id（笔记 ID）、new_deck_id（新牌组 ID）。
**输出**: 返回标准字典。成功时 `data` 为 int（更新数量）。
**说明**: 批量更新某个笔记下所有卡片的牌组归属。

### `get_due_cards(deck_id: int, queue_type: int, limit: int, now_timestamp: int) -> Dictionary`
**输入**: deck_id（牌组 ID）、queue_type（队列类型：0=new, 1=learning, 2=review）、limit（限制条数，≤0 表示不限制）、now_timestamp（软件 Unix 秒数）。
**输出**: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
**说明**: 查询指定队列的到期卡片。new/review 按天比较，learning 按秒级时间戳比较。

### `get_all_due_cards(deck_id: int, now_day_index: int, now_timestamp: int) -> Dictionary`
**输入**: deck_id（牌组 ID）、now_day_index（当前天数索引，review/new 使用）、now_timestamp（当前 Unix 时间戳，learning 使用）。
**输出**: 返回标准字典。成功时 `data` 为 `{new: Array, learning: Array, review: Array}`。
**说明**: 综合查询某牌组全部到期卡片（new/learning/review），一次返回三个队列的结果。

### `get_card_counts(deck_id: int) -> Dictionary`
**输入**: deck_id（牌组 ID）。
**输出**: 返回标准字典。成功时 `data` 为 `{new, learning, review, suspended, total}`。
**说明**: 查询牌组卡片数量统计，按队列分组计数并汇总 total。

### `record_review(card_id: int, rating: int, time_taken_ms: int, new_due: int, new_queue: int, new_reps: int, new_lapses: int, stability: float, difficulty: float, history_json: String, reviewed_at: int, new_step: int = -1) -> Dictionary`
**输入**: card_id（卡片 ID）、rating（评分 1~4）、time_taken_ms（答题耗时，毫秒）、new_due（新到期值）、new_queue（新队列）、new_reps（新复习次数）、new_lapses（新遗忘次数）、stability（新稳定性）、difficulty（新困难度）、history_json（新历史 JSON 字符串）、reviewed_at（本次评分的软件 Unix 秒数）、new_step（学习步进，-1 表示 Review）。
**输出**: 返回标准字典。成功时 `data` 为 null。
**说明**: 记录一次复习结果（单条更新），同时写入 `last_review_time` 为调用方传入的 reviewed_at，与历史 JSON 和调度采样保持一致。

### `move_cards_to_deck(card_ids: Array[int], new_deck_id: int) -> Dictionary`
**输入**: card_ids（卡片 ID 列表）、new_deck_id（新牌组 ID）。
**输出**: 返回标准字典。成功时 `data` 为 int（更新数量）。
**说明**: 批量移动卡片到新牌组，内部自动去重并过滤无效 ID（≤0）。

### `suspend_cards(card_ids: Array[int], suspended: bool = true) -> Dictionary`
**输入**: card_ids（卡片 ID 列表）、suspended（true 设为暂停；false 从暂停恢复为新卡队列，默认 true）。
**输出**: 返回标准字典。成功时 `data` 为 int（更新数量）。
**说明**: 批量暂停或恢复卡片。暂停时设 queue=SUSPENDED；恢复时仅将 queue=SUSPENDED 的卡片改为 NEW。

## 常量

| 常量 | 值 | 说明 |
|------|----|------|
| `_SECONDS_PER_DAY` | `86400` | 每天秒数（私有），用于计算到期天数索引。 |

## 复习日统计

get_today_studied_count(today_start_ts) 使用当前复习日的闭开区间 `[today_start_ts, today_start_ts + 86400)`，并要求 reps 大于零，排除未来复习和从未评分的卡片。数据层不读取 AppClock，时间由业务层显式传入。见 [日期和时间](../date_time.md)。
