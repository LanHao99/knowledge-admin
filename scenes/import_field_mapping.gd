extends Control
class_name FieldMappingEditor

## 导入流程第2步——映射 JSON 字段到 NoteType 字段。
## 左侧显示 JSON 原始 key（只读），右侧每个 key 对应一个下拉选项（NoteType 字段名）。
## 自动调用 import_manager.auto_map_fields() 预填充映射。


# 数据层
var _import_manager: ImportManager = null

# 缓存的映射数据
var _json_keys: Array[String] = []
var _note_type_field_names: Array[String] = []
var _note_type: NoteTypeEntity = null

# UI 节点
var _title_label: Label = null
var _scroll_container: ScrollContainer = null
var _rows_container: VBoxContainer = null
var _auto_map_btn: Button = null
var _start_btn: Button = null
var _back_btn: Button = null
var _status_label: Label = null

# 动态生成的行数据
var _mapping_rows: Array = []  # [{json_key: String, option_btn: OptionButton}]

# 信号
signal mapping_confirmed(mapping: Dictionary)
signal back_requested()


## 注入 ImportManager 依赖并构建 UI。## 输入: import_manager (ImportManager) - 导入管理器。
## 输出: 无。
func setup(import_manager: ImportManager) -> void:
	_import_manager = import_manager
	_build_ui()


## 加载映射编辑界面：传入笔记类型和 JSON 原始 keys，生成映射行。## 输入:
##   note_type (NoteTypeEntity) - 目标笔记类型实体。
##   json_keys (Array[String]) - JSON 数据中的原始键名列表。
## 输出: 无。
func load_mapping(note_type: NoteTypeEntity, json_keys: Array[String]) -> void:
	_note_type = note_type
	_json_keys = json_keys.duplicate()
	_note_type_field_names = note_type.get_field_names()
	_clear_rows()

	# 自动映射
	var auto_mapping: Dictionary = _import_manager.auto_map_fields(_json_keys, _note_type)

	# 为每个 json_key 创建映射行
	for jk in _json_keys:
		var row := HBoxContainer.new()
		row.name = "Row_%s" % jk
		row.add_theme_constant_override("separation", 8)

		# 左侧：JSON key 标签
		var key_label := Label.new()
		key_label.name = "KeyLabel"
		key_label.text = jk
		key_label.custom_minimum_size = Vector2(150, 0)
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(key_label)

		# 箭头
		var arrow := Label.new()
		arrow.name = "Arrow"
		arrow.text = "→"
		arrow.custom_minimum_size = Vector2(30, 0)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(arrow)

		# 右侧：NoteType 字段选项
		var option_btn := OptionButton.new()
		option_btn.name = "FieldOption"
		option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# 填充字段选项
		for fn in _note_type_field_names:
			option_btn.add_item(fn)

		# 根据自动映射结果预选
		if auto_mapping.has(jk):
			var mapped_field: String = str(auto_mapping[jk])
			var field_idx: int = _note_type_field_names.find(mapped_field)
			if field_idx >= 0:
				option_btn.select(field_idx)

		row.add_child(option_btn)
		_rows_container.add_child(row)

		_mapping_rows.append({
			"json_key": jk,
			"option_btn": option_btn
		})

	_update_status()


## 获取当前映射结果：{json_key: note_type_field}。## 输入: 无。
## 输出: Dictionary - 当前映射表。
func get_mapping() -> Dictionary:
	var mapping: Dictionary = {}
	for row_data in _mapping_rows:
		var json_key: String = row_data["json_key"]
		var option_btn: OptionButton = row_data["option_btn"]
		var selected_idx: int = option_btn.selected
		if selected_idx >= 0 and selected_idx < _note_type_field_names.size():
			mapping[json_key] = _note_type_field_names[selected_idx]
	return mapping


## 检查是否所有必填字段已映射（covered）。## 输入: 无。
## 输出: bool。
func _can_proceed() -> bool:
	if _note_type == null:
		return false
	var mapping := get_mapping()
	var covered: Array[String] = []
	for mk in mapping.keys():
		var field: String = str(mapping[mk])
		if not covered.has(field):
			covered.append(field)

	for fn in _note_type_field_names:
		if not covered.has(fn):
			return false
	return true


# ── UI 构建 ──


## 构建 UI 布局（纯代码动态创建）。## 输入: 无。
## 输出: 无。
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "字段映射"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_title_label)

	# 提示
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "请确认 JSON 字段与笔记类型字段的映射关系："
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	root.add_child(hint)

	# 表头
	var header := HBoxContainer.new()
	header.name = "HeaderRow"
	header.add_theme_constant_override("separation", 8)
	var left_header := Label.new()
	left_header.name = "JsonKeyHeader"
	left_header.text = "JSON 字段"
	left_header.custom_minimum_size = Vector2(150, 0)
	left_header.add_theme_font_size_override("font_size", 13)
	header.add_child(left_header)
	var arrow_space := Control.new()
	arrow_space.name = "ArrowSpace"
	arrow_space.custom_minimum_size = Vector2(30, 0)
	header.add_child(arrow_space)
	var right_header := Label.new()
	right_header.name = "FieldHeader"
	right_header.text = "笔记类型字段"
	right_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_header.add_theme_font_size_override("font_size", 13)
	header.add_child(right_header)
	root.add_child(header)

	# 滚动映射行容器
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll_container)

	_rows_container = VBoxContainer.new()
	_rows_container.name = "RowsContainer"
	_rows_container.add_theme_constant_override("separation", 6)
	_scroll_container.add_child(_rows_container)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.name = "BtnRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	root.add_child(btn_row)

	_back_btn = Button.new()
	_back_btn.name = "BackBtn"
	_back_btn.text = "上一步"
	_back_btn.custom_minimum_size = Vector2(100, 36)
	_back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(_back_btn)

	_auto_map_btn = Button.new()
	_auto_map_btn.name = "AutoMapBtn"
	_auto_map_btn.text = "自动映射"
	_auto_map_btn.custom_minimum_size = Vector2(100, 36)
	_auto_map_btn.pressed.connect(_on_auto_map_pressed)
	btn_row.add_child(_auto_map_btn)

	_start_btn = Button.new()
	_start_btn.name = "StartBtn"
	_start_btn.text = "开始导入"
	_start_btn.custom_minimum_size = Vector2(120, 36)
	_start_btn.pressed.connect(_on_start_pressed)
	btn_row.add_child(_start_btn)

	# 状态标签
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_status_label)


## 清除所有映射行。## 输入: 无。
## 输出: 无。
func _clear_rows() -> void:
	for row_data in _mapping_rows:
		var row: HBoxContainer = (row_data["option_btn"] as OptionButton).get_parent()
		if row != null:
			row.queue_free()
	_mapping_rows.clear()

	# 同时清理残留子节点（安全网）
	for child in _rows_container.get_children():
		child.queue_free()


# ── 按钮回调 ──


## "自动映射"按钮——重新运行 auto_map 并更新选项。## 输入: 无。
## 输出: 无。
func _on_auto_map_pressed() -> void:
	if _note_type == null or _json_keys.is_empty():
		return

	var auto_mapping: Dictionary = _import_manager.auto_map_fields(_json_keys, _note_type)
	for row_data in _mapping_rows:
		var json_key: String = row_data["json_key"]
		var option_btn: OptionButton = row_data["option_btn"]
		if auto_mapping.has(json_key):
			var mapped_field: String = str(auto_mapping[json_key])
			var field_idx: int = _note_type_field_names.find(mapped_field)
			if field_idx >= 0:
				option_btn.select(field_idx)

	_update_status()
	_set_status("已重新自动映射")


## "开始导入"按钮——验证后发射 mapping_confirmed 信号。## 输入: 无。
## 输出: 无。
func _on_start_pressed() -> void:
	if not _can_proceed():
		_set_status("❌ 存在未映射的必填字段，请完成所有映射")
		return

	var mapping := get_mapping()
	mapping_confirmed.emit(mapping)


## "上一步"按钮——发射 back_requested 信号。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	back_requested.emit()


## 更新映射状态。## 输入: 无。
## 输出: 无。
func _update_status() -> void:
	if _can_proceed():
		_set_status("✅ 所有必填字段已映射")
	else:
		_set_status("⚠ 尚有必填字段未映射")


## 设置状态文字。## 输入: text (String) - 状态消息。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
