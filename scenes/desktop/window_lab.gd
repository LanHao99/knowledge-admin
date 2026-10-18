extends Control
## 用三个动作按钮演示整个宿主窗口的破损、恢复与完全碎裂。

@export_range(0.1, 1.0, 0.05) var damage_strength: float = 0.7


## 连接动作按钮；独立运行内容场景时说明需要桌面宿主。## 输入: 无。输出: 无。
func _ready() -> void:
	%ShatterButton.pressed.connect(_on_shatter_pressed)
	%DamageButton.pressed.connect(_on_damage_pressed)
	%RestoreButton.pressed.connect(_on_restore_pressed)
	if _host() == null:
		%Status.text = "请从桌面打开窗口实验室，体验整个窗口的效果。"
		for button: Button in [%ShatterButton, %DamageButton, %RestoreButton]:
			button.disabled = true


## 查找包含标题栏和边框的真实宿主。## 输入: 无。输出: ManagedWindow 或 null。
func _host() -> ManagedWindow:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is ManagedWindow:
			return ancestor as ManagedWindow
		ancestor = ancestor.get_parent()
	return null


## 请求结束应用并让整个窗口碎裂。## 输入: 无。输出: 无。
func _on_shatter_pressed() -> void:
	var host: ManagedWindow = _host()
	if host != null:
		WindowManager.shatter_app(host._app_id)


## 设置可重复比较的固定局部损伤。## 输入: 无。输出: 无。
func _on_damage_pressed() -> void:
	var host: ManagedWindow = _host()
	if host != null and WindowManager.set_app_damage(host._app_id, damage_strength):
		%Status.text = "玻璃已经开裂。文字仍可编辑，窗口仍可拖动和缩放。"


## 清除损伤并保留示例文本和窗口布局。## 输入: 无。输出: 无。
func _on_restore_pressed() -> void:
	var host: ManagedWindow = _host()
	if host != null and WindowManager.set_app_damage(host._app_id, 0.0):
		%Status.text = "窗口已恢复。你输入的内容会保留。"
