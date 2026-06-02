extends Control


var _deck_manager: DeckManager = null
var _note_manager: NoteManager = null
var _fields_rows: Array = []

@onready var _deck_name_input: LineEdit = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckNameInput
@onready var _deck_target_id_input: SpinBox = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckTargetIdInput
@onready var _deck_parent_option: OptionButton = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckParentOption
@onready var _deck_parent_custom_spin: SpinBox = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckParentCustomSpin
@onready var _deck_sort_order_input: SpinBox = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckSortOrderInput
@onready var _deck_archived_check: CheckBox = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckArchivedCheck
@onready var _deck_list_view: ItemList = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckListView
@onready var _note_id_input: SpinBox = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/NoteIdInput
@onready var _note_deck_id_input: SpinBox = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/NoteTypeInput
@onready var _fields_editor: VBoxContainer = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/FieldsEditorWrapper/FieldsEditor
@onready var _add_field_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/FieldsEditorWrapper/AddFieldButton
@onready var _note_list_view: ItemList = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NoteListView
@onready var _log_output: TextEdit = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogOutput

@onready var _create_deck_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/CreateDeckButton
@onready var _read_deck_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/ReadDeckButton
@onready var _update_deck_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/UpdateDeckButton
@onready var _delete_deck_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/DeleteDeckButton
@onready var _list_deck_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/ListDeckButton
@onready var _create_note_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/CreateNoteButton
@onready var _read_note_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/ReadNoteButton
@onready var _update_note_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/UpdateNoteButton
@onready var _delete_note_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/DeleteNoteButton
@onready var _list_note_button: Button = $RootMargin/MainVBox/MainHSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/ListNoteButton
@onready var _clear_all_button: Button = $RootMargin/MainVBox/Toolbar/ClearAllDataButton
@onready var _refresh_all_button: Button = $RootMargin/MainVBox/Toolbar/RefreshAllButton
@onready var _copy_log_button: Button = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogToolbar/CopyLogButton
@onready var _clear_log_button: Button = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogToolbar/ClearLogButton
@onready var _export_log_button: Button = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogToolbar/ExportLogButton
@onready var _clear_data_confirm: ConfirmationDialog = $ClearDataConfirm


## 初始化调试场景，建立数据库连接、设定默认值、绑定事件。
func _ready() -> void:
	_setup_default_inputs()
	_setup_parent_option()
	_bind_actions()
	var init_ok: bool = _ensure_database_ready()
	if init_ok:
		_refresh_deck_list()
		_refresh_note_list()


## 退出场景时释放管理器节点（Manager 内部自行管理 DB 子节点）。
func _exit_tree() -> void:
	_clear_fields_editor()
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null
	if _note_manager != null:
		_note_manager.queue_free()
		_note_manager = null


## 设定初始输入值与 fields 默认行。
func _setup_default_inputs() -> void:
	_deck_name_input.text = "Debug Deck"
	_deck_target_id_input.value = 1
	_deck_sort_order_input.value = 0
	_deck_archived_check.button_pressed = false
	_note_id_input.value = 1
	_note_deck_id_input.value = 1
	_log_output.text = ""
	_add_field_row("front", "demo front")
	_add_field_row("back", "demo back")


## 填充 Parent 下拉选项：Root(0) + Custom。
func _setup_parent_option() -> void:
	_deck_parent_option.add_item("Root (parent_id=0)", 0)
	_deck_parent_option.add_item("Custom...", -1)
	_deck_parent_option.item_selected.connect(_on_parent_option_changed)


## 绑定全部按钮与列表事件。
func _bind_actions() -> void:
	_create_deck_button.pressed.connect(_on_create_deck_pressed)
	_read_deck_button.pressed.connect(_on_read_deck_pressed)
	_update_deck_button.pressed.connect(_on_update_deck_pressed)
	_delete_deck_button.pressed.connect(_on_delete_deck_pressed)
	_list_deck_button.pressed.connect(_on_list_decks_pressed)
	_deck_list_view.item_activated.connect(_on_deck_item_double_clicked)
	_create_note_button.pressed.connect(_on_create_note_pressed)
	_read_note_button.pressed.connect(_on_read_note_pressed)
	_update_note_button.pressed.connect(_on_update_note_pressed)
	_delete_note_button.pressed.connect(_on_delete_note_pressed)
	_list_note_button.pressed.connect(_on_list_notes_pressed)
	_note_list_view.item_activated.connect(_on_note_item_double_clicked)
	_add_field_button.pressed.connect(_on_add_field_pressed)
	_clear_all_button.pressed.connect(_on_clear_all_pressed)
	_refresh_all_button.pressed.connect(_on_refresh_all_pressed)
	_copy_log_button.pressed.connect(_on_copy_log_pressed)
	_clear_log_button.pressed.connect(_on_clear_log_pressed)
	_export_log_button.pressed.connect(_on_export_log_pressed)
	_clear_data_confirm.confirmed.connect(_on_clear_data_confirmed)


## 当 Parent OptionButton 切换时，显示/隐藏自定义 SpinBox。## 输入: index (int) - 选中项索引。
## 输出: 无。
func _on_parent_option_changed(index: int) -> void:
	_deck_parent_custom_spin.visible = (_deck_parent_option.get_item_id(index) == -1)


## 获取当前选中的 parent_id 值。## 输入: 无。
## 输出: int - Root 返回 0，Custom 返回 SpinBox 值。
func _get_selected_parent_id() -> int:
	var selected_id: int = _deck_parent_option.get_item_id(_deck_parent_option.selected)
	if selected_id == -1:
		return roundi(_deck_parent_custom_spin.value)
	return selected_id


## 创建并初始化 Manager，由 Manager 自行管理 DB 生命周期。## 输入: 无。
## 输出: bool - 初始化成功返回 true。
func _ensure_database_ready() -> bool:
	if _deck_manager != null and _deck_manager.is_ready() and _note_manager != null and _note_manager.is_ready():
		return true
	
	# 清理旧实例
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null
	if _note_manager != null:
		_note_manager.queue_free()
		_note_manager = null
	
	const db_path: String = "user://knowledge_admin.db"
	
	# 创建 DeckManager（内部自行创建 DeckDB）
	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	if not _deck_manager.setup(db_path):
		_append_log("DeckManager 初始化失败")
		return false
	
	# 创建 NoteManager（内部自行创建 NoteDB + CardDB + DeckDB）
	_note_manager = NoteManager.new()
	add_child(_note_manager)
	if not _note_manager.setup(db_path):
		_append_log("NoteManager 初始化失败")
		return false
	
	_append_log("Manager 层就绪: " + db_path)
	return true


# ──────────────────────────────────────────────────────────────
# Deck CRUD
# ──────────────────────────────────────────────────────────────


## 创建牌组，打印完整返回行并自动回填 Target ID。
func _on_create_deck_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_name: String = _deck_name_input.text.strip_edges()
	var parent_id: int = _get_selected_parent_id()
	var sort_order: int = roundi(_deck_sort_order_input.value)
	_log_operation_header("create_deck", "name=%s parent_id=%d sort_order=%d" % [deck_name, parent_id, sort_order])
	var result: Dictionary = _deck_manager.create_deck(deck_name, parent_id)
	_log_result(result)
	if result.get("success", false):
		var deck: DeckEntity = result.get("data", null)
		if deck != null:
			_log_data(_stringify_deck(deck))
			_deck_target_id_input.value = deck.id
	_refresh_deck_list()


## 按 Target ID 查询牌组，打印完整行并回填表单。
func _on_read_deck_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_id: int = roundi(_deck_target_id_input.value)
	_log_operation_header("read_deck", "id=%d" % deck_id)
	var result: Dictionary = _deck_manager.get_deck(deck_id)
	_log_result(result)
	if result.get("success", false):
		var deck: DeckEntity = result.get("data", null)
		if deck != null:
			_log_data(_stringify_deck(deck))
			_populate_deck_form(deck)
		else:
			_append_log("  data: null (not found)")
			_append_log("")
	else:
		_append_log("")


## 按 Target ID 更新牌组（name + is_archived），打印改前/改后完整行。
func _on_update_deck_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_id: int = roundi(_deck_target_id_input.value)
	var deck_name: String = _deck_name_input.text.strip_edges()
	var is_archived: bool = _deck_archived_check.button_pressed
	_log_operation_header("update_deck", "id=%d name=%s is_archived=%s" % [deck_id, deck_name, str(is_archived)])
	var get_result: Dictionary = _deck_manager.get_deck(deck_id)
	if not get_result.get("success", false):
		_log_result(get_result)
		_append_log("")
		return
	var deck: DeckEntity = get_result.get("data", null)
	if deck == null:
		_append_log("  更新失败: 牌组 id=%d 不存在" % deck_id)
		_append_log("")
		return
	var before_str: String = _stringify_deck(deck)
	
	var update_result: Dictionary
	if deck.name != deck_name:
		update_result = _deck_manager.rename_deck(deck_id, deck_name)
	else:
		update_result = {"success": true}
	
	if update_result.get("success", false) and deck.is_archived != is_archived:
		update_result = _deck_manager.archive_deck(deck_id, is_archived)
	
	_log_result(update_result)
	_append_log("  BEFORE: %s" % before_str)
	if update_result.get("success", false):
		var after_result: Dictionary = _deck_manager.get_deck(deck_id)
		if after_result.get("success", false) and after_result.get("data", null) != null:
			var after_deck: DeckEntity = after_result.get("data")
			_append_log("  AFTER:  %s" % _stringify_deck(after_deck))
	_append_log("")
	_refresh_deck_list()


## 删除指定牌组，打印删除前快照与受影响行数。
func _on_delete_deck_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_id: int = roundi(_deck_target_id_input.value)
	_log_operation_header("delete_deck", "id=%d" % deck_id)
	var get_result: Dictionary = _deck_manager.get_deck(deck_id)
	if get_result.get("success", false) and get_result.get("data", null) != null:
		var deck: DeckEntity = get_result.get("data")
		_append_log("  BEFORE: %s" % _stringify_deck(deck))
	var result: Dictionary = _deck_manager.delete_deck(deck_id)
	_log_result(result)
	_append_log("")
	_refresh_deck_list()


## 列出全部牌组，日志打印完整表格。
func _on_list_decks_pressed() -> void:
	if not _ensure_database_ready():
		return
	_refresh_deck_list()


## 双击牌组列表行→回填表单。## 输入: index (int) - 被双击的列表项索引。
## 输出: 无。
func _on_deck_item_double_clicked(index: int) -> void:
	var deck_id: int = _get_deck_id_from_list_item(_deck_list_view.get_item_text(index))
	if deck_id <= 0:
		return
	if not _ensure_database_ready():
		return
	var result: Dictionary = _deck_manager.get_deck(deck_id)
	if result.get("success", false) and result.get("data", null) != null:
		_populate_deck_form(result.get("data"))


## 从列表行文本中提取牌组 id。## 输入: line (String) - 列表行文本，格式 "id=X | ..."。
## 输出: int - 提取到的 id，失败返回 0。
func _get_deck_id_from_list_item(line: String) -> int:
	var prefix := "id="
	var start_idx := line.find(prefix)
	if start_idx == -1:
		return 0
	var end_idx := line.find("|", start_idx)
	if end_idx == -1:
		end_idx = line.length()
	var id_str := line.substr(start_idx + prefix.length(), end_idx - start_idx - prefix.length())
	return id_str.strip_edges().to_int()


## 把牌组实体回填到表单。## 输入: deck (DeckEntity) - 牌组实体。
## 输出: 无。
func _populate_deck_form(deck: DeckEntity) -> void:
	_deck_name_input.text = deck.name
	_deck_target_id_input.value = deck.id
	_deck_sort_order_input.value = deck.sort_order
	_deck_archived_check.button_pressed = deck.is_archived
	if deck.parent_id <= 0:
		_deck_parent_option.select(0)
		_deck_parent_custom_spin.visible = false
	else:
		_deck_parent_option.select(1)
		_deck_parent_custom_spin.value = deck.parent_id
		_deck_parent_custom_spin.visible = true


## 刷新牌组 ItemList 并输出完整表格日志。
func _refresh_deck_list() -> void:
	if _deck_manager == null:
		return
	_deck_list_view.clear()
	var result: Dictionary = _deck_manager.get_all_decks()
	if not result.get("success", false):
		_append_log("刷新牌组列表失败 -> %s" % _format_result(result))
		_append_log("")
		return
	var decks: Array[DeckEntity] = result.get("data", [])
	_log_operation_header("list_decks", "%d rows" % decks.size())
	_append_log("  id | name                 | parent_id | sort | archived | created_at    | updated_at")
	_append_log("  ---+----------------------+-----------+------+----------+---------------+------------")
	for deck in decks:
		var parent_text: String = "NULL"
		if deck.parent_id > 0:
			parent_text = str(deck.parent_id)
		var line: String = "  %-3d| %-21s| %-10s| %-5d| %-9s| %-14d| %-12d" % [
			deck.id,
			truncate_string(deck.name, 20),
			parent_text,
			deck.sort_order,
			"true" if deck.is_archived else "false",
			deck.created_at,
			deck.updated_at
		]
		_append_log(line)
		var item_line: String = "id=%d | name=%s | parent=%s | archived=%s" % [deck.id, deck.name, parent_text, str(deck.is_archived)]
		_deck_list_view.add_item(item_line)
	_append_log("")


# ──────────────────────────────────────────────────────────────
# Notes CRUD
# ──────────────────────────────────────────────────────────────


## 创建 notes 记录，打印 full_row 并自动回填 ID。
func _on_create_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	const FALLBACK_NOTE_TYPE_ID: int = 1
	var fields_dict: Dictionary = _fields_to_dict()
	if fields_dict.is_empty():
		_append_log("创建 note 失败: fields 至少需要一个字段")
		_append_log("")
		return
	var fields_json: String = JSON.stringify(fields_dict)

	# 获取目标牌组 ID，牌组不存在时自动回退到第一个可用牌组
	var deck_id: int = roundi(_note_deck_id_input.value)
	var requested_id: int = deck_id
	var deck_result := _deck_manager.get_deck(deck_id)
	if not deck_result.get("success", false) or deck_result.get("data", null) == null:
		var all_decks := _deck_manager.get_all_decks()
		if all_decks.get("success", false):
			var decks: Array = all_decks.get("data", [])
			if not decks.is_empty():
				var first_deck: DeckEntity = decks[0]
				deck_id = first_deck.id
				_note_deck_id_input.value = deck_id
				if requested_id != deck_id:
					_append_log("  info: 牌组 id=%d 不存在，自动使用第一个可用牌组 id=%d (%s)" % [requested_id, deck_id, first_deck.name])
			else:
				_append_log("创建 note 失败: 没有任何可用牌组，请先创建牌组")
				_append_log("")
				return
		else:
			_append_log("创建 note 失败: 无法查询牌组列表")
			_append_log("")
			return

	_log_operation_header("create_note", "deck_id=%d note_type_id=%d fields=%s" % [deck_id, FALLBACK_NOTE_TYPE_ID, fields_json])

	var result: Dictionary = _note_manager.create_note(FALLBACK_NOTE_TYPE_ID, fields_dict, deck_id, [])
	_log_result(result)
	if result.get("success", false):
		var data: Dictionary = result.get("data", {})
		var note: NoteEntity = data.get("note", null)
		if note != null:
			_note_id_input.value = note.id
			_append_log("  full_row: %s" % _stringify_note_entity(note))
	_append_log("")
	_refresh_note_list()


## 按 Note ID 读取记录，打印完整行并拆分 fields。
func _on_read_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var note_id: int = roundi(_note_id_input.value)
	_log_operation_header("read_note", "id=%d" % note_id)
	var result: Dictionary = _note_manager.get_note(note_id)
	_log_result(result)
	var note: NoteEntity = result.get("data", null)
	if note != null:
		_append_log("  full_row: %s" % _stringify_note_entity(note))
		_populate_note_form_from_entity(note)
	else:
		_append_log("  data: null (not found)")
	_append_log("")


## 更新 notes 记录，打印 BEFORE + AFTER。
func _on_update_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var note_id: int = roundi(_note_id_input.value)
	var fields_dict: Dictionary = _fields_to_dict()
	if fields_dict.is_empty():
		_append_log("更新 note 失败: fields 至少需要一个字段")
		_append_log("")
		return
	var fields_json: String = JSON.stringify(fields_dict)
	_log_operation_header("update_note", "id=%d fields=%s" % [note_id, fields_json])
	
	var before_result: Dictionary = _note_manager.get_note(note_id)
	if before_result.get("success", false) and before_result.get("data", null) != null:
		_append_log("  BEFORE: %s" % _stringify_note_entity(before_result.get("data")))
	
	var update_result: Dictionary = _note_manager.update_note(note_id, fields_dict, [])
	_log_result(update_result)
	if update_result.get("success", false):
		var after_result: Dictionary = _note_manager.get_note(note_id)
		if after_result.get("success", false) and after_result.get("data", null) != null:
			_append_log("  AFTER:  %s" % _stringify_note_entity(after_result.get("data")))
	_append_log("")
	_refresh_note_list()


## 删除 notes 记录，打印删除前快照与受影响行数。
func _on_delete_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var note_id: int = roundi(_note_id_input.value)
	_log_operation_header("delete_note", "id=%d" % note_id)
	var before_result: Dictionary = _note_manager.get_note(note_id)
	if before_result.get("success", false) and before_result.get("data", null) != null:
		_append_log("  BEFORE: %s" % _stringify_note_entity(before_result.get("data")))
	var result: Dictionary = _note_manager.delete_note(note_id)
	_log_result(result)
	_append_log("")
	_refresh_note_list()


## 列出最近 notes，日志打印完整表格。
func _on_list_notes_pressed() -> void:
	if not _ensure_database_ready():
		return
	_refresh_note_list()


## 双击 notes 列表行→回填表单。## 输入: index (int) - 被双击的列表项索引。
## 输出: 无。
func _on_note_item_double_clicked(index: int) -> void:
	var line: String = _note_list_view.get_item_text(index)
	var prefix := "id="
	var start_idx := line.find(prefix)
	if start_idx == -1:
		return
	var end_idx := line.find("|", start_idx)
	if end_idx == -1:
		end_idx = line.length()
	var note_id: int = line.substr(start_idx + prefix.length(), end_idx - start_idx - prefix.length()).strip_edges().to_int()
	if note_id <= 0:
		return
	if not _ensure_database_ready():
		return
	var result: Dictionary = _note_manager.get_note(note_id)
	if result.get("success", false) and result.get("data", null) != null:
		_populate_note_form_from_entity(result.get("data"))


## 把 NoteEntity 数据回填到表单与 fields 编辑器（不覆盖 Deck ID 输入框，保持用户上次选择）。## 输入: note (NoteEntity) - 笔记实体。
## 输出: 无。
func _populate_note_form_from_entity(note: NoteEntity) -> void:
	_note_id_input.value = note.id
	_json_to_fields(JSON.stringify(note.fields_data))


## 刷新 notes ItemList 并输出完整表格日志。
func _refresh_note_list() -> void:
	if _note_manager == null:
		return
	_note_list_view.clear()
	var result: Dictionary = _note_manager.get_all_notes()
	if not result.get("success", false):
		_append_log("刷新 notes 列表失败 -> %s" % _format_result(result))
		_append_log("")
		return
	var notes: Array[NoteEntity] = result.get("data", [])
	_log_operation_header("list_notes", "%d rows" % notes.size())
	_append_log("  id | note_type_id | fields_json                              | created_at")
	_append_log("  ---+--------------+------------------------------------------+------------")
	for note in notes:
		var fields_json: String = JSON.stringify(note.fields_data)
		_append_log("  %-3d| %-13d| %-41s| %-10d" % [
			note.id,
			note.note_type_id,
			truncate_string(fields_json, 40),
			note.created_at
		])
		var item_line: String = "id=%d | type=%d | fields=%s" % [note.id, note.note_type_id, truncate_string(fields_json, 60)]
		_note_list_view.add_item(item_line)
	_append_log("")


## 把 NoteEntity 渲染为完整可读字符串（含字段展开）。## 输入: note (NoteEntity) - 笔记实体。
## 输出: String - 格式化的完整行字符串。
func _stringify_note_entity(note: NoteEntity) -> String:
	var base := "id=%d note_type_id=%d created_at=%d" % [note.id, note.note_type_id, note.created_at]
	var fields_str: String = JSON.stringify(note.fields_data)
	var parser := JSON.new()
	if parser.parse(fields_str) == OK and typeof(parser.data) == TYPE_DICTIONARY:
		var d: Dictionary = parser.data
		for key in d:
			base += "  %s=%s" % [str(key), str(d[key])]
		return base
	base += "  raw_fields=%s" % fields_str
	return base


# ──────────────────────────────────────────────────────────────
# Fields Editor
# ──────────────────────────────────────────────────────────────


## 向 fields 编辑器添加一行键值输入。## 输入: key (String) - 字段键名默认值；value (String) - 字段值默认值。
## 输出: 无。
func _add_field_row(key: String = "", value: String = "") -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_edit := LineEdit.new()
	key_edit.size_flags_horizontal = 3
	key_edit.placeholder_text = "key"
	if key != "":
		key_edit.text = key

	var value_edit := LineEdit.new()
	value_edit.size_flags_horizontal = 3
	value_edit.placeholder_text = "value"
	if value != "":
		value_edit.text = value

	var remove_btn := Button.new()
	remove_btn.text = "x"
	remove_btn.custom_minimum_size = Vector2(30, 0)
	remove_btn.pressed.connect(_on_remove_field_pressed.bind(hbox))

	hbox.add_child(key_edit)
	hbox.add_child(value_edit)
	hbox.add_child(remove_btn)

	_fields_editor.add_child(hbox)
	_fields_rows.append({"container": hbox, "key_edit": key_edit, "value_edit": value_edit})


## + Add Field 按钮回调。
func _on_add_field_pressed() -> void:
	_add_field_row()


## 删除指定 fields 行。## 输入: hbox (HBoxContainer) - 待删除的行容器。
## 输出: 无。
func _on_remove_field_pressed(hbox: HBoxContainer) -> void:
	for i in range(_fields_rows.size()):
		if _fields_rows[i].get("container") == hbox:
			_fields_rows.remove_at(i)
			break
	hbox.queue_free()


## 清空 fields 编辑器所有行。
func _clear_fields_editor() -> void:
	for row in _fields_rows:
		var hbox: HBoxContainer = row.get("container", null)
		if hbox != null:
			hbox.queue_free()
	_fields_rows.clear()


## 把当前 fields 行序列化为 Dictionary。## 输入: 无。
## 输出: Dictionary - 键值对字典，忽略空 key 的行。
func _fields_to_dict() -> Dictionary:
	var d := {}
	for row in _fields_rows:
		var key: String = (row["key_edit"] as LineEdit).text.strip_edges()
		var val: String = (row["value_edit"] as LineEdit).text.strip_edges()
		if key == "":
			continue
		d[key] = val
	return d


## 将 JSON 字符串解析后回填到 fields 编辑器。## 输入: json_str (String) - fields_data 的 JSON 字符串。
## 输出: 无。
func _json_to_fields(json_str: String) -> void:
	_clear_fields_editor()
	var parser := JSON.new()
	if parser.parse(json_str) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		_add_field_row("raw", json_str)
		return
	var d: Dictionary = parser.data
	if d.is_empty():
		return
	for key in d:
		_add_field_row(str(key), str(d[key]))


# ──────────────────────────────────────────────────────────────
# Clear All Data
# ──────────────────────────────────────────────────────────────


## 打开确认对话框。
func _on_clear_all_pressed() -> void:
	_clear_data_confirm.popup_centered()


## 事务内清空 cards/notes/decks 三表数据（保留表结构），打印每表行数。
func _on_clear_data_confirmed() -> void:
	if not _ensure_database_ready():
		return
	var start_time: int = Time.get_ticks_msec()
	_log_operation_header("clear_all_data", "truncate cards, notes, decks (schema preserved)")
	
	var result: Dictionary = _deck_manager.clear_all_data()
	if result.get("success", false):
		var stats: Dictionary = result.get("data", {})
		_append_log("  DELETE FROM cards    → %d rows" % stats.get("cards", 0))
		_append_log("  DELETE FROM notes    → %d rows" % stats.get("notes", 0))
		_append_log("  DELETE FROM decks    → %d rows" % stats.get("decks", 0))
		var elapsed: int = Time.get_ticks_msec() - start_time
		_append_log("  OK - committed in %d ms" % elapsed)
	else:
		_append_log("  FAIL: %s" % _format_result(result))
	_append_log("")
	_setup_default_inputs()
	_clear_fields_editor()
	_refresh_deck_list()
	_refresh_note_list()


# ──────────────────────────────────────────────────────────────
# Log Utilities
# ──────────────────────────────────────────────────────────────


## 打印操作标题头。## 输入: op (String) - 操作名称；input_info (String) - 输入参数描述。
## 输出: 无。
func _log_operation_header(op: String, input_info: String) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	_log_output.text += "[%s] === %s ===\n" % [timestamp, op]
	_log_output.text += "  input: %s\n" % input_info
	_scroll_to_bottom()


## 打印标准返回字典结果。## 输入: result (Dictionary) - 标准返回字典。
## 输出: 无。
func _log_result(result: Dictionary) -> void:
	if result.get("success", false):
		_log_output.text += "  result: OK\n"
	else:
		var code: String = str(result.get("code", "UNKNOWN"))
		var error_msg: String = str(result.get("error", "未知错误"))
		_log_output.text += "  result: FAIL code=%s error=%s\n" % [code, error_msg]
	_scroll_to_bottom()


## 打印数据内容块（支持多行）。## 输入: data_str (String) - 数据字符串，可包含换行。
## 输出: 无。
func _log_data(data_str: String) -> void:
	for line in data_str.split("\n"):
		_log_output.text += "  %s\n" % line.strip_edges(true, false)
	_scroll_to_bottom()


## 向底部日志面板追加一行文本。## 输入: message (String) - 待写入日志。
## 输出: 无。
func _append_log(message: String) -> void:
	_log_output.text += message + "\n"
	_scroll_to_bottom()


## 滚动日志到底部。
func _scroll_to_bottom() -> void:
	_log_output.set_caret_line(_log_output.get_line_count())


## 复制全部日志到剪贴板。
func _on_copy_log_pressed() -> void:
	DisplayServer.clipboard_set(_log_output.text)
	_append_log("[日志已复制到剪贴板]")


## 清空日志面板。
func _on_clear_log_pressed() -> void:
	_log_output.text = ""


## 导出日志到 user://logs/database/ 目录。
func _on_export_log_pressed() -> void:
	var log_dir := "user://logs/database"
	var dir := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_dir))
	if dir != OK:
		_append_log("导出失败: 无法创建目录 %s (error=%d)" % [log_dir, dir])
		_append_log("")
		return
	var now := Time.get_datetime_dict_from_system()
	var filename := "crud_log_%04d%02d%02d_%02d%02d%02d.txt" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]
	var file_path := log_dir.path_join(filename)
	var fa := FileAccess.open(file_path, FileAccess.WRITE)
	if fa == null:
		_append_log("导出失败: 无法写入文件 %s" % file_path)
		_append_log("")
		return
	fa.store_string(_log_output.text)
	fa.close()
	_append_log("日志已导出到 %s (%d bytes)" % [file_path, _log_output.text.length()])
	_append_log("")


## 一键刷新牌组与 notes 列表。
func _on_refresh_all_pressed() -> void:
	if not _ensure_database_ready():
		return
	_refresh_deck_list()
	_refresh_note_list()


# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────


## 把 DeckEntity 渲染为单行完整字符串。## 输入: deck (DeckEntity) - 牌组实体。
## 输出: String - 包含所有列的格式化字符串。
func _stringify_deck(deck: DeckEntity) -> String:
	var parent_text: String = "NULL"
	if deck.parent_id > 0:
		parent_text = str(deck.parent_id)
	return "id=%s name=\"%s\" parent_id=%s sort_order=%d is_archived=%s created_at=%d updated_at=%d" % [
		str(deck.id),
		deck.name,
		parent_text,
		deck.sort_order,
		"true" if deck.is_archived else "false",
		deck.created_at,
		deck.updated_at
	]


## 把标准结果字典格式化为可读字符串。## 输入: result (Dictionary) - 标准返回字典。
## 输出: String - 简短日志文本。
func _format_result(result: Dictionary) -> String:
	if result.get("success", false):
		return "OK"
	var code: String = str(result.get("code", "UNKNOWN"))
	var error_message: String = str(result.get("error", "未知错误"))
	return "FAIL code=%s error=%s" % [code, error_message]


## 截断字符串到指定长度。## 输入: s (String) - 原始字符串；max_len (int) - 最大长度。
## 输出: String - 截断后字符串，超出部分用 … 替代。
static func truncate_string(s: String, max_len: int) -> String:
	if s.length() <= max_len:
		return s
	return s.left(max_len - 1) + "…"
