class_name StudySessionEntity
extends RefCounted

# 学习会话实体类，纯数据结构，用于记录一次学习会话的暂态统计信息。
# "暂态"意味着该实体不直接映射到数据库的持久化表，而是存在于内存中，
# 会话结束后可将汇总数据写入 review_logs 或 cards 的历史记录中。
# 由 StudyManager 在会话开始时创建，会话结束时销毁。
# 不加入 Godot 节点树，由 StudyManager 持有引用。

# ── 评分常量（与 CardEntity 对齐，但独立定义以避免实体层循环依赖）──
const RATING_AGAIN: int = 1  ## 完全遗忘。
const RATING_HARD: int  = 2  ## 勉强想起。
const RATING_GOOD: int  = 3  ## 正常回忆。
const RATING_EASY: int  = 4  ## 轻松回忆。

## 本次学习的目标牌组 ID。0 表示"全部牌组"（跨牌组学习模式）。
var deck_id: int = 0

## 会话开始的 Unix 时间戳（秒级），用于计算总时长。
var started_at: int = 0

## 本次会话中已见过的新卡片数量。
var new_cards_seen: int = 0

## 本次会话中已见过的复习卡片数量。
var review_cards_seen: int = 0

## 本次会话累计答题耗时（毫秒）。
var total_time_ms: int = 0

## 扩展统计字典，可存储详细数据供后续分析。
## 示例键: "again_count"、"hard_count"、"good_count"、"easy_count"、"average_time_ms" 等。
var session_stats: Dictionary = {}


## 将会话实体序列化为字典，便于调试日志输出或持久化存储。
##
## 输出: Dictionary，包含会话的所有统计字段。
func to_dict() -> Dictionary:
	return {
		"deck_id": deck_id,
		"started_at": started_at,
		"new_cards_seen": new_cards_seen,
		"review_cards_seen": review_cards_seen,
		"total_time_ms": total_time_ms,
		"session_stats": session_stats.duplicate()
	}


## 从字典反序列化，用于从持久化存储恢复会话状态（如断点续学场景）。
##
## 输入: d (Dictionary) - 包含会话数据的字典。
func from_dict(d: Dictionary) -> void:
	if d.has("deck_id"):             deck_id = int(d.get("deck_id", 0))
	if d.has("started_at"):          started_at = int(d.get("started_at", 0))
	if d.has("new_cards_seen"):      new_cards_seen = int(d.get("new_cards_seen", 0))
	if d.has("review_cards_seen"):   review_cards_seen = int(d.get("review_cards_seen", 0))
	if d.has("total_time_ms"):       total_time_ms = int(d.get("total_time_ms", 0))
	if d.has("session_stats") and typeof(d.get("session_stats")) == TYPE_DICTIONARY:
		session_stats = d.get("session_stats").duplicate()


## 递增新卡片计数器，当用户看到一张新卡片时调用。
func increment_new_seen() -> void:
	new_cards_seen += 1


## 递增复习卡片计数器，当用户看到一张复习卡片时调用。
func increment_review_seen() -> void:
	review_cards_seen += 1


## 累加答题耗时。
##
## 输入: time_ms (int) - 本次答题耗时（毫秒）。
func add_time_ms(time_ms: int) -> void:
	total_time_ms += time_ms


## 记录一次评分事件，更新扩展统计。
##
## 输入:
##   rating (int) - 评分，取值 1=Again, 2=Hard, 3=Good, 4=Easy。
##   time_taken_ms (int) - 本次答题耗时（毫秒）。
##   is_new_card (bool) - 是否为新卡片，影响 new_cards_seen 计数。
func record_answer(rating: int, time_taken_ms: int, is_new_card: bool = false) -> void:
	add_time_ms(time_taken_ms)
	if is_new_card:
		increment_new_seen()
	else:
		increment_review_seen()

	# 按评分分类计数
	var rating_key: String = ""
	match rating:
		RATING_AGAIN: rating_key = "again_count"
		RATING_HARD:  rating_key = "hard_count"
		RATING_GOOD:  rating_key = "good_count"
		RATING_EASY:  rating_key = "easy_count"
	if not rating_key.is_empty():
		session_stats[rating_key] = int(session_stats.get(rating_key, 0)) + 1

	# 更新平均耗时（滑动平均）
	var total_answers: int = new_cards_seen + review_cards_seen
	if total_answers > 0:
		session_stats["average_time_ms"] = total_time_ms / total_answers


## 获取会话中已处理的总卡片数量（新卡片 + 复习卡片）。
##
## 输出: int，总卡片数。
func get_total_cards_seen() -> int:
	return new_cards_seen + review_cards_seen


## 获取会话已持续的时间（毫秒）。
##
## 输入: now_timestamp (int) - 当前 Unix 时间戳，默认使用当前系统时间。
## 输出: int，已持续时间（毫秒）。
func get_elapsed_time_ms(now_timestamp: int = 0) -> int:
	if now_timestamp == 0:
		now_timestamp = int(Time.get_unix_time_from_system())
	return (now_timestamp - started_at) * 1000


## 将会话统计转换为更详细的汇总字典，供 UI 层展示或持久化存储。
## 包含所有原始字段 + 派生计算字段（正确率、平均耗时等）。
##
## 输出: Dictionary，包含完整的会话统计信息。
func to_stats_dict() -> Dictionary:
	var total: int = get_total_cards_seen()
	var correct_count: int = int(session_stats.get("good_count", 0)) + int(session_stats.get("easy_count", 0))
	var accuracy: float = 0.0
	if total > 0:
		accuracy = float(correct_count) / float(total)

	var result := to_dict()
	result["total_cards_seen"] = total
	result["correct_count"] = correct_count
	result["accuracy"] = accuracy
	result["elapsed_time_ms"] = get_elapsed_time_ms()
	return result


## 生成当前时间的 Unix 时间戳（秒级）。
##
## 输出: int，当前系统时间的 Unix 时间戳。
static func now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


## 创建一个新的会话实体，自动填充 started_at 为当前时间。
##
## 输入: target_deck_id (int) - 目标牌组 ID，0 表示全部牌组。
## 输出: StudySessionEntity，已初始化的会话实体。
static func create_new(target_deck_id: int = 0) -> StudySessionEntity:
	var session := StudySessionEntity.new()
	session.deck_id = target_deck_id
	session.started_at = now_timestamp()
	return session
