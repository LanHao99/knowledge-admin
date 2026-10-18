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

## 剧情存档的任意内容变化。测试台和相关界面监听这一条。
signal story_state_changed

## 测试播放被停止。reason 是要显示给操作者的原因。
signal story_test_stopped(reason: String)


const OVERLAY_SCENE: String = "res://game/dialogue/story_dialogue_overlay.tscn"
const DEFAULT_CHAPTER: String = "chapter_1"
const ACTION_CONFIRMATION: PackedScene = preload("res://game/dialogue/dialogue_action_confirmation.tscn")
const SEND_WALLPAPER_ACTION: String = "res://game/dialogue/actions/send_wallpaper.gd"

var _story_manager: StoryManager = null
var _overlay: StoryDialogueOverlay = null
var _active_dialogue_key: String = ""
var _dialogue_queue: Array[Dictionary] = []
var _active_tracks_story: bool = false
var _draft_open: bool = false
var _draft_base: Dictionary = {}
var _draft: Dictionary = {}
var _test_playback: bool = false
var _stop_reason: String = ""
var _drop_next_story: bool = false
var _pending_test_backup: String = ""
var _action_confirmation: DialogueActionConfirmation
var _action_running: bool = false


## 启动 AVG，并准备唯一的对话窗。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_story()


## 创建剧情管理器并接上它的信号。章节只在存档为空时写成第一章。## 输入: 无。
## 输出: 无。
func _setup_story() -> void:
	_story_manager = StoryManager.new()
	if not _story_manager.story_triggered.is_connected(_on_story_triggered):
		_story_manager.story_triggered.connect(_on_story_triggered)
	if not _story_manager.progress_updated.is_connected(_on_progress_updated):
		_story_manager.progress_updated.connect(_on_progress_updated)
	if not _story_manager.bond_tier_changed.is_connected(_on_bond_tier_changed):
		_story_manager.bond_tier_changed.connect(_on_bond_tier_changed)
	if not _story_manager.state_changed.is_connected(_on_story_state_changed):
		_story_manager.state_changed.connect(_on_story_state_changed)
	if not DebugSettings.debug_mode_changed.is_connected(_on_debug_mode_changed):
		DebugSettings.debug_mode_changed.connect(_on_debug_mode_changed)
	var dialogue_manager = Engine.get_singleton("DialogueManager")
	_story_manager.setup(dialogue_manager)
	if _story_manager.story_progress != null and _story_manager.story_progress.current_chapter.is_empty():
		_story_manager.story_progress.set_chapter(DEFAULT_CHAPTER)
		_story_manager.story_progress.save_to_user()


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
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	story_state_changed.emit()


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


## 请求播放对话，正式剧情排在尚未开始的教程之前。## 输入: 资源、标识、是否剧情、来源节点。输出: 是否接受请求。
func request_dialogue(resource, key: String, track_story: bool = true, source: Node = null) -> bool:
	if resource == null:
		return false
	var request: Dictionary = {"resource": resource, "key": key, "story": track_story, "source": weakref(source) if source != null else null}
	if track_story:
		var insertion: int = 0
		while insertion < _dialogue_queue.size() and _dialogue_queue[insertion].story:
			insertion += 1
		_dialogue_queue.insert(insertion, request)
	else:
		_dialogue_queue.append(request)
	_play_next_dialogue.call_deferred()
	return true


## 串行打开正文视图，来源已释放的教程不再播放。## 输入: 无。输出: 无。
func _play_next_dialogue() -> void:
	if not _active_dialogue_key.is_empty() or _dialogue_queue.is_empty():
		return
	var request: Dictionary = _dialogue_queue.pop_front()
	if _drop_next_story and bool(request.get("story", false)):
		_drop_next_story = false
		if _story_manager != null:
			_story_manager.end_dialogue()
		_finish_test_stop()
		return
	var source: Node = request.source.get_ref() if request.source != null else null
	if not request.story and request.source != null and not is_instance_valid(source):
		TutorialManager._pending_scene_ids.erase(request.key)
		_play_next_dialogue.call_deferred()
		return
	_active_dialogue_key = request.key
	_active_tracks_story = request.story
	if WindowManager.is_available():
		_overlay = WindowManager.begin_dialogue(request.story, source) as StoryDialogueOverlay
	else:
		_ensure_overlay()
	if _overlay == null:
		_active_dialogue_key = ""
		if _test_playback and bool(request.get("story", false)):
			_abort_test_playback("无法打开剧情窗口")
			return
		_play_next_dialogue.call_deferred()
		return
	if not _overlay.dialogue_finished.is_connected(_on_overlay_finished):
		_overlay.dialogue_finished.connect(_on_overlay_finished)
	_overlay.set_story_manager(_story_manager if request.story else null)
	if _overlay.has_method("set_test_playback"):
		_overlay.set_test_playback(_test_playback and bool(request.get("story", false)))
	dialogue_opened.emit(request.key)
	_overlay.start(request.resource, request.key)


## 打开指定应用（通过 WindowManager 注册表）。
## 输入: app_id (String) - 注册表中的应用 ID。
## 输出: bool - 成功返回 true。
func open_app(app_id: String) -> bool:
	return WindowManager.open_app(app_id)


## 关闭指定应用。
## 输入: app_id (String) - 注册表中的应用 ID。
## 输出: 无。
func close_app(app_id: String) -> void:
	WindowManager.close_app(app_id)


## 显示确认层，选择是后运行 RefCounted 脚本的 execute(arguments)。## 输入: 脚本路径、提示内容、是否允许否、动作参数。
## 输出: bool - 确认且动作成功时为 true；取消、重入或无效脚本返回 false。
func run_confirmed_action(script_path: String, message: String, allow_no: bool = true, arguments: Array = []) -> bool:
	if _action_running or not script_path.begins_with("res://") or not ResourceLoader.exists(script_path, "GDScript"):
		return false
	var action_script: GDScript = load(script_path) as GDScript
	if action_script == null or not action_script.can_instantiate() or not ClassDB.is_parent_class(action_script.get_instance_base_type(), "RefCounted"):
		return false
	var action: RefCounted = action_script.new() as RefCounted
	if action == null or not action.has_method("execute"):
		return false
	_action_running = true
	var confirmation: DialogueActionConfirmation = ACTION_CONFIRMATION.instantiate() as DialogueActionConfirmation
	confirmation.message = message
	confirmation.allow_no = allow_no
	confirmation.show_test_stop = _test_playback
	_action_confirmation = confirmation
	add_child(confirmation)
	var accepted: bool = await confirmation.decided
	_action_confirmation = null
	confirmation.queue_free()
	var succeeded: bool = false
	if accepted:
		succeeded = bool(await action.call("execute", arguments))
	_action_running = false
	return succeeded


## 接收时解锁并保存图片，等待确认后自动更换，拒绝时保留已解锁图片。## 输入: 壁纸路径、可编辑提示、是否允许否。
## 输出: bool - 确认并成功更换时为 true。
func send_wallpaper(path: String, message: String = "收到一张壁纸，是否更换？", allow_no: bool = true) -> bool:
	if _action_running or not WallpaperSettings.unlock_wallpaper(path):
		return false
	return await run_confirmed_action(SEND_WALLPAPER_ACTION, message, allow_no, [path])


## 仅让正在播放正式剧情的未知程序局部破损。## 输入: amount (float) - 0 恢复，1 最强。
## 输出: bool - 是否接受。
func damage_story_window(amount: float = 0.7) -> bool:
	return WindowManager.set_story_window_damage(amount)


## 请求未知程序破碎，截取最后画面后完成本段剧情并释放旧窗口。## 输入: 无。输出: bool - 是否接受。
func shatter_story_window() -> bool:
	if not is_instance_valid(_overlay) or _action_running:
		return false
	_overlay.set_window_shatter_pending(true)
	if WindowManager.shatter_story_window(_on_story_shatter_captured):
		return true
	_overlay.set_window_shatter_pending(false)
	return false


## 快照完成后结束对话；窗口管理器随后释放旧实例，碎片继续独立播放。## 输入: 无。输出: 无。
func _on_story_shatter_captured() -> void:
	if is_instance_valid(_overlay):
		_overlay.finish_window_shatter()


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
		return ERR_FILE_NOT_FOUND
	if WindowManager.is_available():
		return WindowManager.navigate_in_active(path)
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
		story_state_changed.emit()
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
	_drop_next_story = false
	var key: String = _active_dialogue_key
	var tested: bool = _test_playback
	var reason: String = _stop_reason
	_active_dialogue_key = ""
	_test_playback = false
	_stop_reason = ""
	_pending_test_backup = ""
	if WindowManager.is_available():
		WindowManager.end_dialogue(_active_tracks_story)
		_overlay = null
	dialogue_closed.emit(key)
	if tested and not reason.is_empty():
		story_test_stopped.emit(reason)
		_show_stop_reason(reason)
	_play_next_dialogue.call_deferred()


## 退出应用程序（由剧情/教程触发）。包含短暂延迟让玩家看到最后的信息。## 输入: 无。
## 输出: 无（不会返回）。测试播放中改为停止测试。
func quit_app() -> void:
	if _test_playback:
		stop_story_test("剧本请求退出游戏，测试已停止。")
		return
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0)


## 把剧情管理器的统一状态变化转给界面。## 输入: 无。
## 输出: 无。
func _on_story_state_changed() -> void:
	story_state_changed.emit()


## 关闭调试模式时停止测试播放并关掉测试台。## 输入: enabled (bool)。
## 输出: 无。
func _on_debug_mode_changed(enabled: bool) -> void:
	if enabled:
		return
	if _test_playback:
		stop_story_test("调试模式已关闭")
	if WindowManager != null and WindowManager.has_method("close_debug_app"):
		WindowManager.close_debug_app("story_test")


## 读取测试台顶部需要的实时状态。## 输入: 无。
## 输出: Dictionary。
func get_story_test_state() -> Dictionary:
	var progress := get_story_progress()
	var chapter := "" if progress == null else progress.current_chapter
	var next := preview_next_story()
	var playing := _active_dialogue_key if _active_tracks_story else ""
	return {
		"chapter": chapter,
		"chapter_title": StoryCatalog.chapter_title(chapter),
		"playing_key": playing,
		"playing_title": _story_title_for_key(playing),
		"next_key": str(next.get("key", "")),
		"next_title": str(next.get("title", "")),
		"next_chapter": str(next.get("chapter", "")),
		"progress": 0 if progress == null else progress.total_progress,
		"threshold": 1 if progress == null else progress.trigger_threshold,
		"bond": 0 if progress == null else progress.bond,
		"tier": 0 if progress == null else progress.get_bond_tier(),
		"tier_name": "陌生人" if progress == null else progress.get_bond_tier_name(),
		"cooldown_remaining": 0.0 if _story_manager == null else _story_manager.cooldown_remaining(),
		"debug": _debug_enabled(),
		"busy": _story_busy(),
		"test_playing": _test_playback,
		"draft_dirty": is_story_draft_dirty(),
		"draft_conflict": has_story_draft_conflict(),
		"save_path": get_story_save_path(),
	}


## 读取按章节分组的剧情目录。## 输入: 无。
## 输出: Dictionary。管理器未就绪时 chapters 为空数组。
func get_story_catalog() -> Dictionary:
	if _story_manager == null:
		return {"chapters": []}
	return _story_manager.build_catalog()


## 无副作用地预览下一段剧情。## 输入: 无。
## 输出: Dictionary。没有下一段时为空。
func preview_next_story() -> Dictionary:
	if _story_manager == null:
		return {}
	var entry := _story_manager.preview_next_entry()
	if entry.is_empty():
		return {}
	entry["title"] = _story_manager.dialogue_title(str(entry.get("path", "")), str(entry.get("key", "")))
	return entry


## 从当前存档重新读取编辑草稿。## 输入: 无。
## 输出: Dictionary。存档未就绪时为空。
func read_story_draft() -> Dictionary:
	var progress := get_story_progress()
	if progress == null:
		_draft_open = false
		return {}
	_draft_base = progress.capture_state()
	_draft = _duplicate_snapshot(_draft_base)
	_draft_open = true
	return _duplicate_snapshot(_draft)


## 记下界面上的草稿。真正写入要等 apply_story_draft。## 输入: draft。
## 输出: 无。
func update_story_draft(draft: Dictionary) -> void:
	_draft = _duplicate_snapshot(draft)
	_draft_open = true


## 丢弃草稿并重新读取当前存档。## 输入: 无。
## 输出: Dictionary，内容与 read_story_draft 相同。
func revert_story_draft() -> Dictionary:
	return read_story_draft()


## 关闭草稿跟踪。## 输入: 无。
## 输出: 无。
func clear_story_draft() -> void:
	_draft_open = false
	_draft.clear()
	_draft_base.clear()


## 草稿相对读取时是否有未保存修改。## 输入: 无。
## 输出: bool。
func is_story_draft_dirty() -> bool:
	if not _draft_open:
		return false
	return not StoryCatalog.same_editable(_draft, _draft_base)


## 读取草稿后真实存档是否又发生了变化。## 输入: 无。
## 输出: bool。
func has_story_draft_conflict() -> bool:
	if not _draft_open:
		return false
	var progress := get_story_progress()
	if progress == null:
		return false
	return not StoryCatalog.same_snapshot(progress.capture_state(), _draft_base)


## 校验草稿，备份并保存，然后原位同步当前剧情对象。## 输入: 无。
## 输出: Dictionary。失败时当前游戏状态不变。
func apply_story_draft() -> Dictionary:
	var gate := _test_gate(false)
	if not gate.is_empty():
		return _story_failure(gate)
	if not _draft_open:
		return _story_failure("没有可应用的草稿")
	var progress := get_story_progress()
	if progress == null:
		return _story_failure("剧情存档未就绪")
	if not StoryCatalog.same_snapshot(progress.capture_state(), _draft_base):
		return _story_failure("剧情状态已变化，请重新读取")
	var built := _progress_from_draft(_draft, progress)
	if not built.success:
		return built
	var committed: Dictionary = _story_manager.commit_progress(built.data, "apply")
	if not committed.success:
		return committed
	_draft_base = progress.capture_state()
	_draft = _duplicate_snapshot(_draft_base)
	return {"success": true, "data": true}


## 忽略进度门槛和冷却，开启目录中的下一段。## 输入: 无。
## 输出: Dictionary。
func start_next_story() -> Dictionary:
	var gate := _story_launch_gate()
	if not gate.is_empty():
		return _story_failure(gate)
	var prepared: Dictionary = _story_manager.prepare_next_story()
	if not prepared.success:
		return prepared
	return _launch_prepared(prepared)


## 重排所选剧情之前的记录并强制播放，不提高好感度。## 输入: chapter、key。
## 输出: Dictionary。
func jump_to_story(chapter: String, key: String) -> Dictionary:
	var gate := _story_launch_gate()
	if not gate.is_empty():
		return _story_failure(gate)
	var prepared: Dictionary = _story_manager.prepare_story_jump(chapter, key)
	if not prepared.success:
		return prepared
	return _launch_prepared(prepared)


## 停止测试发起的播放。已发生的状态变化保留，当前这段不记完成。## 输入: reason。
## 输出: Dictionary。
func stop_story_test(reason: String = "已停止测试") -> Dictionary:
	if not _debug_enabled():
		return _story_failure("调试模式已关闭")
	if not _test_playback:
		return _story_failure("当前没有测试播放")
	_stop_reason = reason
	_pending_test_backup = ""
	_drop_next_story = true
	_remove_queued_stories()
	if _active_dialogue_key.is_empty() or _overlay == null or not _overlay.has_method("request_test_stop"):
		_drop_next_story = false
		_active_dialogue_key = ""
		if _story_manager != null and _story_manager.is_dialogue_active():
			_story_manager.end_dialogue()
		_finish_test_stop()
		return {"success": true, "data": reason}
	_overlay.request_test_stop()
	if is_instance_valid(_action_confirmation):
		_action_confirmation.cancel_pending()
	return {"success": true, "data": reason}


## 只清空剧情数据并回到第一章。不重置教程。## 输入: 无。
## 输出: Dictionary。
func reset_story_data() -> Dictionary:
	var gate := _test_gate(false)
	if not gate.is_empty():
		return _story_failure(gate)
	if _story_manager == null or get_story_progress() == null:
		return _story_failure("剧情存档未就绪")
	var replacement := StoryProgress.new()
	replacement.reset()
	replacement.set_chapter(DEFAULT_CHAPTER)
	replacement.sync_bond_flags()
	var committed: Dictionary = _story_manager.commit_progress(replacement, "reset")
	if committed.success:
		_refresh_draft_base()
	return committed


## 从一份备份恢复剧情。恢复前会再备份当前状态。## 输入: backup_path。
## 输出: Dictionary。
func restore_story_backup(backup_path: String) -> Dictionary:
	var gate := _test_gate(false)
	if not gate.is_empty():
		return _story_failure(gate)
	if _story_manager == null:
		return _story_failure("剧情存档未就绪")
	var restored: Dictionary = _story_manager.restore_backup(backup_path)
	if restored.success:
		_refresh_draft_base()
	return restored


## 按时间列出剧情备份。## 输入: 无。
## 输出: Array[Dictionary]。
func list_story_backups() -> Array[Dictionary]:
	if _story_manager == null:
		return []
	return _story_manager.list_backups()


## 返回剧情存档的绝对路径。## 输入: 无。
## 输出: String。
func get_story_save_path() -> String:
	return ProjectSettings.globalize_path(StoryProgress.SAVE_PATH)


## 返回当前剧情的只读文本。## 输入: 无。
## 输出: String。
func get_story_snapshot_text() -> String:
	var progress := get_story_progress()
	if progress == null:
		return ""
	return JSON.stringify(progress.to_dict(), "\t")


## 当前是否允许测试操作修改存档。## 输入: 无。
## 输出: bool。调试模式开启且没有播放或排队时返回 true。
func can_mutate_story_test() -> bool:
	return _test_gate(false).is_empty()


## 启动剧情前的共同限制。## 输入: 无。
## 输出: String。可以启动时返回空字符串。
func _story_launch_gate() -> String:
	var gate := _test_gate(false)
	if not gate.is_empty():
		return gate
	if is_story_draft_dirty():
		return "存在未保存修改，请先应用或撤销"
	return ""


## 把已经提交的剧情放进现有播放队列。## 输入: prepared。
## 输出: Dictionary。无法入队时恢复到启动前备份。
func _launch_prepared(prepared: Dictionary) -> Dictionary:
	var data: Dictionary = prepared.get("data", {})
	var resource: Resource = data.get("resource") as Resource
	if resource == null:
		_abort_test_playback("找不到剧情资源")
		return _story_failure("找不到剧情资源")
	_test_playback = true
	_stop_reason = ""
	_pending_test_backup = str(data.get("backup", ""))
	if not request_dialogue(resource, str(data.get("key", "")), true):
		_abort_test_playback("无法开始剧情")
		return _story_failure("无法开始剧情")
	story_state_changed.emit()
	return prepared


## 播放失败时恢复启动前备份，并解除播放锁。## 输入: message。
## 输出: 无。
func _abort_test_playback(message: String) -> void:
	var backup := _pending_test_backup
	_pending_test_backup = ""
	_test_playback = false
	_stop_reason = ""
	_drop_next_story = false
	if _story_manager != null and not backup.is_empty():
		_story_manager.restore_backup(backup)
	if _story_manager != null and _story_manager.is_dialogue_active():
		_story_manager.end_dialogue()
	_active_dialogue_key = ""
	story_test_stopped.emit(message)
	_show_stop_reason(message)


## 队列里的测试剧情还没开始时，直接结束停止流程。## 输入: 无。
## 输出: 无。
func _finish_test_stop() -> void:
	_drop_next_story = false
	var reason := _stop_reason
	_test_playback = false
	_stop_reason = ""
	_pending_test_backup = ""
	story_state_changed.emit()
	if reason.is_empty():
		return
	story_test_stopped.emit(reason)
	_show_stop_reason(reason)


## 去掉队列中的正式剧情，教程请求保留。## 输入: 无。
## 输出: 无。
func _remove_queued_stories() -> void:
	var kept: Array[Dictionary] = []
	for request in _dialogue_queue:
		if not bool(request.get("story", false)):
			kept.append(request)
	_dialogue_queue = kept


## 在桌面恢复后显示停止原因。## 输入: reason。
## 输出: 无。
func _show_stop_reason(reason: String) -> void:
	if reason.is_empty() or not is_inside_tree():
		return
	var dialog := AcceptDialog.new()
	dialog.title = "剧情测试"
	dialog.dialog_text = reason
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


## 用草稿生成一份尚未写盘的剧情副本。章节保持当前游戏中的值。## 输入: draft、live。
## 输出: Dictionary。失败时不修改 live。
func _progress_from_draft(draft: Dictionary, live: StoryProgress) -> Dictionary:
	var progress_value: Variant = draft.get("total_progress", 0)
	if typeof(progress_value) != TYPE_INT or int(progress_value) < 0:
		return _story_failure("进度必须是非负整数")
	var bond_value: Variant = draft.get("bond", 0)
	if typeof(bond_value) != TYPE_INT or int(bond_value) < 0:
		return _story_failure("好感度必须是非负整数")
	var threshold_value: Variant = draft.get("trigger_threshold", 1)
	if typeof(threshold_value) != TYPE_INT or int(threshold_value) < 1:
		return _story_failure("触发阈值至少为 1")
	var cooldown_value: Variant = draft.get("last_triggered_at", 0.0)
	if not (cooldown_value is int or cooldown_value is float) or float(cooldown_value) < 0.0:
		return _story_failure("冷却时间无效")
	var completed := _string_list(draft.get("completed_dialogues", []), "完成记录")
	if not completed.success:
		return completed
	var bonds := _string_list(draft.get("bond_dialogues_triggered", []), "羁绊完成记录")
	if not bonds.success:
		return bonds
	var completed_rows: Array = completed.data
	var bond_rows: Array = bonds.data
	var flags: Variant = draft.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return _story_failure("剧情标记格式无效")
	var draft_flags: Dictionary = flags
	var merged := StoryCatalog.merge_flags(live.flags, draft_flags)
	if not merged.success:
		return merged
	var replacement := StoryProgress.new()
	replacement.copy_from(live)
	replacement.total_progress = int(progress_value)
	replacement.bond = int(bond_value)
	replacement.trigger_threshold = int(threshold_value)
	replacement.last_triggered_at = float(cooldown_value)
	StoryProgress.assign_strings(replacement.completed_dialogues, completed_rows)
	StoryProgress.assign_strings(replacement.bond_dialogues_triggered, bond_rows)
	replacement.flags = merged.flags
	replacement.sync_bond_flags()
	return {"success": true, "data": replacement}


## 确认数组里全是字符串。## 输入: value、label。
## 输出: Dictionary。成功时 data 为 Array[String]。
func _string_list(value: Variant, label: String) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _story_failure("%s格式无效" % label)
	var rows: Array[String] = []
	for item in value:
		if typeof(item) != TYPE_STRING:
			return _story_failure("%s包含无法识别的内容" % label)
		rows.append(str(item))
	return {"success": true, "data": rows}


## 保存成功后让草稿对齐新的真实状态。## 输入: 无。
## 输出: 无。
func _refresh_draft_base() -> void:
	if not _draft_open:
		return
	var progress := get_story_progress()
	if progress == null:
		return
	_draft_base = progress.capture_state()
	_draft = _duplicate_snapshot(_draft_base)


## 深拷贝一份快照字典。## 输入: snapshot。
## 输出: Dictionary。
func _duplicate_snapshot(snapshot: Dictionary) -> Dictionary:
	return snapshot.duplicate(true)


## 为状态栏解析正在播放或下一段的标题。## 输入: dialogue_key。
## 输出: String。
func _story_title_for_key(dialogue_key: String) -> String:
	if dialogue_key.is_empty() or _story_manager == null:
		return ""
	var progress := get_story_progress()
	var chapter := "" if progress == null else progress.current_chapter
	for entry in _story_manager.ordered_story_entries():
		if str(entry.get("key", "")) == dialogue_key and str(entry.get("chapter", "")) == chapter:
			return _story_manager.dialogue_title(str(entry.get("path", "")), dialogue_key)
	for entry in _story_manager.ordered_story_entries():
		if str(entry.get("key", "")) == dialogue_key:
			return _story_manager.dialogue_title(str(entry.get("path", "")), dialogue_key)
	return dialogue_key


## 调试模式是否开启。## 输入: 无。
## 输出: bool。
func _debug_enabled() -> bool:
	return DebugSettings != null and DebugSettings.debug_mode


## 是否已有正式剧情在播放或排队。## 输入: 无。
## 输出: bool。
func _story_busy() -> bool:
	if not _active_dialogue_key.is_empty():
		return true
	for request in _dialogue_queue:
		if bool(request.get("story", false)):
			return true
	return _story_manager != null and _story_manager.is_dialogue_active()


## 测试写操作的调试和播放限制。## 输入: allow_busy。
## 输出: String。通过时返回空字符串。
func _test_gate(allow_busy: bool) -> String:
	if not _debug_enabled():
		return "调试模式已关闭"
	if not allow_busy and _story_busy():
		return "剧情正在播放或排队"
	return ""


## 组装测试操作失败结果。## 输入: message。
## 输出: Dictionary。
func _story_failure(message: String) -> Dictionary:
	return {"success": false, "error": "STORY_TEST", "message": message}
