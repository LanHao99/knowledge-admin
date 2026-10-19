extends GutTest
## 使用真实窗口场景验证几何与生命周期，不连接玩家数据库。

var _area: Control
var _window: ManagedWindow

## 构造固定工作区及只读回收站窗口。## 输入: 无。输出: 无。
func before_each() -> void:
	_area = add_child_autofree(Control.new())
	_area.size = Vector2(1280, 672)
	_window = load("res://content/scenes/desktop/managed_window.tscn").instantiate() as ManagedWindow
	_area.add_child(_window)
	_window.initialize("recycle_bin", "回收站", "res://content/scenes/desktop/recycle_bin.tscn")

## 最小化和恢复不能重建内容。## 输入: 无。输出: 无。
func test_minimize_retains_content() -> void:
	var content: Control = _window.get_content()
	_window._on_minimize_pressed()
	assert_true(_window.is_minimized())
	assert_false(_window.visible)
	_window.restore()
	assert_same(_window.get_content(), content)
	assert_false(_window.is_minimized())

## 最大化使用已经扣除任务栏的工作区，最小化后仍可恢复原始矩形。## 输入: 无。输出: 无。
func test_maximize_restore_and_minimize() -> void:
	var original: Rect2 = Rect2(_window.position, _window.size)
	_window._on_maximize_pressed()
	assert_eq(_window.size, _area.size)
	assert_eq(_window.position, Vector2.ZERO)
	_window._on_minimize_pressed()
	_window.restore()
	assert_eq(_window.size, _area.size)
	_window._on_maximize_pressed()
	assert_eq(Rect2(_window.position, _window.size), original)

## 剧情按钮锁不能通过直接触发处理方法绕过。## 输入: 无。输出: 无。
func test_locked_controls_do_not_close_or_minimize() -> void:
	watch_signals(_window)
	_window.set_close_locked(true)
	_window.set_minimize_locked(true)
	_window._on_close_pressed()
	_window._on_minimize_pressed()
	assert_signal_not_emitted(_window, "close_requested")
	assert_false(_window.is_minimized())

## 工作区变小时保持标题及窗口在可用区域内。## 输入: 无。输出: 无。
func test_smaller_work_area_clamps_bounds() -> void:
	_area.size = Vector2(800, 540)
	_window.position = Vector2(2000, 2000)
	_window.fit_work_area()
	assert_true(Rect2(Vector2.ZERO, _area.size).encloses(Rect2(_window.position, _window.size)))

## 八个方向均能缩放，左上方向达到最小值时不漂移对边。## 输入: 无。输出: 无。
func test_resize_all_eight_directions() -> void:
	var rect: Rect2 = Rect2(100, 100, 800, 600)
	for direction: int in range(1, 9):
		var result: Rect2 = ManagedWindow.resized_rect(rect, Vector2(25, 35), direction, Vector2(200, 120))
		assert_ne(result, rect, "方向 %d 必须改变矩形" % direction)
	var limited: Rect2 = ManagedWindow.resized_rect(rect, Vector2(2000, 2000), ManagedWindow.ResizeDir.TOP_LEFT, Vector2(200, 120))
	assert_eq(limited.size, Vector2(200, 120))
	assert_eq(limited.end, rect.end)
