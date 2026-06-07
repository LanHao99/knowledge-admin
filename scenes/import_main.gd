extends Control
class_name ImportMain

## 导入流程主界面——分步向导控制台。
## Step 1: NoteTypeSelector（选择笔记类型）
## Step 2: FieldMappingEditor（映射字段）
## Step 3: ImportProgressDialog（显示进度）
## 布局在 import_main.tscn 中定义，方便编辑器调整。

# ── 管理器引用 ──
var _import_manager: ImportManager = null
var _notetype_manager: NoteTypeManager = null
var _note_manager: NoteManager = null
var _deck_db: DeckDB = null

# ── 顶部栏 ──
@onready var _back_btn: Button = $RootPanel/RootMargin/RootVBox/TopBar/BackBtn
@onready var _title_label: Label = $RootPanel/RootMargin/RootVBox/TopBar/TitleLabel
@onready var _step_label: Label = $RootPanel/RootMargin/RootVBox/TopBar/StepLabel

# ── 文件/牌组选择 ──
@onready var _file_path_input: LineEdit = $RootPanel/RootMargin/RootVBox/MetaRow/FilePathInput
@onready var _file_pick_btn: Button = $RootPanel/RootMargin/RootVBox/MetaRow/FilePickBtn
@onready var _deck_select: OptionButton = $RootPanel/RootMargin/RootVBox/MetaRow/DeckSelect

# ── 步骤容器 ──
@onready var _step_container: Control = $RootPanel/RootMargin/RootVBox/ContentPanel/ContentMargin/StepContainer

# ── 子组件 ──
var _notetype_selector: NoteTypeSelector = null
var _field_mapping: FieldMappingEditor = null
var _progress_dialog: ImportProgressDialog = null

# 状态
var _current_step: int = 1
var _selected_note_type_id: String = ""
var _selected_note_type_entity: NoteTypeEntity = null
var _json_keys: Array[String] = []
var _json_data_array: Array = []
var _json_file_path: String = ""


## 注入所有依赖并构建子组件、启动 Step 1。
func setup(notetype_manager: NoteTypeManager, import_manager: ImportManager, note_manager: NoteManager, deck_db: DeckDB) -> void:
	_notetype_manager = notetype_manager
	_import_manager = import_manager
	_note_manager = note_manager
	_deck_db = deck_db

	_bind_actions()
	_create_sub_components()
	_refresh_deck_list()
	_show_step(1)


func _bind_actions() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_file_pick_btn.pressed.connect(_on_file_pick_pressed)
	_file_path_input.text_changed.connect(_on_file_path_changed)


func _create_sub_components() -> void:
	_notetype_selector = NoteTypeSelector.new()
	_notetype_selector.name = "NoteTypeSelector"
	_notetype_selector.visible = false
	_notetype_selector.setup(_notetype_manager)
	_notetype_selector.type_selected.connect(_on_type_selected)
	_notetype_selector.cancelled.connect(_on_selector_cancelled)
	_step_container.add_child(_notetype_selector)

	_field_mapping = FieldMappingEditor.new()
	_field_mapping.name = "FieldMappingEditor"
	_field_mapping.visible = false
	_field_mapping.mapping_confirmed.connect(_on_mapping_confirmed)
	_field_mapping.back_requested.connect(_on_mapping_back)
	_step_container.add_child(_field_mapping)

	_progress_dialog = ImportProgressDialog.new()
	_progress_dialog.name = "ImportProgressDialog"
	_progress_dialog.visible = false
	_progress_dialog.import_finished.connect(_on_import_finished)
	_step_container.add_child(_progress_dialog)


# ── 步骤导航 ──

func _show_step(step: int) -> void:
	_current_step = step
	_step_label.text = "步骤 %d/3" % step

	if _notetype_selector: _notetype_selector.visible = false
	if _field_mapping: _field_mapping.visible = false
	if _progress_dialog: _progress_dialog.visible = false

	match step:
		1:
			if _notetype_selector:
				_set_step_control_fill(_notetype_selector)
				_notetype_selector.visible = true
			_back_btn.visible = false
		2:
			if _field_mapping:
				_set_step_control_fill(_field_mapping)
				_field_mapping.visible = true
			_back_btn.visible = true
		3:
			if _progress_dialog:
				_set_step_control_fill(_progress_dialog)
				_progress_dialog.visible = true
			_back_btn.visible = false


func _set_step_control_fill(ctrl: Control) -> void:
	ctrl.layout_mode = 1
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = 0.0
	ctrl.offset_top = 0.0
	ctrl.offset_right = 0.0
	ctrl.offset_bottom = 0.0


# ── 牌组列表 ──

func _refresh_deck_list() -> void:
	if _deck_db == null or _deck_select == null:
		return
	_deck_select.clear()
	var result := _deck_db.get_all_decks(false)
	if not result.get("success", false):
		return
	for d in result.get("data", []):
		var deck: DeckEntity = d
		_deck_select.add_item("%s [ID:%d]" % [deck.name, deck.id])
		_deck_select.set_item_metadata(-1, deck.id)


func select_deck_by_id(deck_id: int) -> void:
	if _deck_select == null: return
	for i in range(_deck_select.item_count):
		var meta: Variant = _deck_select.get_item_metadata(i)
		if typeof(meta) == TYPE_INT and int(meta) == deck_id:
			_deck_select.select(i)
			return


# ── 文件选择 ──

func _on_file_path_changed(new_text: String) -> void:
	_json_file_path = new_text.strip_edges()


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


func _on_file_selected(path: String) -> void:
	_json_file_path = path
	if _file_path_input: _file_path_input.text = path
	for child in get_children():
		if child is FileDialog and child.name == "TempFileDialog":
			child.queue_free()
			break


func _is_file_valid(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)


# ── Step 1 → Step 2 ──

func _on_type_selected(note_type_id: String, note_type: Dictionary) -> void:
	_selected_note_type_id = note_type_id

	var nt_result := _notetype_manager.get_notetype(note_type_id)
	if not nt_result.get("success", false) or nt_result.get("data", null) == null:
		_show_error("找不到笔记类型: %s" % note_type_id)
		return
	_selected_note_type_entity = nt_result.get("data")

	if not _is_file_valid(_json_file_path):
		_show_error("请先选择有效的 JSON 文件")
		return

	if not _parse_json_keys(_json_file_path):
		return

	_field_mapping.setup(_import_manager)
	_field_mapping.load_mapping(_selected_note_type_entity, _json_keys)
	_show_step(2)


func _on_selector_cancelled() -> void:
	queue_free()


func _on_back_pressed() -> void:
	match _current_step:
		2: _show_step(1)
		_: _show_step(1)


# ── Step 2 → Step 3 ──

func _on_mapping_confirmed(mapping: Dictionary) -> void:
	var deck_idx: int = _deck_select.selected
	if deck_idx < 0:
		_show_error("请先选择目标牌组")
		return
	var deck_id_int: int = _deck_select.get_item_metadata(deck_idx)
	var deck_id: String = str(deck_id_int)

	_progress_dialog.setup(_import_manager)
	_show_step(3)

	var result: Dictionary = _import_manager.import_from_file(
		_json_file_path, deck_id, _selected_note_type_id, mapping
	)
	if not result.get("success", false):
		var data: Dictionary = result.get("data", {})
		call_deferred("_deferred_notify_failure", {
			"error": result.get("error", "导入失败"),
			"data": data
		})


func _deferred_notify_failure(error: Dictionary) -> void:
	if _progress_dialog != null:
		_progress_dialog._on_import_failed(error)


func _on_mapping_back() -> void:
	_show_step(1)


# ── Step 3 完成 ──

func _on_import_finished() -> void:
	queue_free()


# ── JSON 解析 ──

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

	var seen: Dictionary = {}
	for row in _json_data_array:
		if row is Dictionary:
			for key in (row as Dictionary).keys():
				var k: String = str(key).to_lower()
				if not seen.has(k):
					seen[k] = true
					_json_keys.append(str(key))
	return true


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "TempErrorDialog"
	dialog.title = "错误"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
