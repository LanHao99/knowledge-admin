extends Control


var _deck_db: DeckDB = null

@onready var _deck_name_input: LineEdit = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckNameInput
@onready var _deck_parent_id_input: SpinBox = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckParentIdInput
@onready var _deck_id_input: SpinBox = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckIdInput
@onready var _deck_rename_input: LineEdit = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckRenameInput
@onready var _deck_list_view: ItemList = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckListView
@onready var _note_id_input: SpinBox = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbForm/NoteIdInput
@onready var _note_type_input: SpinBox = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbForm/NoteTypeInput
@onready var _note_fields_input: TextEdit = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbForm/NoteFieldsInput
@onready var _note_list_view: ItemList = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/NoteListView
@onready var _log_output: TextEdit = $RootMargin/MainVBox/LogOutput

@onready var _create_deck_button: Button = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckButtons/CreateDeckButton
@onready var _get_deck_button: Button = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckButtons/GetDeckButton
@onready var _list_decks_button: Button = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckButtons/ListDeckButton
@onready var _rename_deck_button: Button = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckButtons/RenameDeckButton
@onready var _delete_deck_button: Button = $RootMargin/MainVBox/ContentHBox/DeckPanel/DeckVBox/DeckButtons/DeleteDeckButton
@onready var _create_note_button: Button = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbButtons/CreateNoteButton
@onready var _read_note_button: Button = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbButtons/ReadNoteButton
@onready var _update_note_button: Button = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbButtons/UpdateNoteButton
@onready var _delete_note_button: Button = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbButtons/DeleteNoteButton
@onready var _list_notes_button: Button = $RootMargin/MainVBox/ContentHBox/DbPanel/DbVBox/DbButtons/ListNoteButton
@onready var _refresh_all_button: Button = $RootMargin/MainVBox/Toolbar/RefreshAllButton


## 初始化调试场景，建立数据库连接并绑定按钮事件。
##
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_default_inputs()
	_bind_actions()
	var init_ok: bool = _ensure_database_ready()
	if init_ok:
		_refresh_deck_list()
		_refresh_note_list()


## 设定初始输入值，减少重复手动输入。
##
## 输入: 无。
## 输出: 无。
func _setup_default_inputs() -> void:
	_deck_name_input.text = "Debug Deck"
	_deck_parent_id_input.value = 0
	_deck_id_input.value = 1
	_deck_rename_input.text = "Debug Deck Renamed"
	_note_id_input.value = 1
	_note_type_input.value = 1
	_note_fields_input.text = "{\"front\":\"demo front\",\"back\":\"demo back\"}"
	_log_output.text = ""


## 绑定全部调试按钮事件。
##
## 输入: 无。
## 输出: 无。
func _bind_actions() -> void:
	_create_deck_button.pressed.connect(_on_create_deck_pressed)
	_get_deck_button.pressed.connect(_on_get_deck_pressed)
	_list_decks_button.pressed.connect(_on_list_decks_pressed)
	_rename_deck_button.pressed.connect(_on_rename_deck_pressed)
	_delete_deck_button.pressed.connect(_on_delete_deck_pressed)
	_create_note_button.pressed.connect(_on_create_note_pressed)
	_read_note_button.pressed.connect(_on_read_note_pressed)
	_update_note_button.pressed.connect(_on_update_note_pressed)
	_delete_note_button.pressed.connect(_on_delete_note_pressed)
	_list_notes_button.pressed.connect(_on_list_notes_pressed)
	_refresh_all_button.pressed.connect(_on_refresh_all_pressed)


## 创建并初始化 DeckDB，作为本场景数据库调试入口。
##
## 输入: 无。
## 输出: 数据库是否成功就绪。
func _ensure_database_ready() -> bool:
	if _deck_db != null and _deck_db.is_open():
		return true
	if _deck_db != null:
		_deck_db.queue_free()
		_deck_db = null

	_deck_db = DeckDB.new()
	add_child(_deck_db)
	_deck_db.configure("user://knowledge_admin.db")

	if not _deck_db.open():
		_append_log("数据库打开失败: %s" % _deck_db.get_last_error())
		return false

	var init_result: Dictionary = _deck_db.init_schema()
	if not init_result.get("success", false):
		_append_log("Schema 初始化失败: %s" % _format_result(init_result))
		return false

	_append_log("数据库就绪: user://knowledge_admin.db")
	return true


## 退出场景时释放数据库节点。
##
## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if _deck_db != null:
		_deck_db.queue_free()
		_deck_db = null


## 创建牌组并刷新牌组列表。
##
## 输入: 无。
## 输出: 无。
func _on_create_deck_pressed() -> void:
	if not _ensure_database_ready():
		return

	var deck_name: String = _deck_name_input.text.strip_edges()
	var parent_id: int = int(_deck_parent_id_input.value)
	var result: Dictionary = _deck_db.create_deck(deck_name, parent_id)
	_append_log("创建牌组 -> %s" % _format_result(result))
	_refresh_deck_list()


## 按 ID 查询牌组并打印结果。
##
## 输入: 无。
## 输出: 无。
func _on_get_deck_pressed() -> void:
	if not _ensure_database_ready():
		return

	var deck_id: int = int(_deck_id_input.value)
	var result: Dictionary = _deck_db.get_deck_by_id(deck_id)
	_append_log("查询牌组[%d] -> %s" % [deck_id, _format_result(result)])


## 查询全部牌组并刷新可视列表。
##
## 输入: 无。
## 输出: 无。
func _on_list_decks_pressed() -> void:
	if not _ensure_database_ready():
		return
	_refresh_deck_list()


## 重命名指定牌组并刷新牌组列表。
##
## 输入: 无。
## 输出: 无。
func _on_rename_deck_pressed() -> void:
	if not _ensure_database_ready():
		return

	var deck_id: int = int(_deck_id_input.value)
	var get_result: Dictionary = _deck_db.get_deck_by_id(deck_id)
	if not get_result.get("success", false):
		_append_log("重命名前查询失败 -> %s" % _format_result(get_result))
		return

	var deck: DeckEntity = get_result.get("data", null)
	if deck == null:
		_append_log("重命名失败: 牌组不存在")
		return

	deck.name = _deck_rename_input.text.strip_edges()
	var update_result: Dictionary = _deck_db.update_deck(deck)
	_append_log("重命名牌组[%d] -> %s" % [deck_id, _format_result(update_result)])
	_refresh_deck_list()


## 删除指定牌组并刷新牌组列表。
##
## 输入: 无。
## 输出: 无。
func _on_delete_deck_pressed() -> void:
	if not _ensure_database_ready():
		return

	var deck_id: int = int(_deck_id_input.value)
	var result: Dictionary = _deck_db.delete_deck(deck_id)
	_append_log("删除牌组[%d] -> %s" % [deck_id, _format_result(result)])
	_refresh_deck_list()


## 创建 notes 表记录，验证数据库写入流程。
##
## 输入: 无。
## 输出: 无。
func _on_create_note_pressed() -> void:
	if not _ensure_database_ready():
		return

	var note_type_id: int = int(_note_type_input.value)
	var fields_result: Dictionary = _validate_fields_json(_note_fields_input.text)
	if not fields_result.get("success", false):
		_append_log("创建 note 失败: %s" % fields_result.get("error", "JSON 校验失败"))
		return

	var now_ts: int = int(Time.get_unix_time_from_system())
	var create_result: Dictionary = _deck_db.execute_bind(
		"INSERT INTO notes(note_type_id, fields_data, created_at) VALUES(?, ?, ?);",
		[note_type_id, _note_fields_input.text.strip_edges(), now_ts]
	)
	_append_log("创建 note -> %s" % _format_result(create_result))

	if create_result.get("success", false):
		var id_result: Dictionary = _deck_db.last_insert_rowid()
		if id_result.get("success", false):
			_note_id_input.value = int(id_result.get("data", 0))
	_refresh_note_list()


## 按 ID 读取 notes 表记录。
##
## 输入: 无。
## 输出: 无。
func _on_read_note_pressed() -> void:
	if not _ensure_database_ready():
		return

	var note_id: int = int(_note_id_input.value)
	var result: Dictionary = _deck_db.fetch_one("SELECT * FROM notes WHERE id = ? LIMIT 1;", [note_id])
	_append_log("读取 note[%d] -> %s" % [note_id, _format_result(result)])


## 更新指定 notes 记录。
##
## 输入: 无。
## 输出: 无。
func _on_update_note_pressed() -> void:
	if not _ensure_database_ready():
		return

	var fields_result: Dictionary = _validate_fields_json(_note_fields_input.text)
	if not fields_result.get("success", false):
		_append_log("更新 note 失败: %s" % fields_result.get("error", "JSON 校验失败"))
		return

	var note_id: int = int(_note_id_input.value)
	var note_type_id: int = int(_note_type_input.value)
	var result: Dictionary = _deck_db.execute_bind(
		"UPDATE notes SET note_type_id = ?, fields_data = ? WHERE id = ?;",
		[note_type_id, _note_fields_input.text.strip_edges(), note_id]
	)
	_append_log("更新 note[%d] -> %s" % [note_id, _format_result(result)])
	_refresh_note_list()


## 删除指定 notes 记录。
##
## 输入: 无。
## 输出: 无。
func _on_delete_note_pressed() -> void:
	if not _ensure_database_ready():
		return

	var note_id: int = int(_note_id_input.value)
	var result: Dictionary = _deck_db.execute_bind("DELETE FROM notes WHERE id = ?;", [note_id])
	_append_log("删除 note[%d] -> %s" % [note_id, _format_result(result)])
	_refresh_note_list()


## 查询最近 notes 记录并刷新列表。
##
## 输入: 无。
## 输出: 无。
func _on_list_notes_pressed() -> void:
	if not _ensure_database_ready():
		return
	_refresh_note_list()


## 一键刷新牌组与 notes 列表。
##
## 输入: 无。
## 输出: 无。
func _on_refresh_all_pressed() -> void:
	if not _ensure_database_ready():
		return
	_refresh_deck_list()
	_refresh_note_list()


## 读取牌组并渲染到列表控件。
##
## 输入: 无。
## 输出: 无。
func _refresh_deck_list() -> void:
	if _deck_db == null:
		return

	_deck_list_view.clear()
	var result: Dictionary = _deck_db.get_all_decks(true)
	if not result.get("success", false):
		_append_log("刷新牌组列表失败 -> %s" % _format_result(result))
		return

	var decks: Array[DeckEntity] = result.get("data", [])
	for deck in decks:
		var parent_text: String = "root"
		if deck.parent_id > 0:
			parent_text = str(deck.parent_id)
		var line: String = "id=%d | name=%s | parent=%s | archived=%s" % [deck.id, deck.name, parent_text, str(deck.is_archived)]
		_deck_list_view.add_item(line)

	_append_log("牌组列表刷新完成，共 %d 条" % decks.size())


## 读取 notes 表并渲染到列表控件。
##
## 输入: 无。
## 输出: 无。
func _refresh_note_list() -> void:
	if _deck_db == null:
		return

	_note_list_view.clear()
	var result: Dictionary = _deck_db.fetch_all("SELECT id, note_type_id, fields_data, created_at FROM notes ORDER BY id DESC LIMIT 50;")
	if not result.get("success", false):
		_append_log("刷新 notes 列表失败 -> %s" % _format_result(result))
		return

	var rows: Array = result.get("data", [])
	for row in rows:
		if not (row is Dictionary):
			continue
		var line: String = "id=%s | type=%s | fields=%s" % [str(row.get("id", 0)), str(row.get("note_type_id", 0)), str(row.get("fields_data", "{}"))]
		_note_list_view.add_item(line)

	_append_log("notes 列表刷新完成，共 %d 条" % rows.size())


## 校验 fields_data 是否为合法 JSON 对象字符串。
##
## 输入: raw_json (String) - 输入框中的 JSON 文本。
## 输出: 返回标准字典。成功时 `data` 为解析后的 Dictionary。
func _validate_fields_json(raw_json: String) -> Dictionary:
	var text: String = raw_json.strip_edges()
	if text == "":
		return _deck_db.fail("NOTE_FIELDS_EMPTY", "fields_data 不能为空")

	var parser := JSON.new()
	var parse_error: int = parser.parse(text)
	if parse_error != OK:
		return _deck_db.fail("NOTE_FIELDS_JSON_INVALID", "fields_data 不是合法 JSON: %s" % parser.get_error_message())

	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return _deck_db.fail("NOTE_FIELDS_JSON_TYPE_INVALID", "fields_data 必须是 JSON 对象")

	return _deck_db.ok(data)


## 把标准结果字典格式化为可读字符串。
##
## 输入: result (Dictionary) - 标准返回字典。
## 输出: String - 简短日志文本。
func _format_result(result: Dictionary) -> String:
	if result.get("success", false):
		var data: Variant = result.get("data", null)
		if data == null:
			return "OK"
		if typeof(data) == TYPE_ARRAY or typeof(data) == TYPE_DICTIONARY:
			return "OK data=%s" % JSON.stringify(data)
		return "OK data=%s" % str(data)

	var code: String = str(result.get("code", "UNKNOWN"))
	var error_message: String = str(result.get("error", "未知错误"))
	return "FAIL code=%s error=%s" % [code, error_message]


## 向底部日志面板追加一行文本。
##
## 输入: message (String) - 待写入日志。
## 输出: 无。
func _append_log(message: String) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	_log_output.text += "[%s] %s\n" % [timestamp, message]
	_log_output.set_caret_line(_log_output.get_line_count())
