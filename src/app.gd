# App.gd（Autoload 单例）
extends Node
## 主逻辑门面。跨场景保存世界标记，把闪卡评分转给 AVG，并按标记规则改设置行和卡面显示。
## 不包含复习算法，也不解析 .dialogue 脚本。


## 一张卡即将显示。shown_text 已是规则过滤后的文字。
signal card_presented(card_id: int, side: String, shown_text: String)

## 闪卡引擎上报了一次评分。AVG 是否因此开对话由主逻辑内部决定。
signal card_answered(rating: int)

## 对话窗已经打开。学习界面应藏起卡片。
signal dialogue_opened(dialogue_key: String)

## 对话窗已经关闭。学习界面仅在仍处于学习中时恢复卡片。
signal dialogue_closed(dialogue_key: String)

## 世界标记被写入并存档。
signal flags_changed(flag_name: String, value: Variant)

## 剧情进度数值变化，供学习界面刷新进度条。
signal story_progress_changed(current: int, threshold: int)


const OVERLAY_SCENE: String = "res://game/dialogue/story_dialogue_overlay.tscn"
const DEFAULT_CHAPTER: String = "chapter_1"

var _story_manager: StoryManager = null
var _overlay: StoryDialogueOverlay = null
var _active_dialogue_key: String = ""


## 启动 AVG，并准备唯一的对话窗。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_story()
	_ensure_overlay()


## 创建剧情管理器并接上它的信号。章节只在存档为空时写成第一章。## 输入: 无。
## 输出: 无。
func _setup_story() -> void:
	_story_manager = StoryManager.new()
	var dialogue_manager = Engine.get_singleton("DialogueManager")
	_story_manager.setup(dialogue_manager)
	if _story_manager.story_progress != null and _story_manager.story_progress.current_chapter.is_empty():
		_story_manager.story_progress.set_chapter(DEFAULT_CHAPTER)
		_story_manager.story_progress.save_to_user()
	if not _story_manager.story_triggered.is_connected(_on_story_triggered):
		_story_manager.story_triggered.connect(_on_story_triggered)
	if not _story_manager.progress_updated.is_connected(_on_progress_updated):
		_story_manager.progress_updated.connect(_on_progress_updated)
	if not _story_manager.bond_tier_changed.is_connected(_on_bond_tier_changed):
		_story_manager.bond_tier_changed.connect(_on_bond_tier_changed)


## 实例化唯一对话覆盖层并挂在本单例下，场景切换时不销毁。## 输入: 无。
## 输出: 无。
func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var packed := load(OVERLAY_SCENE) as PackedScene
	if packed == null:
		push_error("[App] 对话覆盖层场景加载失败: %s" % OVERLAY_SCENE)
		return
	_overlay = packed.instantiate() as StoryDialogueOverlay
	if _overlay == null:
		push_error("[App] 对话覆盖层实例化失败")
		return
	_overlay.layer = 20
	add_child(_overlay)
	if not _overlay.dialogue_finished.is_connected(_on_overlay_finished):
		_overlay.dialogue_finished.connect(_on_overlay_finished)


## 读取当前剧情存档。设置和卡面不要直接碰 StoryManager。## 输入: 无。
## 输出: StoryProgress。AVG 尚未就绪时返回 null。
func get_story_progress() -> StoryProgress:
	if _story_manager == null:
		return null
	return _story_manager.story_progress


## 读取世界标记。## 输入:
##   flag_name (String) - 标记名。
##   default_value (Variant) - 标记不存在时的返回值。
## 输出: Variant - 存档中的值，或 default_value。
func get_flag(flag_name: String, default_value: Variant = null) -> Variant:
	var progress := get_story_progress()
	if progress == null:
		return default_value
	return progress.get_flag(flag_name, default_value)


## 写入世界标记并立即存档。## 输入:
##   flag_name (String) - 标记名。
##   value (Variant) - 新值。规则表只把 true 视为开启。
## 输出: 无。
func set_flag(flag_name: String, value: Variant) -> void:
	var progress := get_story_progress()
	if progress == null:
		push_warning("[App] 无法写入标记，剧情存档未就绪: %s" % flag_name)
		return
	progress.set_flag(flag_name, value)
	progress.save_to_user()
	flags_changed.emit(flag_name, value)


## 判断标记是否为严格的 true。## 输入: flag_name (String) - 标记名。
## 输出: bool。
func _flag_enabled(flag_name: String) -> bool:
	return get_flag(flag_name, false) == true


## 闪卡上报评分。主逻辑转给 AVG，由 AVG 决定要不要打开对话。## 输入: rating (int) - 评分 1~4。
## 输出: 无。
func notify_card_answered(rating: int) -> void:
	card_answered.emit(rating)
	if _story_manager == null:
		return
	_story_manager.on_review_answered(rating)


## 按规则表过滤即将显示的卡面文字。不写数据库。## 输入:
##   card_id (int) - 卡片 ID。
##   side (String) - "front" 或 "back"。
##   raw_text (String) - 笔记字段原文。
## 输出: String - 应显示的文本。没有命中规则时原样返回。
func present_card_text(card_id: int, side: String, raw_text: String) -> String:
	var shown := raw_text
	for rule_variant in MetaRules.all():
		if typeof(rule_variant) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = rule_variant
		if not _flag_enabled(str(rule.get("when_flag", ""))):
			continue
		var replacement: Variant = rule.get("replace_card_text", null)
		if not (replacement is Dictionary):
			continue
		var spec: Dictionary = replacement
		if spec.is_empty():
			continue
		var rule_side := str(spec.get("side", ""))
		if rule_side != "" and rule_side != side:
			continue
		var rule_card_id := int(spec.get("card_id", 0))
		if rule_card_id != 0 and rule_card_id != card_id:
			continue
		shown = str(spec.get("text", shown))
	card_presented.emit(card_id, side, shown)
	return shown


## 收集当前标记下应出现的设置附加行。## 输入: 无。
## 输出: Array[Dictionary]。每项含 id、label、control。
func get_setting_extras() -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	for rule_variant in MetaRules.all():
		if typeof(rule_variant) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = rule_variant
		if not _flag_enabled(str(rule.get("when_flag", ""))):
			continue
		var entry: Variant = rule.get("unlock_setting", null)
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			extras.append(entry as Dictionary)
	return extras


## 打开唯一对话窗。剧情和教程都走这里。## 输入:
##   resource - DialogueResource。为空则不打开。
##   key (String) - 对话标识。
##   track_story (bool) - 为 true 时结束对话会写入剧情完成记录。教程传 false。
## 输出: bool。成功开始播放返回 true。
func request_dialogue(resource, key: String, track_story: bool = true) -> bool:
	if resource == null:
		push_warning("[App] 对话资源为空: %s" % key)
		return false
	_ensure_overlay()
	if _overlay == null:
		return false
	_active_dialogue_key = key
	_overlay.set_story_manager(_story_manager if track_story else null)
	dialogue_opened.emit(key)
	_overlay.start(resource, key)
	return true


## 打开指定应用（通过 WindowManager 注册表）。
## 输入: app_id (String) - 注册表中的应用 ID。
## 输出: bool - 成功返回 true。
func open_app(app_id: String) -> bool:
	if Engine.has_singleton("WindowManager"):
		var wm = Engine.get_singleton("WindowManager")
		if wm != null and wm.has_method("open_app"):
			return wm.open_app(app_id)
	# 降级：如果 WindowManager 未就绪，使用注册表中的场景路径
	push_warning("[App] WindowManager 未就绪，无法打开应用: %s" % app_id)
	return false


## 关闭指定应用。
## 输入: app_id (String) - 注册表中的应用 ID。
## 输出: 无。
func close_app(app_id: String) -> void:
	if Engine.has_singleton("WindowManager"):
		var wm = Engine.get_singleton("WindowManager")
		if wm != null and wm.has_method("close_app"):
			wm.close_app(app_id)


## 打开 AI 制卡应用。保留向后兼容的调用接口。
## 输入: 无。
## 输出: int - OK 或错误码。
func open_ai_cards() -> int:
	var ok: bool = open_app("ai_cards")
	return OK if ok else ERR_FILE_NOT_FOUND


## 切换场景。若 WindowManager 已就绪则在活动窗口内导航；否则全屏切换。
## 输入: path (String) - res:// 场景路径。
## 输出: int - Godot 错误码。文件不存在时返回 ERR_FILE_NOT_FOUND。
func goto_scene(path: String) -> int:
	if not ResourceLoader.exists(path):
		push_warning("[App] 场景不存在: %s" % path)
		return ERR_FILE_NOT_FOUND
	# 优先在活动窗口内导航
	var wm_node: Node = get_node_or_null("/root/WindowManager")
	if wm_node != null and wm_node.has_method("has_active_window") and wm_node.has_active_window():
		return wm_node.navigate_in_active(path)
	# 降级：全屏场景切换
	return get_tree().change_scene_to_file(path)


## 重置当前剧情存档和教程进度。不删除闪卡数据库。## 输入: 无。
## 输出: 无。
func reset_global_save() -> void:
	var progress := get_story_progress()
	if progress == null:
		push_warning("[App] 剧情存档未就绪，只重置教程进度")
	else:
		progress.reset()
		progress.set_chapter(DEFAULT_CHAPTER)
		progress.save_to_user()
		if _story_manager != null and _story_manager.is_dialogue_active():
			_story_manager.end_dialogue()
		story_progress_changed.emit(progress.total_progress, progress.trigger_threshold)
		flags_changed.emit("bond_value", progress.bond)
	TutorialManager.reset_all()


## 按对话选项增减好感度，并写入当前剧情存档。## 输入: amount (int) - 变化量，可为负数。
## 输出: Dictionary - StoryManager.add_bond 的结果。存档未就绪时 tier_changed 为 false。
func add_bond(amount: int) -> Dictionary:
	if _story_manager == null:
		return {"tier_changed": false, "old_tier": 0, "new_tier": 0}
	var result: Dictionary = _story_manager.add_bond(amount)
	var progress := get_story_progress()
	if progress != null:
		flags_changed.emit("bond_value", progress.bond)
	return result


## 读取当前好感度。供对话脚本里的 if 使用。## 输入: 无。
## 输出: int。存档未就绪时返回 0。
func get_bond() -> int:
	var progress := get_story_progress()
	if progress == null:
		return 0
	return progress.bond


## 调试：把剧情进度填到阈值并用 Easy 评分触发一次对话。## 输入: 无。
## 输出: 无。
func debug_fill_and_trigger() -> void:
	if _story_manager == null or _story_manager.story_progress == null:
		return
	var progress := _story_manager.story_progress
	progress.total_progress = progress.trigger_threshold
	progress.save_to_user()
	story_progress_changed.emit(progress.total_progress, progress.trigger_threshold)
	var saved_cooldown: float = _story_manager.cooldown_seconds
	_story_manager.set_cooldown(0.0)
	notify_card_answered(4)
	_story_manager.set_cooldown(saved_cooldown)


## AVG 判定该播一段剧情时，加载资源并打开对话窗。## 输入: dialogue_key (String) - 对话标识。
## 输出: 无。
func _on_story_triggered(dialogue_key: String) -> void:
	if _story_manager == null:
		return
	var resource = _story_manager.load_dialogue_resource(dialogue_key)
	if resource == null:
		push_warning("[App] 找不到对话资源: %s" % dialogue_key)
		_story_manager.end_dialogue()
		return
	request_dialogue(resource, dialogue_key, true)


## 把 AVG 的进度变化转成主逻辑信号。## 输入:
##   current (int) - 当前进度。
##   threshold (int) - 触发阈值。
## 输出: 无。
func _on_progress_updated(current: int, threshold: int) -> void:
	story_progress_changed.emit(current, threshold)


## 羁绊层级变化后刷新进度显示。## 输入:
##   _old_tier (int) - 旧层级。
##   _new_tier (int) - 新层级。
##   _tier_name (String) - 层级名称。
## 输出: 无。
func _on_bond_tier_changed(_old_tier: int, _new_tier: int, _tier_name: String) -> void:
	var progress := get_story_progress()
	if progress == null:
		return
	story_progress_changed.emit(progress.total_progress, progress.trigger_threshold)


## 对话窗关闭。## 输入: 无。
## 输出: 无。
func _on_overlay_finished() -> void:
	var key := _active_dialogue_key
	_active_dialogue_key = ""
	dialogue_closed.emit(key)


## 退出应用程序（由剧情/教程触发）。包含短暂延迟让玩家看到最后的信息。## 输入: 无。
## 输出: 无（不会返回）。
func quit_app() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0)
