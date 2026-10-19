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

## 剧情存档内容发生变化。进度、标记、完成记录和章节都走这一条。
signal state_changed


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
		"chapter": "chapter_1",
		"prerequisite": "trust",
		"path": "res://content/dialogue/story/ch1_bond_memory_1.dialogue"
	},
	"bond_memory_2": {
		"tier": 3,
		"chapter": "chapter_1",
		"prerequisite": "choice",
		"path": "res://content/dialogue/story/ch1_bond_memory_2.dialogue"
	},
	"bond_memory_3": {
		"tier": 3,
		"chapter": "chapter_1",
		"prerequisite": "revelation",
		"path": "res://content/dialogue/story/ch1_bond_memory_3.dialogue"
	}
}

## 章末羁绊隐藏场景注册表。
const BOND_EPILOGUE: Dictionary = {
	"ch1_bond_epilogue": {
		"tier": 3,
		"chapter": "chapter_1",
		"prerequisite": "end",
		"path": "res://content/dialogue/story/ch1_bond_epilogue.dialogue"
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

## 正式存档和备份的写入器。
var _archive: StoryArchive = null

## 对话标题缓存，避免重复加载资源。
var _title_cache: Dictionary = {}


# ── 初始化 ──


## 初始化 StoryManager：加载存档、注册默认对话表、设置 DialogueManager 引用。## 输入:
##   dialogue_manager - Engine.get_singleton("DialogueManager") 的引用。
##   existing (StoryProgress) - 已有存档；为空时从 user:// 读取并迁移旧记录。
##   archive (StoryArchive) - 存档写入器；为空时使用正式路径。
## 输出: 无。
func setup(dialogue_manager = null, existing: StoryProgress = null, archive: StoryArchive = null) -> void:
	_archive = archive if archive != null else StoryArchive.new()
	_dialogue_manager = dialogue_manager
	if _dialogue_definitions.is_empty():
		register_dialogues(_default_dialogue_definitions())
	if existing != null:
		story_progress = existing
	else:
		story_progress = StoryProgress.load_from_user()
		migrate_loaded_records()

	if progress_bar != null:  # 兼容旧引用，实际不注入
		progress_bar.set_story_progress(story_progress)


## AVG 自带的章节对话路径。学习场景不再登记这些文件。## 输入: 无。
## 输出: Dictionary - { chapter_id: { dialogue_key: path } }。
func _default_dialogue_definitions() -> Dictionary:
	return {
		"chapter_1": {
			"intro": "res://content/dialogue/story/ch1_intro.dialogue",
			"explain": "res://content/dialogue/story/ch1_explain.dialogue",
			"trust": "res://content/dialogue/story/ch1_trust.dialogue",
			"warning": "res://content/dialogue/story/ch1_warning.dialogue",
			"past": "res://content/dialogue/story/ch1_past.dialogue",
			"choice": "res://content/dialogue/story/ch1_choice.dialogue",
			"revelation": "res://content/dialogue/story/ch1_revelation.dialogue",
			"end": "res://content/dialogue/story/ch1_end.dialogue",
		},
		"chapter_2": {
			"revelation": "res://content/dialogue/story/ch2_revelation.dialogue",
			"xanaku": "res://content/dialogue/story/ch2_xanaku.dialogue",
			"trojan": "res://content/dialogue/story/ch2_trojan.dialogue",
			"survivor": "res://content/dialogue/story/ch2_survivor.dialogue",
			"protocol": "res://content/dialogue/story/ch2_protocol.dialogue",
			"choice": "res://content/dialogue/story/ch2_choice.dialogue",
			"connection": "res://content/dialogue/story/ch2_connection.dialogue",
			"end": "res://content/dialogue/story/ch2_end.dialogue",
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

	_notify_state()

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
	var entry := preview_next_entry()
	if entry.is_empty():
		return ""
	if _advances_chapter(entry):
		story_progress.set_chapter(str(entry.get("chapter", "")), true)
		story_progress.save_to_user()
		state_changed.emit()
	return str(entry.get("key", ""))


## 从羁绊专属内容池中选择一个可触发的对话。
## 优先级：记忆碎片 > 章末隐藏场景。
## 所有羁绊内容已触发或无符合条件的，返回 ""。## 输入: 无。
## 输出: String — 对话 key，无可选时返回 ""。
func _pick_bond_dialogue_key() -> String:
	if story_progress == null:
		return ""

	# 1. 检查记忆碎片（需前置对话已完成 + 羁绊达标 + 未触发过）
	for bond in _memory_bonds():
		if StoryCatalog._bond_ready(story_progress, bond, _dialogue_definitions, false):
			return str(bond.get("key", ""))

	# 2. 检查章末隐藏场景（需前置对话已完成 + 羁绊达标 + 未触发过 + 全章完成）
	for bond in _epilogue_bonds():
		if StoryCatalog._bond_ready(story_progress, bond, _dialogue_definitions, true):
			return str(bond.get("key", ""))

	return ""


## 检查指定章节的所有普通对话是否已完成（不含羁绊专属内容）。## 输入: chapter (String) — 章节 ID。
## 输出: bool。
func _is_chapter_all_completed(chapter: String) -> bool:
	if not _dialogue_definitions.has(chapter):
		return false
	var chapter_dialogues: Dictionary = _dialogue_definitions.get(chapter, {})
	for key in chapter_dialogues:
		if not story_progress.is_chapter_dialogue_completed(chapter, str(key)):
			return false
	return not chapter_dialogues.is_empty()


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
		story_progress.mark_chapter_dialogue(story_progress.current_chapter, dialogue_key)

	story_progress.save_to_user()
	_notify_state()


## 检查某对话是否已完成。## 输入: dialogue_key (String) - 对话标识符。
## 输出: bool。
func is_dialogue_completed(dialogue_key: String) -> bool:
	if story_progress == null:
		return false
	if StoryProgress.is_composite_record(dialogue_key):
		return story_progress.is_dialogue_completed(dialogue_key)
	return story_progress.is_chapter_dialogue_completed(story_progress.current_chapter, dialogue_key)


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
	_notify_state()
	return result


## 标记羁绊专属对话为已完成（与普通对话完成独立）。## 输入: dialogue_key (String) - 对话标识符。
## 输出: 无。
func complete_bond_dialogue(dialogue_key: String) -> void:
	if story_progress == null:
		return
	story_progress.mark_bond_dialogue_triggered(dialogue_key)
	story_progress.save_to_user()
	_notify_state()


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


## 无副作用地查询下一段剧情。## 输入: 无。
## 输出: Dictionary。没有下一段时为空。
func preview_next_entry() -> Dictionary:
	if story_progress == null or _dialogue_definitions.is_empty():
		return {}
	_ensure_archive()
	return StoryCatalog.preview_next(
		story_progress,
		CHAPTER_ORDER,
		_dialogue_definitions,
		_memory_bonds(),
		_epilogue_bonds()
	)


## 按章节返回主线和羁绊目录，显示名来自对话标题。## 输入: 无。
## 输出: Dictionary，键 chapters 为分组后的条目。
func build_catalog() -> Dictionary:
	var chapters: Array[Dictionary] = []
	var entries := ordered_story_entries()
	var grouped: Dictionary = {}
	for entry in entries:
		var chapter := str(entry.get("chapter", ""))
		if not grouped.has(chapter):
			grouped[chapter] = []
		var row: Dictionary = entry.duplicate()
		row["title"] = dialogue_title(str(entry.get("path", "")), str(entry.get("key", "")))
		row["completed"] = _entry_completed(entry)
		(grouped[chapter] as Array).append(row)
	for chapter in CHAPTER_ORDER:
		if not grouped.has(chapter):
			continue
		chapters.append({
			"id": chapter,
			"title": StoryCatalog.chapter_title(chapter),
			"entries": grouped[chapter],
		})
	return {"chapters": chapters}


## 返回跳转和目录使用的完整顺序。## 输入: 无。
## 输出: Array[Dictionary]。
func ordered_story_entries() -> Array[Dictionary]:
	return StoryCatalog.ordered_entries(CHAPTER_ORDER, _dialogue_definitions, _all_bonds())


## 读取对话文件的首个标题。## 输入: path、fallback。
## 输出: String。资源没有标题时返回 fallback。
func dialogue_title(path: String, fallback: String) -> String:
	if path.is_empty():
		return fallback
	if _title_cache.has(path):
		return str(_title_cache[path])
	var title := fallback
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		title = _title_from_resource(resource, fallback)
	_title_cache[path] = title
	return title


## 从对话资源读取第一个标题名。## 输入: resource、fallback。
## 输出: String。
func _title_from_resource(resource: Resource, fallback: String) -> String:
	if resource == null:
		return fallback
	var raw := str(resource.get("raw_text"))
	for row in raw.split("\n"):
		var line := str(row).strip_edges()
		if line.begins_with("~"):
			var title := line.substr(1).strip_edges()
			if not title.is_empty():
				return title
	var titles: Variant = resource.get("titles")
	if titles is Dictionary:
		var named: Dictionary = titles
		for title_name in named.keys():
			if not str(title_name).is_valid_int():
				return str(title_name)
	return fallback


## 忽略进度门槛和冷却，准备下一段并写入存档。## 输入: 无。
## 输出: Dictionary。成功时 data 含 key、path、resource 和 backup。
func prepare_next_story() -> Dictionary:
	if story_progress == null:
		return _failure("剧情存档未就绪")
	if _is_dialogue_active:
		return _failure("剧情正在播放或排队")
	var entry := preview_next_entry()
	if entry.is_empty():
		return _failure("没有下一段剧情")
	var path := str(entry.get("path", ""))
	var resource: Resource = _load_story_resource(path)
	if resource == null:
		return _failure("找不到剧情资源: %s" % path)
	var next := StoryProgress.new()
	next.copy_from(story_progress)
	if _advances_chapter(entry):
		next.set_chapter(str(entry.get("chapter", "")), true)
	next.consume_progress()
	if str(entry.get("kind", "")) == "main":
		next.trigger_threshold += 5
	next.last_triggered_at = Time.get_unix_time_from_system()
	var committed := commit_progress(next, "start")
	if not committed.success:
		return committed
	_is_dialogue_active = true
	return {
		"success": true,
		"data": {
			"chapter": str(entry.get("chapter", "")),
			"key": str(entry.get("key", "")),
			"kind": str(entry.get("kind", "")),
			"path": path,
			"resource": resource,
			"backup": str(committed.get("backup", "")),
		},
	}


## 重排完成记录并准备强制播放所选剧情。## 输入: chapter、key。
## 输出: Dictionary。成功时 data 含资源和跳转前备份。
func prepare_story_jump(chapter: String, key: String) -> Dictionary:
	if story_progress == null:
		return _failure("剧情存档未就绪")
	if _is_dialogue_active:
		return _failure("剧情正在播放或排队")
	var plan := StoryCatalog.plan_jump(story_progress, ordered_story_entries(), chapter, key)
	if not plan.success:
		return plan
	var path := str(plan.get("path", ""))
	var resource: Resource = _load_story_resource(path)
	if resource == null:
		return _failure("找不到剧情资源: %s" % path)
	var next := StoryProgress.new()
	next.copy_from(story_progress)
	next.current_chapter = str(plan.get("chapter", chapter))
	next.total_progress = 0
	next.last_triggered_at = 0.0
	next.trigger_threshold = int(plan.get("threshold", 10))
	StoryProgress.assign_strings(next.completed_dialogues, plan.get("completed", []))
	StoryProgress.assign_strings(next.bond_dialogues_triggered, plan.get("bonds", []))
	next.sync_bond_flags()
	var committed := commit_progress(next, "jump")
	if not committed.success:
		return committed
	_is_dialogue_active = true
	return {
		"success": true,
		"data": {
			"chapter": next.current_chapter,
			"key": key,
			"kind": str(plan.get("kind", "")),
			"path": path,
			"resource": resource,
			"backup": str(committed.get("backup", "")),
		},
	}


## 验证并原位保存一份新的剧情状态。## 输入: replacement、reason。
## 输出: Dictionary。
func commit_progress(replacement: StoryProgress, reason: String) -> Dictionary:
	_ensure_archive()
	var committed := _archive.commit(story_progress, replacement, reason)
	if committed.success:
		_notify_state()
	return committed


## 把旧的短完成记录迁移到「章节/剧情」，迁移前先备份。## 输入: 无。
## 输出: Dictionary。没有需要迁移的记录时 changed 为 false。
func migrate_loaded_records() -> Dictionary:
	if story_progress == null:
		return _failure("剧情存档未就绪")
	var migrated := StoryCatalog.migrate_completed(
		story_progress.completed_dialogues,
		_dialogue_definitions,
		CHAPTER_ORDER
	)
	if not migrated.changed:
		return {"success": true, "data": {"changed": false}}
	var next := StoryProgress.new()
	next.copy_from(story_progress)
	StoryProgress.assign_strings(next.completed_dialogues, migrated.records)
	var committed := commit_progress(next, "migrate")
	if not committed.success:
		push_error("[StoryManager] 旧档迁移失败: %s" % str(committed.get("message", "")))
		return committed
	committed["changed"] = true
	return committed


## 用备份恢复剧情。## 输入: backup_path。
## 输出: Dictionary。
func restore_backup(backup_path: String) -> Dictionary:
	_ensure_archive()
	var restored := _archive.restore(story_progress, backup_path)
	if restored.success:
		_notify_state()
	return restored


## 列出已保留的剧情备份。## 输入: 无。
## 输出: Array[Dictionary]。
func list_backups() -> Array[Dictionary]:
	_ensure_archive()
	return _archive.list_backups()


## 当前触发冷却还剩多少秒。## 输入: 无。
## 输出: float。没有冷却时返回 0。
func cooldown_remaining() -> float:
	if story_progress == null or story_progress.last_triggered_at <= 0.0:
		return 0.0
	var elapsed := Time.get_unix_time_from_system() - story_progress.last_triggered_at
	return maxf(0.0, cooldown_seconds - elapsed)


## 预览结果是否会在真正开播时切到下一章。## 输入: entry。
## 输出: bool。
func _advances_chapter(entry: Dictionary) -> bool:
	if story_progress == null or str(entry.get("kind", "")) != "main":
		return false
	var target := str(entry.get("chapter", ""))
	return not target.is_empty() and target != story_progress.current_chapter and _is_chapter_all_completed(story_progress.current_chapter)


## 加载剧情资源，不执行剧本。## 输入: path。
## 输出: Resource。路径无效时返回 null。
func _load_story_resource(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


## 通知进度和统一状态变化。## 输入: 无。
## 输出: 无。
func _notify_state() -> void:
	if story_progress == null:
		return
	progress_updated.emit(story_progress.total_progress, story_progress.trigger_threshold)
	state_changed.emit()


## 保证备份写入器存在。## 输入: 无。
## 输出: 无。
func _ensure_archive() -> void:
	if _archive == null:
		_archive = StoryArchive.new()


## 记忆碎片登记转换成目录条目。## 输入: 无。
## 输出: Array[Dictionary]。
func _memory_bonds() -> Array[Dictionary]:
	return _bonds_from(BOND_MEMORY_FRAGMENTS)


## 章末羁绊登记转换成目录条目。## 输入: 无。
## 输出: Array[Dictionary]。
func _epilogue_bonds() -> Array[Dictionary]:
	return _bonds_from(BOND_EPILOGUE)


## 合并两类羁绊条目。## 输入: 无。
## 输出: Array[Dictionary]。
func _all_bonds() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append_array(_memory_bonds())
	rows.append_array(_epilogue_bonds())
	return rows


## 把羁绊登记表转成稳定顺序的目录条目。## 输入: table。
## 输出: Array[Dictionary]。
func _bonds_from(table: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key in table:
		var spec: Dictionary = table[key]
		var dialogue_key := str(key)
		var chapter := str(spec.get("chapter", ""))
		rows.append({
			"key": dialogue_key,
			"chapter": chapter,
			"kind": "bond",
			"tier": int(spec.get("tier", 1)),
			"prerequisite": str(spec.get("prerequisite", "")),
			"path": str(spec.get("path", "")),
			"record": StoryProgress.record_key(chapter, dialogue_key),
		})
	return rows


## 判断目录条目在当前存档中是否已完成。## 输入: entry。
## 输出: bool。
func _entry_completed(entry: Dictionary) -> bool:
	if story_progress == null:
		return false
	if str(entry.get("kind", "")) == "bond":
		return story_progress.is_bond_dialogue_triggered(str(entry.get("key", "")))
	return story_progress.is_dialogue_completed(str(entry.get("record", "")))


## 组装剧情操作失败结果。## 输入: message。
## 输出: Dictionary。
func _failure(message: String) -> Dictionary:
	return {"success": false, "error": "STORY", "message": message}
