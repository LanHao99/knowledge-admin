class_name StoryManager
extends RefCounted
## 剧情管理器（逻辑层），协调 StoryProgress、StoryProgressBar 和 DialogueManager。
## 负责评分驱动进度累加、对话触发判定、冷却管理、条件检测和进度存档。
## 由 study.gd 创建和管理生命周期。

# ── 信号 ──

## 对话被触发（进度达标 + 冷却通过 + 对话未完成）。
signal story_triggered(dialogue_key: String)

## 对话结束（用于恢复复习）。
signal story_ended()

## 进度更新（UI 层监听刷新）。
signal progress_updated(current: int, threshold: int)


# ── 常量 ──

## 默认冷却时间（秒），防止连续触发对话。
const DEFAULT_COOLDOWN_SECONDS: float = 30.0

## 默认触发阈值。
const DEFAULT_TRIGGER_THRESHOLD: int = 10


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

## 触发阈值。
var trigger_threshold: int = DEFAULT_TRIGGER_THRESHOLD

## 是否正在播放对话（阻止新的触发）。
var _is_dialogue_active: bool = false


# ── 初始化 ──


## 初始化 StoryManager：加载存档、设置 DialogueManager 引用。## 输入:
##   dialogue_manager - Engine.get_singleton("DialogueManager") 的引用。
## 输出: 无。
func setup(dialogue_manager = null) -> void:
	story_progress = StoryProgress.load_from_user()
	_dialogue_manager = dialogue_manager

	if progress_bar != null:  # 兼容旧引用，实际不注入
		progress_bar.set_story_progress(story_progress)


## 注册对话资源映射表（通常在 study.gd 中调用）。## 输入:
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

	# 通过进度条累加
	if progress_bar != null:  # 兼容旧引用，实际不注入
		progress_bar.add_progress_from_rating(rating)
	else:
		var add_value := _rating_to_progress(rating)
		story_progress.add_progress(add_value)

	# 保存（每次评分后持久化）
	story_progress.save_to_user()

	# 检查触发条件
	var triggered: bool = false
	var key: String = ""

	if story_progress.total_progress >= trigger_threshold:
		# 冷却检查
		if _is_cooldown_passed():
			key = _pick_dialogue_key()
			if not key.is_empty():
				triggered = true
				story_progress.consume_progress()
				story_progress.last_triggered_at = Time.get_unix_time_from_system()
				_is_dialogue_active = true
				story_progress.save_to_user()
				story_triggered.emit(key)

	progress_updated.emit(story_progress.total_progress, trigger_threshold)

	return {"triggered": triggered, "dialogue_key": key}


## 结束当前对话，恢复复习流程。## 输入: 无。
## 输出: 无。
func end_dialogue() -> void:
	_is_dialogue_active = false
	story_ended.emit()


# ── 对话选择逻辑 ──


## 从当前章节的对话池中选择一个未完成的对话。
## 优先选择条件满足且未完成的；若全部完成，返回空字符串。## 输入: 无。
## 输出: String — 对话 key，无可选时返回 ""。
func _pick_dialogue_key() -> String:
	if story_progress == null or _dialogue_definitions.is_empty():
		return ""

	var chapter: String = story_progress.current_chapter
	if chapter.is_empty() or not _dialogue_definitions.has(chapter):
		return ""

	var chapter_dialogues: Dictionary = _dialogue_definitions.get(chapter, {})
	for key in chapter_dialogues:
		if not story_progress.is_dialogue_completed(key):
			return key

	return ""


## 获取对话 key 对应的 .dialogue 文件路径。## 输入: dialogue_key (String) - 对话标识符。
## 输出: String — 资源路径（如 "res://dialogues/ch1_intro.dialogue"），找不到返回 ""。
func get_dialogue_path(dialogue_key: String) -> String:
	if story_progress == null or dialogue_key.is_empty():
		return ""

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


## 标记对话完成并保存存档。## 输入: dialogue_key (String) - 对话标识符。
## 输出: 无。
func complete_dialogue(dialogue_key: String) -> void:
	if story_progress == null:
		return
	story_progress.mark_dialogue_completed(dialogue_key)
	story_progress.save_to_user()


## 检查某对话是否已完成。## 输入: dialogue_key (String) - 对话标识符。
## 输出: bool。
func is_dialogue_completed(dialogue_key: String) -> bool:
	if story_progress == null:
		return false
	return story_progress.is_dialogue_completed(dialogue_key)


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
