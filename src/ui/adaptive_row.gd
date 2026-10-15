@tool
extends GridContainer
## 根据可用宽度和子控件最小宽度自动调整列数。

@export_range(1, 4, 1) var preferred_columns: int = 2
@export var minimum_column_width: float = 280.0


## 监听尺寸与主题变化，在布局稳定后计算列数。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	resized.connect(_schedule_layout)
	theme_changed.connect(_schedule_layout)
	_schedule_layout()


## 延迟计算，避免在容器排序期间改变最小尺寸。## 输入: 无。
## 输出: 无。
func _schedule_layout() -> void:
	_update_columns.call_deferred()


## 选择能容纳子控件的列数。## 输入: 无。
## 输出: 无。
func _update_columns() -> void:
	if not is_inside_tree():
		return
	var column_width: float = minimum_column_width
	for child: Node in get_children():
		if child is Control and (child as Control).visible:
			column_width = maxf(column_width, (child as Control).get_combined_minimum_size().x)
	var separation: float = get_theme_constant("h_separation")
	columns = clampi(floori((size.x + separation) / (column_width + separation)), 1, preferred_columns)
