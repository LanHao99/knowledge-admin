extends Control
class_name NoteTypeSelector

## 导入流程第1步——选择目标笔记类型。
## 独立组件，可被 ImportMain 或其他场景复用。
## 显示所有笔记类型列表，发射 type_selected 信号通知调用方。


# 数据层
var _notetype_manager: NoteTypeManager = null

# UI 节点
var _title_label: Label = null
var _type_list: ItemList = null
var _next_btn: Button = null
var _cancel_btn: Button = null
var _status_label: Label = null

# 缓存的类型数据
var _all_types: Array = []  # Array[NoteTypeEntity]

# 信号
signal type_selected(note_type_id: String, note_type: Dictionary)
signal cancelled()


## 注入 NoteTypeManager 依赖并构建 UI。## 输入: notetype_manager (NoteTypeManager) - 笔记类型管理器。
## 输出: 无。
func setup(notetype_manager: NoteTypeManager) -> void:
	_notetype_manager = notetype_manager
	_build_ui()
	_refresh_list()


## 构建 UI 布局（纯代码动态创建）。## 输入: 无。
## 输出: 无。
func _build_ui() -> void:
	# 根容器
	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "选择笔记类型"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_title_label)

	# 提示文字
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "请选择导入笔记的目标类型："
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)

	# 笔记类型列表
	var list_container := MarginContainer.new()
	list_container.name = "ListContainer"
	list_container.add_theme_constant_override("margin_left", 20)
	list_container.add_theme_constant_override("margin_right", 20)
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list_container)

	_type_list = ItemList.new()
	_type_list.name = "TypeList"
	_type_list.allow_reselect = true
	_type_list.same_column_width = true
	list_container.add_child(_type_list)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.name = "BtnRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root.add_child(btn_row)

	_cancel_btn = Button.new()
	_cancel_btn.name = "CancelBtn"
	_cancel_btn.text = "取消"
	_cancel_btn.custom_minimum_size = Vector2(100, 36)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(_cancel_btn)

	_next_btn = Button.new()
	_next_btn.name = "NextBtn"
	_next_btn.text = "下一步"
	_next_btn.custom_minimum_size = Vector2(120, 36)
	_next_btn.disabled = true
	_next_btn.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_btn)

	# 状态标签
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_status_label)

	# 列表选中事件
	_type_list.item_selected.connect(_on_item_selected)


## 刷新笔记类型列表。## 输入: 无。
## 输出: 无。
func _refresh_list() -> void:
	if _notetype_manager == null:
		_set_status("笔记类型管理器未初始化")
		return

	_type_list.clear()
	_all_types.clear()

	var result := _notetype_manager.get_all_notetypes()
	if not result.get("success", false):
		_set_status("加载笔记类型失败: %s" % result.get("error", "未知错误"))
		return

	var types: Array = result.get("data", [])
	if types.is_empty():
		_set_status("暂无笔记类型")
		return

	var default_index: int = 0
	for i in range(types.size()):
		var nt: NoteTypeEntity = types[i]
		_all_types.append(nt)

		# 构造显示文本：名称 + 字段预览
		var field_names: Array[String] = nt.get_field_names()
		var preview: String = ", ".join(field_names.slice(0, 3))
		if field_names.size() > 3:
			preview += "…"
		var display: String = "%s  [%s]" % [nt.name, preview]

		_type_list.add_item(display)

		# 默认选中 "默认" 类型
		if nt.is_default():
			default_index = i

	_type_list.select(default_index)
	_next_btn.disabled = false
	_set_status("共 %d 个笔记类型" % types.size())


## 列表项点击处理。## 输入: index (int) - 选中的索引。
## 输出: 无。
func _on_item_selected(index: int) -> void:
	_next_btn.disabled = false


## "下一步"按钮点击——发射 type_selected 信号。## 输入: 无。
## 输出: 无。
func _on_next_pressed() -> void:
	var selected: Array = _type_list.get_selected_items()
	if selected.is_empty():
		_set_status("请先选择一个笔记类型")
		return

	var idx: int = selected[0]
	if idx < 0 or idx >= _all_types.size():
		_set_status("无效的选择")
		return

	var entity: NoteTypeEntity = _all_types[idx]
	var note_type_dict: Dictionary = {
		"id": entity.id,
		"name": entity.name,
		"field_names": entity.get_field_names(),
		"fields_schema": entity.fields_schema.duplicate(true),
		"card_templates": entity.card_templates.duplicate(true),
		"is_default": entity.is_default()
	}
	type_selected.emit(entity.id, note_type_dict)


## "取消"按钮点击——发射 cancelled 信号。## 输入: 无。
## 输出: 无。
func _on_cancel_pressed() -> void:
	cancelled.emit()


## 设置状态文字。## 输入: text (String) - 状态消息。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
