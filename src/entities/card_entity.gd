class_name CardEntity
extends RefCounted

# 卡片实体类，纯数据结构，对应数据库 cards 表的一行记录。
# 卡片是"学习单元"，是用户实际看到和复习的对象。一张 Card 关联一个 Note（通过 note_id）
# 和一个 Deck（通过 deck_id）。一张 Note 可生成多张 Card（通过 template_order 区分）。
# 队列状态（queue）和到期时间（due）是调度系统的核心字段。
# 不加入 Godot 节点树，由 Manager 持有引用，引用计数归零时自动释放。

# ── 队列常量（对齐 Anki 语义）──
const QUEUE_NEW: int = 0 ## 新卡片，从未学习过。
const QUEUE_LEARNING: int = 1 ## 学习中（短期间隔，按秒/分钟计）。
const QUEUE_REVIEW: int = 2 ## 复习中（长期间隔，按天计）。
const QUEUE_SUSPENDED: int = -1 ## 已暂停，不加入学习队列。
const QUEUE_BURIED: int = -2 ## 已搁置（当天推迟，明天自动恢复）。

# ── 评分常量（用于 last_rating）──
const RATING_AGAIN: int = 1 ## 完全遗忘，需重新学习。
const RATING_HARD: int = 2 ## 勉强想起，间隔缩短。
const RATING_GOOD: int = 3 ## 正常回忆，标准间隔。
const RATING_EASY: int = 4 ## 轻松回忆，间隔拉长。

## 唯一标识符（自增主键）。0 表示尚未写入数据库的临时对象。
var id: int = 0

## 关联的笔记 ID。对应 note_id 字段（INTEGER, NOT NULL）。
var note_id: int = 0

## 关联的牌组 ID，决定该卡片归属哪个牌组的学习队列。对应 deck_id 字段（INTEGER, NOT NULL）。
var deck_id: int = 0

## 模板序号，用于区分同一 Note 生成的多张 Card。对应 template_order 字段（INTEGER, default 0）。
## 示例: 0=正面→背面, 1=背面→正面（双向卡片）。
var template_order: int = 0

## 队列状态，决定卡片当前处于哪个学习阶段。对应 queue 字段（INTEGER, default 0）。
## 取值见上方 QUEUE_* 常量。
var queue: int = QUEUE_NEW

## 到期值，含义随 queue 变化：
##   - new: 新卡片排序位置（position）
##   - learning: 下次复习的 Unix 时间戳（秒级）
##   - review: 下次复习的天数索引（如 19700 表示自 1970-01-01 起第 19700 天）
## 对应 due 字段（INTEGER, NOT NULL）。
var due: int = 0

## 总复习次数（repetitions），累计答过多少次。对应 reps 字段（INTEGER, default 0）。
var reps: int = 0

## 遗忘/失败次数（lapses），答 Again 导致重新学习的次数。对应 lapses 字段（INTEGER, default 0）。
var lapses: int = 0

## 上次复习的 Unix 时间戳（秒级）。0 表示从未复习过。对应 last_review_time 字段（INTEGER, default 0）。
var last_review_time: int = 0

## 上次评分（1=Again, 2=Hard, 3=Good, 4=Easy）。0 表示从未评分。对应 last_rating 字段（INTEGER, default 0）。
var last_rating: int = 0

## 上次答题耗时（毫秒），用于统计用户思考时间。对应 last_time_taken 字段（INTEGER, default 0）。
var last_time_taken: int = 0

## 复习历史记录的 JSON 序列化字符串，格式为对象数组。对应 review_history_json 字段（TEXT, default "[]"）。
## 示例: [{"rating":3,"time_taken":4200,"reviewed_at":1717200000}, ...]
var review_history_json: String = "[]"

## FSRS 稳定性参数（预留算法扩展），表示记忆保留半衰期（天）。对应 stability 字段（REAL, default 0.0）。
var stability: float = 0.0

## FSRS 难度参数（预留算法扩展），表示卡片固有难度（0.0~1.0+）。对应 difficulty 字段（REAL, default 0.0）。
var difficulty: float = 0.0


## 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。## 输出: Dictionary，键名与数据库 cards 表字段一一对应。
func to_dict() -> Dictionary:
	var d := {
		"note_id": note_id,
		"deck_id": deck_id,
		"template_order": template_order,
		"queue": queue,
		"due": due,
		"reps": reps,
		"lapses": lapses,
		"last_review_time": last_review_time,
		"last_rating": last_rating,
		"last_time_taken": last_time_taken,
		"review_history_json": review_history_json,
		"stability": stability,
		"difficulty": difficulty
	}
	if id > 0:
		d["id"] = id
	return d


## 从字典反序列化，用于数据层 SELECT 查询后将行记录转换为类型安全的实体对象。## 输入: d (Dictionary) - 数据库查询返回的行字典，键名应与 cards 表字段对应。
func from_dict(d: Dictionary) -> void:
	if d.has("id"): id = int(d.get("id", 0))
	if d.has("note_id"): note_id = int(d.get("note_id", 0))
	if d.has("deck_id"): deck_id = int(d.get("deck_id", 0))
	if d.has("template_order"): template_order = int(d.get("template_order", 0))
	if d.has("queue"): queue = int(d.get("queue", QUEUE_NEW))
	if d.has("due"): due = int(d.get("due", 0))
	if d.has("reps"): reps = int(d.get("reps", 0))
	if d.has("lapses"): lapses = int(d.get("lapses", 0))
	if d.has("last_review_time"): last_review_time = int(d.get("last_review_time", 0))
	if d.has("last_rating"): last_rating = int(d.get("last_rating", 0))
	if d.has("last_time_taken"): last_time_taken = int(d.get("last_time_taken", 0))
	if d.has("review_history_json"): review_history_json = str(d.get("review_history_json", "[]"))
	if d.has("stability"): stability = float(d.get("stability", 0.0))
	if d.has("difficulty"): difficulty = float(d.get("difficulty", 0.0))


## 判断卡片是否到期，应根据当前时间或天数索引判断。## 输入: now_day_index (int) - 当前天数索引（用于 review 队列）或 Unix 时间戳（用于 learning 队列）。
##       调用方需根据 queue 类型传入正确的时间单位。
## 输出: bool，due <= now_day_index 时返回 true。
func is_due(now_day_index: int) -> bool:
	return due <= now_day_index


## 判断卡片是否为新卡片（从未学习过）。## 输出: bool，queue == QUEUE_NEW 时返回 true。
func is_new() -> bool:
	return queue == QUEUE_NEW


## 判断卡片是否处于学习阶段（短期间隔）。## 输出: bool，queue == QUEUE_LEARNING 时返回 true。
func is_learning() -> bool:
	return queue == QUEUE_LEARNING


## 判断卡片是否处于复习阶段（长期间隔，按天计）。## 输出: bool，queue == QUEUE_REVIEW 时返回 true。
func is_review() -> bool:
	return queue == QUEUE_REVIEW


## 判断卡片是否已暂停。## 输出: bool，queue == QUEUE_SUSPENDED 时返回 true。
func is_suspended() -> bool:
	return queue == QUEUE_SUSPENDED


## 判断卡片是否已搁置（当天推迟）。## 输出: bool，queue == QUEUE_BURIED 时返回 true。
func is_buried() -> bool:
	return queue == QUEUE_BURIED


## 将本次复习记录追加到历史 JSON 中。## 输入:
##   rating (int) - 本次评分，取值 1~4。
##   time_taken_ms (int) - 本次答题耗时（毫秒）。
##   reviewed_at (int) - 复习时间的 Unix 时间戳，默认使用当前时间。
func append_review_history(rating: int, time_taken_ms: int, reviewed_at: int = 0) -> void:
	if reviewed_at == 0:
		reviewed_at = int(Time.get_unix_time_from_system())

	# 解析现有历史记录
	var history: Array = []
	var json := JSON.new()
	if not review_history_json.is_empty() and review_history_json != "[]":
		var parse_code: int = json.parse(review_history_json)
		if parse_code == OK and typeof(json.data) == TYPE_ARRAY:
			history = json.data

	# 追加新记录
	history.append({
		"rating": rating,
		"time_taken": time_taken_ms,
		"reviewed_at": reviewed_at
	})

	# 序列化回 JSON
	review_history_json = JSON.new().stringify(history)


## 获取复习历史记录数组。## 输出: Array[Dictionary]，每个元素包含 rating/time_taken/reviewed_at 键。
func get_review_history() -> Array:
	if review_history_json.is_empty() or review_history_json == "[]":
		return []
	var json := JSON.new()
	var parse_code: int = json.parse(review_history_json)
	if parse_code == OK and typeof(json.data) == TYPE_ARRAY:
		return json.data
	return []


## 获取当前卡片在 UI 中的显示队列名称（用于调试或状态展示）。## 输出: String，如 "新卡片"、"学习中"、"复习"、"已暂停"、"已搁置"。
func get_queue_name() -> String:
	match queue:
		QUEUE_NEW: return "新卡片"
		QUEUE_LEARNING: return "学习中"
		QUEUE_REVIEW: return "复习"
		QUEUE_SUSPENDED: return "已暂停"
		QUEUE_BURIED: return "已搁置"
		_: return "未知(%d)" % queue


## 获取当前卡片在 UI 中的显示评分名称。## 输出: String，如 "Again"、"Hard"、"Good"、"Easy"、"未评分"。
func get_last_rating_name() -> String:
	match last_rating:
		RATING_AGAIN: return "Again"
		RATING_HARD: return "Hard"
		RATING_GOOD: return "Good"
		RATING_EASY: return "Easy"
		_: return "未评分"


## 生成当前时间的 Unix 时间戳（秒级）。## 输出: int，当前系统时间的 Unix 时间戳。
static func now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


## 将 Unix 时间戳转换为天数索引（自 1970-01-01 起的天数）。
## 用于 review 队列的 due 字段计算。## 输入: unix_ts (int) - Unix 时间戳（秒级）。
## 输出: int，天数索引。
static func day_index_from_timestamp(unix_ts: int) -> int:
	return int(unix_ts / 86400)


## 获取今天的天数索引。## 输出: int，今天的天数索引。
static func today_day_index() -> int:
	return day_index_from_timestamp(now_timestamp())
