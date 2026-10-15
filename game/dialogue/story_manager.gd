class_name StoryManager
extends RefCounted
## AVG 引擎。负责评分驱动进度、对话触发、冷却、选项羁绊和进度存档。
## 由 App 创建。不修改卡片数据库，也不改设置界面。

# ── 信号 ──

## 对话被触发（进度达标 + 冷却通过 + 对话未完成）。
signal story_triggered(dialogue_key: String)

## 对话结束（用于恢复复习）。
signal story_ended()

## 进度更新（UI 层监听刷新）。
signal progress_updated(current: int, threshold: int)

## 羁绊层级跃迁（用于 UI 提示或特殊台词）。
signal bond_tier_changed(old_tier: int, new_tier: int, tier_name: String)


# ── 常量 ──

## 默认冷却时间（秒），防止连续触发对话。
const DEFAULT_COOLDOWN_SECONDS: float = 30.0

## 章节顺序表（按叙事流程自动推进）。
const CHAPTER_ORDER: Array[String] = ["chapter_1", "chapter_2"]

## Chapter 1 羁绊专属记忆碎片注册表。
## 格式: { dialogue_key: { tier: int, prerequisite: String, path: String } }
const BOND_MEMORY_FRAGMENTS: Dictionary = {
	"bond_memory_1": {
		"tier": 2,
		"prerequisite": "trust",
		"path": "res://game/dialogue/ch1_bond_memory_1.dialogue"
	},
	"bond_memory_2": {
		"tier": 3,
		"prerequisite": "choice",
		"path": "res://game/dialogue/ch1_bond_memory_2.dialogue"
	},
	"bond_memory_3": {
		"tier": 3,
		"prerequisite": "revelation",
		"path": "res://game/dialogue/ch1_bond_memory_3.dialogue"
	}
}

## 章末羁绊隐藏场景注册表。
const BOND_EPILOGUE: Dictionary = {
	"ch1_bond_epilogue": {
		"tier": 3,
		"prerequisite": "end",
		"path": "res://game/dialogue/ch1_bond_epilogue.dialogue"
	}
}


# ── 内部状态 ──

## 剧情存档数据。
var story_progress: StoryProgress = null

## 进度条 UI 组件引用（可选，支持无 UI 模式）。
var progress_bar: StoryProgressBar = null  # 已弃用，session 内 ProgressBar 节点替代

## 对话资源映射表: { chapter_id: { dialogue_key: "res://path.dialogue", ... }, ... }
var _dialogue_definitions: Dictionary = {}

## 当前注册的 DialogueManager 引用。
var _dialogue_manager = null  # 不声明类型以避免循环依赖

## 触发冷却时间（秒）。
var cooldown_seconds: float = DEFAULT_COOLDOWN_SECONDS

## 是否正在播放对话（阻止新的触发）。
var _is_dialogue_active: bool = false


# ── 初始化 ──


## 初始化 StoryManager：加载存档、注册默认对话表、设置 DialogueManager 引用。## 输入:
##   dialogue_manager - Engine.get_singleton("DialogueManager") 的引用。
## 输出: 无。
func setup(dialogue_manager = null) -> void:
	story_progress = StoryProgress.load_from_user()
	_dialogue_manager = dialogue_manager
	if _dialogue_definitions.is_empty():
		register_dialogues(_default_dialogue_definitions())

	if progress_bar != null:  # 兼容旧引用，实际不注入
		progress_bar.set_story_progress(story_progress)


## AVG 自带的章节对话路径。学习场景不再登记这些文件。## 输入: 无。
## 输出: Dictionary - { chapter_id: { dialogue_key: path } }。
func _default_dialogue_definitions() -> Dictionary:
	return {
		"chapter_1": {
			"intro": "res://game/dialogue/ch1_intro.dialogue",
			"explain": "res://game/dialogue/ch1_explain.dialogue",
			"trust": "res://game/dialogue/ch1_trust.dialogue",
			"warning": "res://game/dialogue/ch1_warning.dialogue",
			"past": "res://game/dialogue/ch1_past.dialogue",
			"choice": "res://game/dialogue/ch1_choice.dialogue",
			"revelation": "res://game/dialogue/ch1_revelation.dialogue",
			"end": "res://game/dialogue/ch1_end.dialogue",
		},
		"chapter_2": {
			"revelation": "res://game/dialogue/ch2_revelation.dialogue",
			"xanaku": "res://game/dialogue/ch2_xanaku.dialogue",
			"trojan": "res://game/dialogue/ch2_trojan.dialogue",
			"survivor": "res://game/dialogue/ch2_survivor.dialogue",
			"protocol": "res://game/dialogue/ch2_protocol.dialogue",
			"choice": "res://game/dialogue/ch2_choice.dialogue",
			"connection": "res://game/dialogue/ch2_connection.dialogue",
			"end": "res://game/dialogue/ch2_end.dialogue",
		},
	}


## 注册对话资源映射表。setup() 会先登记默认章节表，外部可再覆盖。## 输入:
##   definitions (Dictionary) - 格式: { "chapter_1": { "intro": "res://dialogues/ch1_intro.dialogue", ... } }
## 输出: 无。
func register_dialogues(definitions: Dictionary) -> void:
	_dialogue_definitions = definitions


## 注入进度条 UI 引用。## 输入: bar (StoryProgressBar) - 进度条组件。
## 输出: 无。
func set_progress_bar(bar: StoryProgressBar) -> void:
	progress_bar = bar
	if story_progress != null:
		progress_bar.set_story_progress(story_progress)


# ── 核心逻辑 ──


## 评分回调：累加进度并检测是否触发对话。## 输入: rating (int) - 评分值 (1~4)。
## 输出: Dictionary — { triggered: bool, dialogue_key: String }。
func on_review_answered(rating: int) -> Dictionary:
	if story_progress == null:
		return {"triggered": false, "dialogue_key": ""}

	# 如果正在播对话，不触发新的
	if _is_dialogue_active:
		return {"triggered": false, "dialogue_key": ""}

	var add_value := _rating_to_progress(rating)
	story_progress.add_progress(add_value)

	# 保存（每次评分后持久化）
	story_progress.save_to_user()

	# 检查触发条件
	var triggered: bool = false
	var key: String = ""

	if story_progress.total_progress >= story_progress.trigger_threshold:
		# 冷却检查
		if _is_cooldown_passed():
			key = _pick_dialogue_key()
			if not key.is_empty():
				triggered = true
				story_progress.consume_progress()

				# 普通对话：阈值递增；羁绊对话：不递增（额外内容）
				if not (BOND_MEMORY_FRAGMENTS.has(key) or BOND_EPILOGUE.has(key)):
					story_progress.trigger_threshold += 5

				story_progress.last_triggered_at = Time.get_unix_time_from_system()
				_is_dialogue_active = true
				story_progress.save_to_user()
				story_triggered.emit(key)

	progress_updated.emit(story_progress.total_progress, story_progress.trigger_threshold)

	return {"triggered": triggered, "dialogue_key": key}


## 结束当前对话，恢复复习流程。## 输入: 无。
## 输出: 无。
func end_dialogue() -> void:
	_is_dialogue_active = false
	story_ended.emit()


# ── 对话选择逻辑 ──


## 从当前章节的对话池中选择一个未完成的对话。
## 优先级：羁绊记忆碎片 > 羁绊章末隐藏场景 > 普通对话。
## 本章全部完成后自动推进到下一章，返回下一章的首个对话 key。
## 所有章节完成后返回空字符串。## 输入: 无。
## 输出: String — 对话 key，无可选时返回 ""。
func _pick_dialogue_key() -> String:
	if story_progress == null or _dialogue_definitions.is_empty():
		return ""

	# 优先检查羁绊专属内容
	var bond_key := _pick_bond_dialogue_key()
	if not bond_key.is_empty():
		return bond_key

	var chapter: String = story_progress.current_chapter
	if chapter.is_empty() or not _dialogue_definitions.has(chapter):
		return ""

	var chapter_dialogues: Dictionary = _dialogue_definitions.get(chapter, {})
	for key in chapter_dialogues:
		if not story_progress.is_dialogue_completed(key):
			return key

	# 当前章节全部完成 → 尝试推进到下一章
	var next_chapter: String = _get_next_chapter(chapter)
	if next_chapter.is_empty():
		return ""

	story_progress.set_chapter(next_chapter, true)  # 切换章节并重置进度
	story_progress.save_to_user()

	# 返回下一章的第一个对话
	var next_dialogues: Dictionary = _dialogue_definitions.get(next_chapter, {})
	for key in next_dialogues:
		return key

	return ""


## 从羁绊专属内容池中选择一个可触发的对话。
## 优先级：记忆碎片 > 章末隐藏场景。
## 所有羁绊内容已触发或无符合条件的，返回 ""。## 输入: 无。
## 输出: String — 对话 key，无可选时返回 ""。
func _pick_bond_dialogue_key() -> String:
	if story_progress == null:
		return ""

	var bond_tier := story_progress.get_bond_tier()

	# 1. 检查记忆碎片（需前置对话已完成 + 羁绊达标 + 未触发过）
	for key in BOND_MEMORY_FRAGMENTS:
		var frag: Dictionary = BOND_MEMORY_FRAGMENTS[key]
		if bond_tier >= frag["tier"] \
			and story_progress.is_dialogue_completed(str(frag.get("prerequisite", ""))) \
			and not story_progress.is_bond_dialogue_triggered(key):
			return key

	# 2. 检查章末隐藏场景（需前置对话已完成 + 羁绊达标 + 未触发过 + 全章完成）
	for key in BOND_EPILOGUE:
		var ep: Dictionary = BOND_EPILOGUE[key]
		if bond_tier >= ep["tier"] \
			and story_progress.is_dialogue_completed(str(ep.get("prerequisite", ""))) \
			and not story_progress.is_bond_dialogue_triggered(key):
			if _is_chapter_all_completed(story_progress.current_chapter):
				return key

	return ""


## 检查指定章节的所有普通对话是否已完成（不含羁绊专属内容）。## 输入: chapter (String) — 章节 ID。
## 输出: bool。
func _is_chapter_all_completed(chapter: String) -> bool:
	if not _dialogue_definitions.has(chapter):
		return false
	var chapter_dialogues: Dictionary = _dialogue_definitions.get(chapter, {})
	for key in chapter_dialogues:
		if not story_progress.is_dialogue_completed(key):
			return false
	return true


## 按 CHAPTER_ORDER 获取下一章节 ID。无下一章时返回空字符串。## 输入: current (String) — 当前章节 ID。
## 输出: String — 下一章 ID，已是最后一章时返回 ""。
func _get_next_chapter(current: String) -> String:
	var idx: int = CHAPTER_ORDER.find(current)
	if idx < 0 or idx >= CHAPTER_ORDER.size() - 1:
		return ""
	return CHAPTER_ORDER[idx + 1]


## 获取对话 key 对应的 .dialogue 文件路径（含羁绊专属内容）。## 输入: dialogue_key (String) - 对话标识符。
## 输出: String — 资源路径，找不到返回 ""。
func get_dialogue_path(dialogue_key: String) -> String:
	if story_progress == null or dialogue_key.is_empty():
		return ""

	# 先查羁绊专属内容
	if BOND_MEMORY_FRAGMENTS.has(dialogue_key):
		return str(BOND_MEMORY_FRAGMENTS[dialogue_key].get("path", ""))
	if BOND_EPILOGUE.has(dialogue_key):
		return str(BOND_EPILOGUE[dialogue_key].get("path", ""))

	# 再查普通对话
	var chapter: String = story_progress.current_chapter
	if not _dialogue_definitions.has(chapter):
		return ""

	var chapter_dialogues: Dictionary = _dialogue_definitions[chapter]
	return str(chapter_dialogues.get(dialogue_key, ""))


## 加载对话资源。## 输入: dialogue_key (String) - 对话标识符。
## 输出: DialogueResource 或 null。
func load_dialogue_resource(dialogue_key: String):
	var path := get_dialogue_path(dialogue_key)
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


# ── 冷却管理 ──


## 检查冷却时间是否已过。## 输入: 无。
## 输出: bool，冷却已过返回 true。
func _is_cooldown_passed() -> bool:
	if story_progress == null or story_progress.last_triggered_at <= 0:
		return true
	var elapsed: float = Time.get_unix_time_from_system() - story_progress.last_triggered_at
	return elapsed >= cooldown_seconds


## 设置冷却时间。## 输入: seconds (float) - 冷却秒数。
## 输出: 无。
func set_cooldown(seconds: float) -> void:
	cooldown_seconds = max(0.0, seconds)


# ── 对话完成管理 ──


## 标记对话完成并保存存档（自动区分普通对话和羁绊专属对话）。## 输入: dialogue_key (String) - 对话标识符。
## 输出: 无。
func complete_dialogue(dialogue_key: String) -> void:
	if story_progress == null:
		return

	# 羁绊专属对话走独立轨道
	if BOND_MEMORY_FRAGMENTS.has(dialogue_key) or BOND_EPILOGUE.has(dialogue_key):
		story_progress.mark_bond_dialogue_triggered(dialogue_key)
	else:
		story_progress.mark_dialogue_completed(dialogue_key)

	story_progress.save_to_user()


## 检查某对话是否已完成。## 输入: dialogue_key (String) - 对话标识符。
## 输出: bool。
func is_dialogue_completed(dialogue_key: String) -> bool:
	if story_progress == null:
		return false
	return story_progress.is_dialogue_completed(dialogue_key)


# ── 羁绊管理 ──


## 对话选项不再在这里改好感度。增量写在 .dialogue 的 do App.add_bond 里。## 输入:
##   _dialogue_key (String) — 当前对话标识，未使用。
##   _choice_index (int) — 对话内选项序数，未使用。
##   _option_index (int) — 玩家选择的选项索引，未使用。
## 输出: Dictionary — 始终 applied=false，避免和对话脚本重复加分。
func on_dialogue_choice(_dialogue_key: String, _choice_index: int, _option_index: int) -> Dictionary:
	return {"applied": false, "delta": 0, "tier_changed": false, "old_tier": 0, "new_tier": 0}


## 获取当前羁绊层级。## 输入: 无。
## 输出: int (0~3)。
func get_bond_tier() -> int:
	if story_progress == null:
		return 0
	return story_progress.get_bond_tier()


## 检查是否已达到指定羁绊层级。## 输入: tier (int) - 0~3。
## 输出: bool。
func is_bond_tier_reached(tier: int) -> bool:
	if story_progress == null:
		return false
	return story_progress.get_bond_tier() >= tier


## 直接操作羁绊值（用于调试或特殊事件）。## 输入: amount (int) — 变化量。
## 输出: Dictionary — add_bond 的结果。
func add_bond(amount: int) -> Dictionary:
	if story_progress == null:
		return {"tier_changed": false, "old_tier": 0, "new_tier": 0}
	var result := story_progress.add_bond(amount)
	if result["tier_changed"]:
		var tier_name: String = story_progress.get_bond_tier_name(result["new_tier"])
		bond_tier_changed.emit(result["old_tier"], result["new_tier"], tier_name)
	story_progress.save_to_user()
	return result


## 标记羁绊专属对话为已完成（与普通对话完成独立）。## 输入: dialogue_key (String) - 对话标识符。
## 输出: 无。
func complete_bond_dialogue(dialogue_key: String) -> void:
	if story_progress == null:
		return
	story_progress.mark_bond_dialogue_triggered(dialogue_key)
	story_progress.save_to_user()


# ── 存档 ──


## 手动保存进度到文件。## 输入: 无。
## 输出: 无。
func save() -> void:
	if story_progress != null:
		story_progress.save_to_user()


# ── 工具 ──


## 将评分转换为进度值.## 输入: rating (int) - 1~4。
## 输出: int — 对应的进度值。
func _rating_to_progress(rating: int) -> int:
	match rating:
		2: return 1  # Hard
		3: return 2  # Good
		4: return 3  # Easy
		_: return 0  # Again or invalid


## 检查是否正在播放对话。## 输入: 无。
## 输出: bool。
func is_dialogue_active() -> bool:
	return _is_dialogue_active
