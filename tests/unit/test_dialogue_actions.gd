extends GutTest
## 验证确认阻塞、强制选择、解锁与更换分离，以及剧情窗口的特效生命周期。

const RECORD_ACTION: String = "res://tests/fixtures/record_dialogue_action.gd"
const WALLPAPER: String = "res://assets/wallpapers/mountain1.png"

var _outcome: Dictionary = {}
var _wallpaper_before: Dictionary = {}
var _config_path: String


## 暂存全局壁纸状态，所有接收测试均重定向至临时配置。## 输入: 无。输出: 无。
func before_each() -> void:
	_outcome = {"done": false, "success": false}
	_wallpaper_before = {
		"path": WallpaperSettings.wallpaper_path,
		"mode": WallpaperSettings.display_mode,
		"settings_path": WallpaperSettings.settings_path,
		"unlocked": WallpaperSettings._unlocked_wallpapers.duplicate(),
		"dirty": WallpaperSettings._dirty,
	}
	_config_path = "user://dialogue_action_test_%d.cfg" % Time.get_ticks_usec()
	WallpaperSettings.load_settings(_config_path)


## 清理未决确认并恢复原配置和延迟保存状态。## 输入: 无。输出: 无。
func after_each() -> void:
	if is_instance_valid(App._action_confirmation):
		App._action_confirmation.cancel_pending()
	WallpaperSettings._save_timer.stop()
	WallpaperSettings.wallpaper_path = _wallpaper_before.path
	WallpaperSettings.display_mode = _wallpaper_before.mode
	WallpaperSettings.settings_path = _wallpaper_before.settings_path
	WallpaperSettings._unlocked_wallpapers = _wallpaper_before.unlocked
	WallpaperSettings._dirty = _wallpaper_before.dirty
	if WallpaperSettings._dirty:
		WallpaperSettings._save_timer.start()
	WallpaperSettings.wallpaper_changed.emit(WallpaperSettings.wallpaper_path, WallpaperSettings.display_mode)
	if FileAccess.file_exists(_config_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_config_path))
	await wait_process_frames(2)


## 动作只有确认是之后才执行，重复确认不会产生第二次副作用。## 输入: 无。输出: 无。
func test_yes_runs_script_once_after_confirmation() -> void:
	var state: Dictionary = {"count": 0}
	_record_action(state)
	assert_false(_outcome.done)
	assert_eq(state.count, 0)
	var confirmation: DialogueActionConfirmation = App._action_confirmation
	assert_not_null(confirmation)
	assert_eq((confirmation.get_node("%Message") as Label).text, "运行测试动作？")
	assert_true((confirmation.get_node("%NoButton") as Button).visible)
	confirmation.accept()
	confirmation.accept()
	assert_true(_outcome.done)
	assert_true(_outcome.success)
	assert_eq(state.count, 1)


## 选择否或允许拒绝时按 Esc 都返回失败，动作保持未执行。## 输入: 无。输出: 无。
func test_no_and_escape_do_not_run_script() -> void:
	var state: Dictionary = {"count": 0}
	_record_action(state)
	App._action_confirmation.reject()
	assert_true(_outcome.done)
	assert_false(_outcome.success)
	assert_eq(state.count, 0)
	_outcome.done = false
	_record_action(state)
	var cancel_event: InputEventAction = InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	App._action_confirmation._input(cancel_event)
	assert_true(_outcome.done)
	assert_eq(state.count, 0)


## 强制确认不显示否，并且 Esc、拒绝回调和重复调用均不能绕过等待。## 输入: 无。输出: 无。
func test_mandatory_confirmation_rejects_escape_and_reentry() -> void:
	var state: Dictionary = {"count": 0}
	_record_action(state, false)
	var confirmation: DialogueActionConfirmation = App._action_confirmation
	assert_false((confirmation.get_node("%NoButton") as Button).visible)
	confirmation.reject()
	var cancel_event: InputEventAction = InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	confirmation._input(cancel_event)
	assert_false(_outcome.done)
	assert_false(await App.run_confirmed_action(RECORD_ACTION, "重复", true, [state]))
	assert_same(App._action_confirmation, confirmation)
	confirmation.accept()
	assert_true(_outcome.success)
	assert_eq(state.count, 1)


## 壁纸先领取落盘，否只取消切换，后续确认可自动应用。## 输入: 无。输出: 无。
func test_received_wallpaper_unlocks_before_choice_and_can_be_declined() -> void:
	_receive_wallpaper(true)
	assert_true(WallpaperSettings.is_wallpaper_unlocked(WALLPAPER))
	assert_eq(WallpaperSettings.wallpaper_path, "")
	var saved: ConfigFile = ConfigFile.new()
	assert_eq(saved.load(_config_path), OK)
	assert_has(saved.get_value("wallpaper", "unlocked", []), WALLPAPER)
	App._action_confirmation.reject()
	assert_false(_outcome.success)
	assert_eq(WallpaperSettings.wallpaper_path, "")
	assert_true(WallpaperSettings.is_wallpaper_unlocked(WALLPAPER))
	_receive_wallpaper(false)
	App._action_confirmation.accept()
	assert_true(_outcome.success)
	assert_eq(WallpaperSettings.wallpaper_path, WALLPAPER)
	assert_eq(saved.load(_config_path), OK)
	assert_eq(saved.get_value("wallpaper", "path", ""), WALLPAPER)


## 内部取消能结束强制确认，失效脚本和图片不能留下弹窗。## 输入: 无。输出: 无。
func test_internal_stop_and_invalid_requests_do_not_execute() -> void:
	var state: Dictionary = {"count": 0}
	_record_action(state, false)
	App._action_confirmation.cancel_pending()
	assert_true(_outcome.done)
	assert_false(_outcome.success)
	assert_eq(state.count, 0)
	assert_false(await App.run_confirmed_action("res://missing_action.gd", "无效"))
	assert_false(await App.run_confirmed_action("res://scenes/desktop/desktop.gd", "节点脚本"))
	assert_false(await App.send_wallpaper("res://icon.svg"))
	assert_null(App._action_confirmation)


## 控制面板隐藏锁定图片，收到后加入列表且保留原选择与预览。## 输入: 无。输出: 无。
func test_open_control_panel_refreshes_unlocked_entries() -> void:
	var panel: Control = load("res://scenes/ui/settings.tscn").instantiate() as Control
	add_child_autofree(panel)
	var items: ItemList = panel.get_node("%WallpaperList") as ItemList
	var original_paths: PackedStringArray = []
	for index: int in items.item_count:
		var path: String = str(items.get_item_metadata(index))
		original_paths.append(path)
		assert_false(WallpaperSettings.LOCKED_BY_DEFAULT.has(path))
	assert_eq(original_paths[0], "")
	var selected_path: String = "res://assets/wallpapers/tree.jpg"
	WallpaperSettings.set_wallpaper(selected_path)
	assert_true(WallpaperSettings.unlock_wallpaper(WALLPAPER))
	assert_eq(items.item_count, original_paths.size() + 1)
	assert_eq(items.get_item_text(0), "无壁纸")
	for index: int in items.item_count:
		var path: String = str(items.get_item_metadata(index))
		assert_ne(path, "res://assets/wallpapers/tower1.png")
		if path == WALLPAPER:
			assert_eq(items.get_item_text(index), "mountain1.png")
			assert_not_null(items.get_item_icon(index))
			assert_false(items.is_item_disabled(index))
	var selected: PackedInt32Array = items.get_selected_items()
	assert_eq(selected.size(), 1)
	assert_eq(items.get_item_metadata(selected[0]), selected_path)
	assert_eq(WallpaperSettings.wallpaper_path, selected_path)
	assert_eq((panel.get_node("%WallpaperPreview") as TextureRect).texture.resource_path, selected_path)


## 剧情特效仅作用于播放中的未知程序，完全破碎释放实例和任务栏后可重新打开。## 输入: 无。输出: 无。
func test_story_window_damage_and_shatter_release_modal_lock() -> void:
	var desktop: Control = load("res://scenes/desktop/desktop.tscn").instantiate() as Control
	add_child_autofree(desktop)
	assert_false(WindowManager.set_story_window_damage(0.7))
	assert_not_null(WindowManager.begin_dialogue(true, null))
	var window: ManagedWindow = WindowManager.get_app_window("unknown_program")
	var previous: WeakRef = weakref(window)
	assert_false(WindowManager.shatter_app("unknown_program"))
	assert_true(WindowManager.set_story_window_damage(0.7))
	assert_eq(window.damage_amount, 0.7)
	assert_false(WindowManager.set_story_window_damage(NAN))
	assert_true(WindowManager.shatter_story_window(_finish_test_story))
	assert_false(WindowManager.shatter_story_window(_finish_test_story))
	await wait_process_frames(5)
	assert_null(previous.get_ref())
	assert_null(WindowManager.get_app_window("unknown_program"))
	assert_false(WindowManager._story_locked)
	assert_false(desktop.get_node("ModalLayer").visible)
	assert_not_null(WindowManager.begin_dialogue(true, null))
	assert_eq(WindowManager.get_app_window("unknown_program").damage_amount, 0.0)
	WindowManager.end_dialogue(true)


## 最小化保留半破损，点击关闭销毁进程后重新打开恢复完好。## 输入: 无。输出: 无。
func test_partial_damage_survives_minimize_and_clears_after_process_close() -> void:
	var desktop: Control = load("res://scenes/desktop/desktop.tscn").instantiate() as Control
	add_child_autofree(desktop)
	assert_not_null(WindowManager.begin_dialogue(true, null))
	var window: ManagedWindow = WindowManager.get_app_window("unknown_program")
	assert_true(WindowManager.set_story_window_damage(0.7))
	WindowManager.end_dialogue(true)
	assert_true(window.is_minimized())
	assert_eq(window.damage_amount, 0.7)
	assert_true(WindowManager.open_app("unknown_program"))
	assert_same(WindowManager.get_app_window("unknown_program"), window)
	assert_eq(window.damage_amount, 0.7)
	var previous: WeakRef = weakref(window)
	window._on_close_pressed()
	assert_null(WindowManager.get_app_window("unknown_program"))
	assert_false(desktop.get_node("%Taskbar")._app_buttons.has("unknown_program"))
	await wait_process_frames(2)
	assert_null(previous.get_ref())
	assert_true(WindowManager.open_app("unknown_program"))
	var reopened: ManagedWindow = WindowManager.get_app_window("unknown_program")
	assert_eq(reopened.damage_amount, 0.0)
	assert_false((reopened.get_node("DamageOverlay") as CanvasItem).visible)
	assert_not_null(WindowManager.begin_dialogue(true, null))
	assert_eq(WindowManager.get_app_window("unknown_program").damage_amount, 0.0)
	WindowManager.end_dialogue(true)


## 在不启动剧情管理器的窗口测试中解除模态。## 输入: 无。输出: 无。
func _finish_test_story() -> void:
	WindowManager.end_dialogue(true)


## 异步记录通用确认入口的结果。## 输入: 状态字典、是否允许否。输出: 无。
func _record_action(state: Dictionary, allow_no: bool = true) -> void:
	_outcome.success = await App.run_confirmed_action(RECORD_ACTION, "运行测试动作？", allow_no, [state])
	_outcome.done = true


## 异步记录壁纸接收入口的结果。## 输入: allow_no (bool)。输出: 无。
func _receive_wallpaper(allow_no: bool) -> void:
	_outcome.done = false
	_outcome.success = await App.send_wallpaper(WALLPAPER, "收到一张壁纸，是否更换？", allow_no)
	_outcome.done = true
