extends Control
class_name ImportMain

## 导入流程主界面——分步向导控制台。
## Step 1: NoteTypeSelector（选择笔记类型）
## Step 2: FieldMappingEditor（映射字段）
## Step 3: ImportProgressDialog（显示进度）
##
## 使用显隐切换实现分步导航（三页面共享同一容器区域）。


# ── 管理器引用 ──
var _import_manager: ImportManager = null
var _notetype_manager: NoteTypeManager = null
var _note_manager: NoteManager = null
var _deck_db: DeckDB = null

# ── 子组件 ──
var _notetype_selector: NoteTypeSelector = null
var _field_mapping: FieldMappingEditor = null
var _progress_dialog: ImportProgressDialog = null

# ── 顶部栏 ──
var _title_label: Label = null
var _back_btn: Button = null
var _step_label: Label = null

# ── 文件/牌组选择器 ──
var _file_path_input: LineEdit = null
var _file_pick_btn: Button = null
var _deck_select: OptionButton = null

# ── 步骤容器 ──
var _step_container: Control = null
var _current_step: int = 1

# 缓存的状态数据
var _selected_note_type_id: String = ""
var _selected_note_type_dict: Dictionary = {}
var _selected_note_type_entity: NoteTypeEntity = null
var _json_keys: Array[String] = []
var _json_data_array: Array = []
var _json_file_path: String = ""


## 注入所有依赖并构建 UI、启动 Step 1。## 输入:
##   notetype_manager (NoteTypeManager) - 笔记类型管理器。
##   import_manager (ImportManager) - 导入管理器。
##   note_manager (NoteManager) - 笔记管理器。
##   deck_db (DeckDB) - 牌组数据仓库。
## 输出: 无。
func setup(notetype_manager: NoteTypeManager, import_manager: ImportManager, note_manager: NoteManager, deck_db: DeckDB) -> void:
	_notetype_manager = notetype_manager
	_import_manager = import_manager
	_note_manager = note_manager
	_deck_db = deck_db

	_build_ui()
	_inject_dependencies()
	_show_step(1)


## 构建顶层 UI 布局。## 输入: 无。
## 输出: 无。
func _build_ui() -> void:
	# 根容器
	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── 顶部标题栏 ──
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	_back_btn = Button.new()
	_back_btn.name = "BackBtn"
	_back_btn.text = "← 返回"
	_back_btn.custom_minimum_size = Vector2(80, 36)
	_back_btn.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_btn)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "批量导入"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(_title_label)

	_step_label = Label.new()
	_step_label.name = "StepLabel"
	_step_label.text = "步骤 1/3"
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_label.custom_minimum_size = Vector2(80, 0)
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", Color.GRAY)
	top_bar.add_child(_step_label)

	# ── 文件/牌组选择行（始终可见） ──
	var meta_row := HBoxContainer.new()
	meta_row.name = "MetaRow"
	meta_row.add_theme_constant_override("separation", 8)
	root.add_child(meta_row)

	var file_label := Label.new()
	file_label.name = "FileLabel"
	file_label.text = "JSON 文件:"
	file_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_row.add_child(file_label)

	_file_path_input = LineEdit.new()
	_file_path_input.name = "FilePathInput"
	_file_path_input.placeholder_text = "选择或输入 JSON 文件路径..."
	_file_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_path_input.text_changed.connect(_on_file_path_changed)
	meta_row.add_child(_file_path_input)

	_file_pick_btn = Button.new()
	_file_pick_btn.name = "FilePickBtn"
	_file_pick_btn.text = "浏览..."
	_file_pick_btn.custom_minimum_size = Vector2(70, 0)
	_file_pick_btn.pressed.connect(_on_file_pick_pressed)
	meta_row.add_child(_file_pick_btn)

	var deck_label := Label.new()
	deck_label.name = "DeckLabel"
	deck_label.text = "目标牌组:"
	deck_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_row.add_child(deck_label)

	_deck_select = OptionButton.new()
	_deck_select.name = "DeckSelect"
	_deck_select.custom_minimum_size = Vector2(120, 0)
	meta_row.add_child(_deck_select)

	# 分隔线
	var sep := HSeparator.new()
	sep.name = "Separator"
	root.add_child(sep)

	# ── 步骤内容容器 ──
	var content_margin := MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_left", 4)
	content_margin.add_theme_constant_override("margin_right", 4)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(content_margin)

	_step_container = Control.new()
	_step_container.name = "StepContainer"
	_step_container.size_flags_horizontal = Control.SIZE_FILL
	_step_container.size_flags_vertical = Control.SIZE_FILL
	content_margin.add_child(_step_container)

	# 刷新牌组列表
	_refresh_deck_list()


## 创建并注入子组件依赖。## 输入: 无。
## 输出: 无。
func _inject_dependencies() -> void:
	# NoteTypeSelector
	_notetype_selector = NoteTypeSelector.new()
	_notetype_selector.name = "NoteTypeSelector"
	_notetype_selector.visible = false
	_notetype_selector.type_selected.connect(_on_type_selected)
	_notetype_selector.cancelled.connect(_on_selector_cancelled)
	_step_container.add_child(_notetype_selector)

	# FieldMappingEditor
	_field_mapping = FieldMappingEditor.new()
	_field_mapping.name = "FieldMappingEditor"
	_field_mapping.visible = false
	_field_mapping.mapping_confirmed.connect(_on_mapping_confirmed)
	_field_mapping.back_requested.connect(_on_mapping_back)
	_step_container.add_child(_field_mapping)

	# ImportProgressDialog
	_progress_dialog = ImportProgressDialog.new()
	_progress_dialog.name = "ImportProgressDialog"
	_progress_dialog.visible = false
	_progress_dialog.import_finished.connect(_on_import_finished)
	_step_container.add_child(_progress_dialog)


# ── 步骤导航 ──


## 切换到指定步骤。## 输入: step (int) - 步骤编号 1/2/3。
## 输出: 无。
func _show_step(step: int) -> void:
	_current_step = step
	_step_label.text = "步骤 %d/3" % step

	# 隐藏所有
	if _notetype_selector != null:
		_notetype_selector.visible = false
	if _field_mapping != null:
		_field_mapping.visible = false
	if _progress_dialog != null:
		_progress_dialog.visible = false

	# 显示目标步骤
	match step:
		1:
			if _notetype_selector != null:
				_set_step_control_fill(_notetype_selector)
				_notetype_selector.visible = true
			_back_btn.visible = false
			_meta_row_visible(true)
		2:
			if _field_mapping != null:
				_set_step_control_fill(_field_mapping)
				_field_mapping.visible = true
			_back_btn.visible = true
			_meta_row_visible(false)
		3:
			if _progress_dialog != null:
				_set_step_control_fill(_progress_dialog)
				_progress_dialog.visible = true
			_back_btn.visible = false
			_meta_row_visible(false)


## 设置步骤组件填满容器（通过锚点）。## 输入: ctrl (Control) - 步骤组件。
## 输出: 无。
func _set_step_control_fill(ctrl: Control) -> void:
	ctrl.layout_mode = 1  # PRESSED / anchors mode
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = 0.0
	ctrl.offset_top = 0.0
	ctrl.offset_right = 0.0
	ctrl.offset_bottom = 0.0


## 控制元数据行的可见性。## 输入: show (bool) - 是否可见。
## 输出: 无。
func _meta_row_visible(show: bool) -> void:
	var meta_row := get_node_or_null("RootVBox/MetaRow")
	if meta_row != null:
		meta_row.visible = show


# ── 牌组列表 ──


## 刷新牌组下拉列表。## 输入: 无。
## 输出: 无。
func _refresh_deck_list() -> void:
	if _deck_db == null or _deck_select == null:
		return

	_deck_select.clear()
	var result := _deck_db.get_all_decks(false)
	if not result.get("success", false):
		return

	var decks: Array = result.get("data", [])
	for d in decks:
		var deck: DeckEntity = d
		_deck_select.add_item("%s [ID:%d]" % [deck.name, deck.id])
		_deck_select.set_item_metadata(-1, deck.id)


## 根据 deck_id 预选牌组下拉项（用于 DeckList 编辑面板入口）。## 输入: deck_id (int) - 牌组 ID。
## 输出: 无。
func select_deck_by_id(deck_id: int) -> void:
	if _deck_select == null:
		return
	for i in range(_deck_select.item_count):
		var meta: Variant = _deck_select.get_item_metadata(i)
		if typeof(meta) == TYPE_INT and int(meta) == deck_id:
			_deck_select.select(i)
			return


# ── 文件选择 ──


## 文件路径变更回调。## 输入: new_text (String) - 新文件路径。
## 输出: 无。
func _on_file_path_changed(new_text: String) -> void:
	_json_file_path = new_text.strip_edges()


## "浏览"按钮——打开文件选择对话框。## 输入: 无。
## 输出: 无。
func _on_file_pick_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.name = "TempFileDialog"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "选择 JSON 文件"
	file_dialog.add_filter("*.json", "JSON Files")
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(file_dialog.queue_free)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(600, 500))


## 文件选择对话框确认后回调。## 输入: path (String) - 选中的文件路径。
## 输出: 无。
func _on_file_selected(path: String) -> void:
	_json_file_path = path
	if _file_path_input != null:
		_file_path_input.text = path

	# 清理临时对话框
	var sender: FileDialog = null
	for child in get_children():
		if child is FileDialog and child.name == "TempFileDialog":
			sender = child
			break
	if sender != null:
		sender.queue_free()


## 检查文件是否有效。## 输入: path (String) - 文件路径。
## 输出: bool。
func _is_file_valid(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)


# ── Step 1 → Step 2：类型选择后解析 JSON ──


## NoteTypeSelector 的 type_selected 回调——推进到 Step 2。## 输入:
##   note_type_id (String) - 选中的笔记类型 ID。
##   note_type (Dictionary) - 笔记类型摘要。
## 输出: 无。
func _on_type_selected(note_type_id: String, note_type: Dictionary) -> void:
	_selected_note_type_id = note_type_id
	_selected_note_type_dict = note_type

	# 获取完整 NoteTypeEntity（用于 auto_map 等操作）
	var nt_result := _notetype_manager.get_notetype(note_type_id)
	if not nt_result.get("success", false) or nt_result.get("data", null) == null:
		_show_error("找不到笔记类型: %s" % note_type_id)
		return
	_selected_note_type_entity = nt_result.get("data")

	# 解析 JSON 文件获取 keys
	if not _is_file_valid(_json_file_path):
		_show_error("请先选择有效的 JSON 文件")
		return

	var parse_ok: bool = _parse_json_keys(_json_file_path)
	if not parse_ok:
		return

	# 注入 FieldMappingEditor
	_field_mapping.setup(_import_manager)
	_field_mapping.load_mapping(_selected_note_type_entity, _json_keys)

	# 进入 Step 2
	_show_step(2)


## NoteTypeSelector 的 cancelled 回调。## 输入: 无。
## 输出: 无。
func _on_selector_cancelled() -> void:
	# 返回调用方（由外部场景处理）
	queue_free()


## "返回"按钮——根据当前步骤返回。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	match _current_step:
		2:
			_show_step(1)
		_:
			_show_step(1)


# ── Step 2 → Step 3：映射确认后执行导入 ──


## FieldMappingEditor 的 mapping_confirmed 回调——执行导入 + 推进到 Step 3。## 输入: mapping (Dictionary) - {json_key: note_type_field}。
## 输出: 无。
func _on_mapping_confirmed(mapping: Dictionary) -> void:
	# 获取选中牌组 ID
	var deck_idx: int = _deck_select.selected
	if deck_idx < 0:
		_show_error("请先选择目标牌组")
		return
	var deck_id_int: int = _deck_select.get_item_metadata(deck_idx)
	var deck_id: String = str(deck_id_int)

	# 设置进度对话框
	_progress_dialog.setup(_import_manager)

	# 进入 Step 3
	_show_step(3)

	# 尝试执行导入
	var result: Dictionary = _import_manager.import_from_file(
		_json_file_path,
		deck_id,
		_selected_note_type_id,
		mapping
	)

	# 如果导入立即失败（非异步），直接处理
	if not result.get("success", false):
		# 信号可能不会发射（全部失败），手动触发进度对话框更新
		var data: Dictionary = result.get("data", {})
		var error_info := {
			"error": result.get("error", "导入失败"),
			"data": data
		}
		# 给进度对话框一个帧的时间来 setup
		call_deferred("_deferred_notify_failure", error_info)


## 延迟通知导入失败（等待进度对话框 setup 完成）。## 输入: error (Dictionary) - 错误信息。
## 输出: 无。
func _deferred_notify_failure(error: Dictionary) -> void:
	if _progress_dialog != null:
		_progress_dialog._on_import_failed(error)


## FieldMappingEditor 的 back_requested 回调——返回 Step 1。## 输入: 无。
## 输出: 无。
func _on_mapping_back() -> void:
	_show_step(1)


# ── Step 3 完成 ──


## ImportProgressDialog 的 import_finished 回调。## 输入: 无。
## 输出: 无。
func _on_import_finished() -> void:
	# 导入流程结束，清理并通知外部
	queue_free()


# ── JSON 解析 ──


## 解析 JSON 文件并提取键名列表。## 输入: path (String) - JSON 文件路径。
## 输出: bool - 解析成功返回 true。
func _parse_json_keys(path: String) -> bool:
	_json_keys.clear()
	_json_data_array.clear()

	if not FileAccess.file_exists(path):
		_show_error("JSON 文件不存在: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_error("无法打开 JSON 文件: %s" % path)
		return false

	var text: String = file.get_as_text()
	file.close()

	var parser := JSON.new()
	var parse_code: int = parser.parse(text)
	if parse_code != OK:
		_show_error("JSON 解析失败: line=%d msg=%s" % [parser.get_error_line(), parser.get_error_message()])
		return false

	var raw_data: Variant = parser.data

	# 归一化为数组
	if typeof(raw_data) == TYPE_DICTIONARY:
		_json_data_array = [raw_data as Dictionary]
	elif typeof(raw_data) == TYPE_ARRAY:
		_json_data_array = raw_data as Array
	else:
		_show_error("JSON 数据格式错误：顶层必须是数组或对象")
		return false

	if _json_data_array.is_empty():
		_show_error("JSON 数据为空")
		return false

	# 收集所有行的键名
	var seen: Dictionary = {}
	for row in _json_data_array:
		if row is Dictionary:
			for key in (row as Dictionary).keys():
				var k: String = str(key).to_lower()
				if not seen.has(k):
					seen[k] = true
					_json_keys.append(str(key))

	return true


# ── 错误提示 ──


## 显示错误提示对话框。## 输入: message (String) - 错误消息。
## 输出: 无。
func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "TempErrorDialog"
	dialog.title = "错误"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
