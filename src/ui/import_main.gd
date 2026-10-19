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
var _writing: bool = false
var _current_step: int = 1
var _selected_note_type_id: String = ""
var _selected_note_type_entity: NoteTypeEntity = null
var _json_keys: Array[String] = []
var _json_data_array: Array = []
var _json_file_path: String = ""


## 注入全部依赖，绑定顶栏事件、构建三个步骤子组件、填充牌组下拉并进入 Step 1。## 输入:
##   notetype_manager (NoteTypeManager) - 笔记类型管理器，供 NoteTypeSelector 使用。
##   import_manager (ImportManager) - 导入管理器，供映射器与进度对话框使用。
##   note_manager (NoteManager) - 笔记管理器，保存用于后续导入写入。
##   deck_db (DeckDB) - 牌组数据库，用于填充目标牌组下拉列表。
## 输出: 无。
func setup(notetype_manager: NoteTypeManager, import_manager: ImportManager, note_manager: NoteManager, deck_db: DeckDB) -> void:
	_notetype_manager = notetype_manager
	_import_manager = import_manager
	_note_manager = note_manager
	_deck_db = deck_db

	_bind_actions()
	_create_sub_components()
	_refresh_deck_list()
	_show_step(1)


## 绑定顶栏返回、文件选择按钮与文件路径输入框的信号。## 输入: 无。
## 输出: 无。
func _bind_actions() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_file_pick_btn.pressed.connect(_on_file_pick_pressed)
	_file_path_input.text_changed.connect(_on_file_path_changed)


## 实例化三个步骤子组件，挂到步骤容器上并连接各自信号，初始全部隐藏。## 输入: 无。
## 输出: 无。
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

## 切换当前步骤：更新步骤标签、隐藏全部子组件后只显示目标组件，并决定返回按钮是否可见。## 输入: step (int) - 目标步骤，1=选类型、2=字段映射、3=导入进度。
## 输出: 无。
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


## 把步骤子控件的布局模式设为锚点，使其四边贴合父容器铺满。## 输入: ctrl (Control) - 待铺满的步骤子控件。
## 输出: 无。
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

## 清空牌组下拉框并按数据库中的未归档牌组重新填充，条目元数据存放牌组 ID。## 输入: 无。
## 输出: 无。
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


## 在牌组下拉框中按 ID 选中对应条目。## 输入: deck_id (int) - 要选中的牌组 ID。
## 输出: 无。匹配不到或下拉框为空时不做任何事。
func select_deck_by_id(deck_id: int) -> void:
	if _deck_select == null: return
	for i in range(_deck_select.item_count):
		var meta: Variant = _deck_select.get_item_metadata(i)
		if typeof(meta) == TYPE_INT and int(meta) == deck_id:
			_deck_select.select(i)
			return


# ── 文件选择 ──

## 响应文件路径输入框文本变化，去掉首尾空白后记录为待导入文件路径。## 输入: new_text (String) - 输入框的当前文本。
## 输出: 无。
func _on_file_path_changed(new_text: String) -> void:
	_json_file_path = new_text.strip_edges()


## 响应「选择文件」按钮：弹出只筛选 *.json 的系统文件对话框。## 输入: 无。
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


## 文件对话框选中回调：记录路径、回填输入框并释放临时对话框。## 输入: path (String) - 用户选中的文件路径。
## 输出: 无。
func _on_file_selected(path: String) -> void:
	_json_file_path = path
	if _file_path_input: _file_path_input.text = path
	for child in get_children():
		if child is FileDialog and child.name == "TempFileDialog":
			child.queue_free()
			break


## 判断给定路径是否非空且文件真实存在。## 输入: path (String) - 待校验的文件路径。
## 输出: bool - 路径非空且文件存在时返回 true。
func _is_file_valid(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)


# ── Step 1 → Step 2 ──

## 响应笔记类型选择：校验类型、JSON 文件与解析结果，通过后加载字段映射并进入 Step 2。## 输入:
##   note_type_id (String) - 选中的笔记类型 ID。
##   note_type (Dictionary) - 选中的笔记类型数据（本函数未直接使用）。
## 输出: 无。任一步校验失败时弹出错误并停留在 Step 1。
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


## 笔记类型选择被取消时的回调：释放本界面节点。## 输入: 无。
## 输出: 无。
func _on_selector_cancelled() -> void:
	queue_free()


## 响应顶栏返回按钮：回到 Step 1 的笔记类型选择。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	match _current_step:
		2: _show_step(1)
		_: _show_step(1)


# ── Step 2 → Step 3 ──

## 字段映射确认回调：校验目标牌组后进入 Step 3，调用导入管理器执行导入，失败时延迟通知进度对话框。## 输入: mapping (Dictionary) - 用户确认的字段映射表。
## 输出: 无。未选择牌组时弹出错误并留在 Step 2。
func _on_mapping_confirmed(mapping: Dictionary) -> void:
	var deck_idx: int = _deck_select.selected
	if deck_idx < 0:
		_show_error("请先选择目标牌组")
		return
	var deck_id_int: int = _deck_select.get_item_metadata(deck_idx)
	var deck_id: String = str(deck_id_int)

	_progress_dialog.setup(_import_manager)
	_show_step(3)

	_writing = true
	var result: Dictionary = _import_manager.import_from_file(
		_json_file_path, deck_id, _selected_note_type_id, mapping
	)
	_writing = false
	if not result.get("success", false):
		var raw_data = result.get("data", {})
		var data: Dictionary = raw_data if raw_data is Dictionary else {}
		call_deferred("_deferred_notify_failure", {
			"error": result.get("error", "导入失败"),
			"data": data
		})


## 延迟一帧把导入失败信息交给进度对话框展示。## 输入: error (Dictionary) - 含 error 文本与 data 明细的错误信息。
## 输出: 无。
func _deferred_notify_failure(error: Dictionary) -> void:
	if _progress_dialog != null:
		_progress_dialog._on_import_failed(error)


## 字段映射界面请求返回时的回调：回到 Step 1。## 输入: 无。
## 输出: 无。
func _on_mapping_back() -> void:
	_show_step(1)


# ── Step 3 完成 ──

## 导入完成回调：释放本界面节点，返回上一层。## 输入: 无。
## 输出: 无。
func _on_import_finished() -> void:
	queue_free()


# ── JSON 解析 ──

## 解析 JSON 文件，缓存数据行并汇总所有行出现过的顶层字段名（按小写去重）。## 输入: path (String) - 待解析的 JSON 文件路径。
## 输出: bool - 解析成功且数据非空返回 true；文件缺失、打不开、解析失败、顶层类型不符或数据为空时弹错误并返回 false。
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


## 弹出标题为「错误」的临时模态提示框，关闭后自动释放。## 输入: message (String) - 要显示的错误文本。
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


## 查询导入事务是否正在执行。## 输入: 无。输出: bool。
func is_importing() -> bool:
	return _writing
