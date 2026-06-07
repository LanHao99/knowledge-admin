class_name StoryProgress
extends Resource
## 剧情进度存档资源，持久化保存于 user://story_progress.tres。
## 记录总进度值、章节、已完成对话、剧情标记和触发时间等长期数据。
## 由 StoryManager 负责读写，不直接操作文件系统。

# ── 存档文件路径 ──
const SAVE_PATH: String = "user://story_progress.tres"

# ── 剧情数据字段 ──

## 累计剧情经验值（评分驱动累加）。达到阈值时触发对话。
@export var total_progress: int = 0

## 当前章节标识符，如 "chapter_1"、"prologue"，用于条件分支。
@export var current_chapter: String = ""

## 已完成对话 ID 列表，如 ["intro_met_ai", "ch1_revelation"]。
@export var completed_dialogues: Array[String] = []

## 剧情标记字典，如 {"met_character_x": true, "found_secret": false}。
@export var flags: Dictionary = {}

## 上次触发对话的 Unix 时间戳（秒级浮点），用于冷却检测。
@export var last_triggered_at: float = 0.0

## 剧情触发阈值（每次触发后 +5）。达到此值时触发对话。
@export var trigger_threshold: int = 10

## MIRA 对玩家的羁绊值（信任深度）。范围 [0, ∞)，有效区间 [0, 20]。
@export var bond: int = 0

## 已触发过的羁绊专属对话 ID 列表（防止重复触发）。
@export var bond_dialogues_triggered: Array[String] = []


# ── 羁绊系统 ──


## 根据 bond 值返回当前羁绊层级（0~3）。## 输入: 无。
## 输出: int — 0:陌生人 1:相识 2:信任 3:羁绊。
func get_bond_tier() -> int:
	if bond < 4:
		return 0
	if bond < 8:
		return 1
	if bond < 13:
		return 2
	return 3


## 获取羁绊层级的文本名称。输入: tier (int, 可选) - 层级编号，默认用当前层级。
## 输出: String — 如 "陌生人"、"相识"、"信任"、"羁绊"。
func get_bond_tier_name(tier: int = -1) -> String:
	var t: int = tier if tier >= 0 else get_bond_tier()
	match t:
		1: return "相识"
		2: return "信任"
		3: return "羁绊"
		_: return "陌生人"


## 羁绊值改变后同步 flags（供 DialogueManager 条件检测）。## 输入: 无。
## 输出: 无。
func _sync_bond_flags() -> void:
	var tier := get_bond_tier()
	flags["bond_tier"] = tier
	flags["bond_tier_1_reached"] = (tier >= 1)
	flags["bond_tier_2_reached"] = (tier >= 2)
	flags["bond_tier_3_reached"] = (tier >= 3)
	flags["bond_value"] = bond


## 增加或减少羁绊值，钳位到 [0, INT_MAX)，并同步 flags。## 输入: amount (int) — 变化量，可正可负。
## 输出: Dictionary — { tier_changed: bool, old_tier: int, new_tier: int }。
func add_bond(amount: int) -> Dictionary:
	var old_tier := get_bond_tier()
	bond = max(0, bond + amount)
	var new_tier := get_bond_tier()
	_sync_bond_flags()
	return {
		"tier_changed": old_tier != new_tier,
		"old_tier": old_tier,
		"new_tier": new_tier
	}


## 检查羁绊专属对话是否已触发过。## 输入: dialogue_key (String) — 对话标识符。
## 输出: bool，已触发返回 true。
func is_bond_dialogue_triggered(dialogue_key: String) -> bool:
	return dialogue_key in bond_dialogues_triggered


## 标记羁绊专属对话为已触发（去重）。## 输入: dialogue_key (String) — 对话标识符。
## 输出: 无。
func mark_bond_dialogue_triggered(dialogue_key: String) -> void:
	if not is_bond_dialogue_triggered(dialogue_key):
		bond_dialogues_triggered.append(dialogue_key)


# ── 存档读写 ──


## 保存当前 StoryProgress 到 user:// 路径。## 输入: 无。
## 输出: 返回标准字典。成功时 data 为 true，失败时 data 为错误信息。
func save_to_user() -> Dictionary:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK:
		return {
			"success": false,
			"error": "SAVE_FAILED",
			"message": "保存 StoryProgress 失败，错误码: %d" % err
		}
	return {"success": true, "data": true}


## 从 user:// 路径加载 StoryProgress。如果文件不存在，返回一个新的默认实例。## 输入: 无。
## 输出: StoryProgress 实例（已加载或新建）。
static func load_from_user() -> StoryProgress:
	if not FileAccess.file_exists(SAVE_PATH):
		return StoryProgress.new()
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as StoryProgress
	if loaded == null:
		return StoryProgress.new()
	return loaded


# ── 进度操作 ──


## 累加进度值。会钳位在 [0, INT_MAX)。## 输入: value (int) - 要累加的进度值，负数表示扣除。
## 输出: 无。
func add_progress(value: int) -> void:
	total_progress = max(0, total_progress + value)


## 检查进度是否达到给定阈值。## 输入: threshold (int) - 阈值。
## 输出: bool，total_progress >= threshold 时返回 true。
func is_progress_above(threshold: int) -> bool:
	return total_progress >= threshold


## 消耗一定量的进度值（触发对话后归零或扣减）。## 输入: amount (int) - 要消耗的数量，默认 0 表示全部归零。
## 输出: 无。
func consume_progress(amount: int = 0) -> void:
	if amount <= 0:
		total_progress = 0
	else:
		total_progress = max(0, total_progress - amount)


# ── 对话完成管理 ──


## 检查某个对话 ID 是否已完成。## 输入: dialogue_id (String) - 对话唯一标识符。
## 输出: bool，已完成返回 true。
func is_dialogue_completed(dialogue_id: String) -> bool:
	return dialogue_id in completed_dialogues


## 标记某个对话为已完成（去重）。## 输入: dialogue_id (String) - 对话唯一标识符。
## 输出: 无。
func mark_dialogue_completed(dialogue_id: String) -> void:
	if not is_dialogue_completed(dialogue_id):
		completed_dialogues.append(dialogue_id)


# ── 标记系统 ──


## 检查某个剧情标记是否存在且为 true。## 输入: flag_name (String) - 标记名称。
## 输出: bool，标记存在且值为 true 时返回 true。
func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false) == true


## 设置剧情标记。## 输入:
##   flag_name (String) - 标记名称。
##   value (Variant) - 标记值，通常为 bool。
## 输出: 无。
func set_flag(flag_name: String, value: Variant) -> void:
	flags[flag_name] = value


## 获取剧情标记的原始值（不存在时返回 default）。## 输入:
##   flag_name (String) - 标记名称。
##   default (Variant) - 默认值。
## 输出: Variant，标记的当前值或默认值。
func get_flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)


## 移除剧情标记。## 输入: flag_name (String) - 标记名称。
## 输出: 无。
func remove_flag(flag_name: String) -> void:
	flags.erase(flag_name)


# ── 章节管理 ──


## 切换到新章节，可选是否重置进度值。## 输入:
##   chapter_id (String) - 新章节标识符。
##   reset_progress (bool) - 是否重置进度值，默认 false。
## 输出: 无。
func set_chapter(chapter_id: String, reset_progress: bool = false) -> void:
	current_chapter = chapter_id
	if reset_progress:
		total_progress = 0


# ── 工具方法 ──


## 将 StoryProgress 序列化为字典（不含 Resource 元数据），用于调试或导出。## 输出: Dictionary。
func to_dict() -> Dictionary:
	return {
		"total_progress": total_progress,
		"current_chapter": current_chapter,
		"completed_dialogues": completed_dialogues.duplicate(),
		"flags": flags.duplicate(),
		"last_triggered_at": last_triggered_at,
		"trigger_threshold": trigger_threshold,
		"bond": bond,
		"bond_tier": get_bond_tier()
	}


## 重置所有数据为初始状态（保留同一个实例引用）。## 输入: 无。
## 输出: 无。
func reset() -> void:
	total_progress = 0
	current_chapter = ""
	completed_dialogues.clear()
	flags.clear()
	last_triggered_at = 0.0
	trigger_threshold = 10
	bond = 0
	bond_dialogues_triggered.clear()
	_sync_bond_flags()
