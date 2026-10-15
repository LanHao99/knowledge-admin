extends Panel
## 开始菜单。外部点击或 Esc 关闭，系统退出提供取消选项。

## 从注册表填充菜单。## 输入: 无。输出: 无。
func _ready() -> void:
	for app_info: Dictionary in WindowManager.get_visible_apps():
		var button: Button = Button.new()
		button.text = "  " + str(app_info.title)
		button.icon = load(app_info.icon_path) as Texture2D
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_open_app.bind(str(app_info.app_id)))
		%AppList.add_child(button)
	%AppList.add_child(HSeparator.new())
	var quit_button: Button = Button.new()
	quit_button.text = "  关闭系统…"
	quit_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit_button.pressed.connect(_on_quit_pressed)
	%AppList.add_child(quit_button)
	size.y = %AppList.get_combined_minimum_size().y + 12
	position.y = get_parent().get_node("%Taskbar").position.y - size.y

## 打开选定应用并收起菜单。## 输入: app_id。输出: 无。
func _open_app(app_id: String) -> void:
	App.open_app(app_id)
	hide()
	queue_free()

## 点击外部或按取消键时收起菜单。## 输入: event。输出: 无。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()
		queue_free()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		hide()
		queue_free()

## 弹出可取消的关闭系统确认。## 输入: 无。输出: 无。
func _on_quit_pressed() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "关闭系统"
	dialog.dialog_text = "确认要关闭系统吗？"
	dialog.confirmed.connect(App.quit_app)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_parent().add_child(dialog)
	dialog.popup_centered()
	hide()
	queue_free()

## 对话框关闭后释放，避免隐藏窗口泄漏。## 输入: dialog。输出: 无。
func _release_dialog(dialog: ConfirmationDialog) -> void:
	if not dialog.visible and not WindowManager._story_locked:
		dialog.queue_free()
