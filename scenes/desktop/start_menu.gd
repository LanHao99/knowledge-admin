extends Control
## 开始菜单弹出控件。列出可见应用和系统操作。

@onready var _app_list: VBoxContainer = %AppList


## 生成菜单项并连接关闭逻辑。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_populate()
	# 点击菜单外部时关闭
	get_tree().root.gui_input.connect(_on_root_input)


## 根据注册表填充应用列表和系统按钮。
## 输入: 无。
## 输出: 无。
func _populate() -> void:
	for child: Node in _app_list.get_children():
		child.queue_free()

	var apps: Array[Dictionary] = WindowManager.get_visible_apps()
	for app_info: Dictionary in apps:
		var btn: Button = Button.new()
		btn.text = app_info.get("title", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var app_id: String = app_info.get("app_id", "")
		btn.pressed.connect(func() -> void:
			WindowManager.open_app(app_id)
			queue_free()
		)
		_app_list.add_child(btn)

	# 分隔线
	_app_list.add_child(HSeparator.new())

	# 关闭系统
	var quit_btn: Button = Button.new()
	quit_btn.text = "关闭系统"
	quit_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit_btn.pressed.connect(_on_quit_pressed)
	_app_list.add_child(quit_btn)


## 点击菜单外部时自动关闭。
## 输入: event (InputEvent)。
## 输出: 无。
func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and not get_global_rect().has_point(mb.global_position):
			queue_free()


## 关闭系统按钮：弹出确认对话框后退出游戏。
## 输入: 无。
## 输出: 无。
func _on_quit_pressed() -> void:
	queue_free()
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.dialog_text = "确认要关闭系统吗？"
	dialog.title = "关闭系统"
	dialog.confirmed.connect(func() -> void:
		App.quit_app()
	)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
