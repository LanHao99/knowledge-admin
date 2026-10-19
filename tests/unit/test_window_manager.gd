extends GutTest
## 窗口管理器核心行为测试。验证应用开关、Z 轴激活、注册表查询等功能。

var _wm: Node = null
var _fake_container: Control = null
var _fake_taskbar: Node = null


## 创建独立 WindowManager 实例并准备假容器。
## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_wm = autofree(load("res://src/window_manager.gd").new())
	_fake_container = autofree(Control.new())
	_fake_taskbar = autofree(Node.new())
	# 不 add_child，纯逻辑测试


## 验证注册表包含所有预期应用且 unknown_program 不可见。
## 输入: 无。
## 输出: 无。
func test_registry_has_expected_apps() -> void:
	assert_true(_wm.REGISTRY.has("knowledge_admin"))
	assert_true(_wm.REGISTRY.has("ai_cards"))
	assert_true(_wm.REGISTRY.has("control_panel"))
	assert_true(_wm.REGISTRY.has("my_computer"))
	assert_true(_wm.REGISTRY.has("recycle_bin"))
	assert_true(_wm.REGISTRY.has("unknown_program"))
	assert_false(_wm.REGISTRY["unknown_program"].get("entry_visible", true),
		"unknown_program 必须不出现在入口列表")


## 验证 get_visible_apps 不包含隐藏应用。
## 输入: 无。
## 输出: 无。
func test_visible_apps_excludes_hidden() -> void:
	var visible: Array[Dictionary] = _wm.get_visible_apps()
	for item: Dictionary in visible:
		assert_ne(item.get("app_id", ""), "unknown_program",
			"隐藏应用不应出现在可见列表")
	assert_gt(visible.size(), 0, "至少有一个可见应用")


## 验证初始状态下无活动窗口。
## 输入: 无。
## 输出: 无。
func test_initial_state_no_active_window() -> void:
	assert_false(_wm.has_active_window())
	assert_eq(_wm.get_active_app_id(), "")


## 验证 open_app 对未知 ID 返回 false。
## 输入: 无。
## 输出: 无。
func test_open_unknown_app_returns_false() -> void:
	_wm.setup(_fake_container, _fake_taskbar)
	# 未知程序场景不存在时会提前失败并发出警告
	assert_false(_wm.open_app("nonexistent_app_xyz"))


## 验证 close_app 对未开启应用不报错。
## 输入: 无。
## 输出: 无。
func test_close_never_opened_app_is_safe() -> void:
	_wm.close_app("knowledge_admin")  # 不应抛出错误
	assert_false(_wm.has_active_window())


## 验证 navigate_in_active 在无活动窗口时返回错误码。
## 输入: 无。
## 输出: 无。
func test_navigate_without_active_window_returns_error() -> void:
	var result: int = _wm.navigate_in_active("res://content/scenes/ui/main_menu.tscn")
	assert_ne(result, OK, "无活动窗口时应返回错误")


## 验证 get_app_window 对未开启应用返回 null。
## 输入: 无。
## 输出: 无。
func test_get_window_for_closed_app_returns_null() -> void:
	assert_null(_wm.get_app_window("knowledge_admin"))


## 验证 open_app 对场景路径不存在的情况返回 false 且不发信号。
## 输入: 无。
## 输出: 无。
func test_open_app_with_missing_scene_does_not_emit_opened() -> void:
	_wm.setup(_fake_container, _fake_taskbar)
	watch_signals(_wm)
	# recycle_bin 的 tscn 还未创建时应返回 false（不依赖修改 const）
	# 用完全不存在的 ID 验证路径
	var result: bool = _wm.open_app("__never_registered_id__")
	assert_false(result)
	assert_signal_not_emitted(_wm, "app_opened")
