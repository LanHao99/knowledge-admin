extends Control
## 笔记列表界面，按牌组分组展示所有笔记，类似 Windows 文件系统布局。
## 双击笔记项展开可折叠编辑面板，支持新建/编辑/删除笔记。
## 通过监听 NoteManager 信号自动刷新列表。


# ── 数据层 ──
var _note_manager: NoteManager = null
var _deck_manager: DeckManager = null
var _deck_names: Dictionary = {}  # deck_id → deck_name 缓存

# ── 顶部栏 ──
@onready var _back_btn: Button = $RootMargin/MainVBox/TopBar/BackBtn
@onready var _title_label: Label = $RootMargin/MainVBox/TopBar/TitleLabel
@onready var _new_note_btn: Button = $RootMargin/MainVBox/TopBar/NewNoteBtn

# ── 笔记列表 ──
@onready var _note_tree: Tree = $RootMargin/MainVBox/NoteTree

# ── 编辑面板 ──
@onready var _edit_panel: PanelContainer = $RootMargin/MainVBox/EditPanel
@onready var _edit_title: Label = $RootMargin/MainVBox/EditPanel/EditVBox/EditHeader/EditTitle
@onready var _close_edit_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/EditHeader/CloseEditBtn
@onready var _fields_edit: VBoxContainer = $RootMargin/MainVBox/EditPanel/EditVBox/FieldsEdit
@onready var _deck_label: Label = $RootMargin/MainVBox/EditPanel/EditVBox/MetaInfo/DeckLabel
@onready var _created_label: Label = $RootMargin/MainVBox/EditPanel/EditVBox/MetaInfo/CreatedLabel
@onready var _save_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/SaveBtn
@onready var _delete_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/DeleteBtn

# ── 新建对话框 ──
@onready var _new_dialog: ConfirmationDialog = $NewNoteDialog
@onready var _new_deck_select: OptionButton = $NewNoteDialog/DialogVBox/DeckSelect
@onready var _new_front_input: LineEdit = $NewNoteDialog/DialogVBox/FieldsForm/FrontInput
@onready var _new_back_input: LineEdit = $NewNoteDialog/DialogVBox/FieldsForm/BackInput

# ── 底部状态栏 ──
@onready var _status_label: Label = $RootMargin/MainVBox/StatusBar/StatusLabel

# 编辑面板动态生成的字段行
var _editor_rows: Array = []  # [{field_name: String, input: LineEdit}]


## 初始化 Manager、信号、刷新列表。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_edit_panel.visible = false
	_bind_actions()
	var init_ok: bool = _ensure_managers_ready()
	if init_ok:
		_refresh_all()
	else:
		_set_status("数据库初始化失败")


## 退出场景时断开信号并释放 Manager。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	_clear_editor_rows()
	if _note_manager != null:
		_note_manager.entity_created.disconnect(_on_note_changed)
		_note_manager.entity_updated.disconnect(_on_note_changed)
		_note_manager.entity_deleted.disconnect(_on_note_changed)
		_note_manager.queue_free()
		_note_manager = null
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null


## 绑定按钮事件与 Tree 双击信号。## 输入: 无。
## 输出: 无。
func _bind_actions() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_new_note_btn.pressed.connect(_on_new_note_pressed)
	_note_tree.item_activated.connect(_on_item_activated)
	_close_edit_btn.pressed.connect(_on_close_edit_pressed)
	_save_btn.pressed.connect(_on_save_pressed)
	_delete_btn.pressed.connect(_on_delete_pressed)
	_new_dialog.confirmed.connect(_on_new_dialog_confirmed)


# ──────────────────────────────────────────────────────────────
# Manager 初始化
# ──────────────────────────────────────────────────────────────


## 创建并初始化 NoteManager 和 DeckManager（每个场景独立实例）。## 输入: 无。
## 输出: bool - 初始化成功返回 true。
func _ensure_managers_ready() -> bool:
	if _note_manager != null and _note_manager.is_ready() and _deck_manager != null and _deck_manager.is_ready():
		return true

	if _note_manager != null:
		_note_manager.queue_free()
		_note_manager = null
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null

	const db_path: String = "user://knowledge_admin.db"

	_note_manager = NoteManager.new()
	add_child(_note_manager)
	if not _note_manager.setup(db_path):
		push_error("[NoteList] NoteManager 初始化失败")
		return false
	_note_manager.entity_created.connect(_on_note_changed.bind("created"))
	_note_manager.entity_updated.connect(_on_note_changed.bind("updated"))
	_note_manager.entity_deleted.connect(_on_note_changed.bind("deleted"))

	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	if not _deck_manager.setup(db_path):
		push_error("[NoteList] DeckManager 初始化失败")
		return false

	return true


# ──────────────────────────────────────────────────────────────
# 列表刷新
# ──────────────────────────────────────────────────────────────


## 监听 NoteManager 信号，自动刷新列表。## 输入:
##   event (String) - 事件类型: "created"/"updated"/"deleted"。
##   _entity_type (String) - 实体类型，未使用。
##   _entity_id (int) - 实体 ID，未使用。
## 输出: 无。
func _on_note_changed(event: String, _entity_type: String, _entity_id: int) -> void:
	_refresh_all()


## 全量刷新：重新加载笔记和牌组数据。## 输入: 无。
## 输出: 无。
func _refresh_all() -> void:
	_refresh_deck_names()
	_rebuild_tree()
	_update_status_count()


## 加载 deck_id → deck_name 映射缓存。## 输入: 无。
## 输出: 无。
func _refresh_deck_names() -> void:
	_deck_names.clear()
	if _deck_manager == null:
		return
	var result := _deck_manager.get_all_decks()
	if result.get("success", false):
		for deck in result.get("data", []):
			if deck is DeckEntity:
				_deck_names[deck.id] = deck.name


## 获取 deck 名称（带缓存回退）。## 输入: deck_id (int)。
## 输出: String - 牌组名，无匹配时返回 "牌组#id"。
func _get_deck_name(deck_id: int) -> String:
	if _deck_names.has(deck_id):
		return _deck_names[deck_id]
	return "牌组#%d" % deck_id


## 按牌组分组重建 Tree 列表。## 输入: 无。
## 输出: 无。
func _rebuild_tree() -> void:
	_note_tree.clear()
	_note_tree.columns = 3
	_note_tree.set_column_title(0, "📝 笔记")
	_note_tree.set_column_title(1, "📂 牌组")
	_note_tree.set_column_title(2, "📅 创建时间")
	_note_tree.hide_root = true

	if _note_manager == null:
		return

	var result := _note_manager.get_all_notes()
	if not result.get("success", false):
		return

	var notes: Array = result.get("data", [])
	if notes.is_empty():
		return

	# 按 deck_id 分组
	var by_deck: Dictionary = {}
	for note in notes:
		if not (note is NoteEntity):
			continue
		var did: int = note.deck_id
		if not by_deck.has(did):
			by_deck[did] = []
		by_deck[did].append(note)

	var root: TreeItem = _note_tree.create_item()

	# 按 deck_id 排序输出
	var sorted_deck_ids := by_deck.keys()
	sorted_deck_ids.sort()

	for deck_id in sorted_deck_ids:
		var deck_name: String = _get_deck_name(deck_id)
		var deck_item: TreeItem = _note_tree.create_item(root)
		deck_item.set_text(0, deck_name)
		deck_item.set_text(1, "(%d)" % by_deck[deck_id].size())
		deck_item.set_selectable(0, false)  # 分组项不可选

		var sub_notes: Array = by_deck[deck_id]
		for note in sub_notes:
			if not (note is NoteEntity):
				continue
			var item: TreeItem = _note_tree.create_item(deck_item)
			var summary: String = _make_note_summary(note)
			item.set_text(0, summary)
			item.set_text(1, deck_name)
			item.set_text(2, _format_timestamp(note.created_at))
			item.set_metadata(0, note.id)


## 从 NoteEntity 提取摘要文本（fields_data 第一个字段的前 40 字符）。## 输入: note (NoteEntity)。
## 输出: String - 摘要文本，无字段时返回 "(空笔记)"。
func _make_note_summary(note: NoteEntity) -> String:
	if note.fields_data.is_empty():
		return "(空笔记)"
	var first_value: String = ""
	for key in note.fields_data:
		first_value = str(note.fields_data[key])
		break
	if first_value.length() > 40:
		return first_value.substr(0, 40) + "…"
	return first_value


## 格式化 Unix 时间戳为可读日期字符串。## 输入: ts (int) - 秒级 Unix 时间戳。
## 输出: String - "yyyy-mm-dd" 格式日期。
func _format_timestamp(ts: int) -> String:
	if ts <= 0:
		return "—"
	var dt := Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


## 更新底部状态栏计数。## 输入: 无。
## 输出: 无。
func _update_status_count() -> void:
	if _note_manager == null:
		return
	var result := _note_manager.get_all_notes()
	if result.get("success", false):
		var notes: Array = result.get("data", [])
		_set_status("共 %d 条笔记" % notes.size())


# ──────────────────────────────────────────────────────────────
# 编辑面板
# ──────────────────────────────────────────────────────────────


## Tree 双击事件：加载对应笔记并展开编辑面板。## 输入: 无（从 Tree 当前选中项获取 metadata）。
## 输出: 无。
func _on_item_activated() -> void:
	var selected: TreeItem = _note_tree.get_selected()
	if selected == null:
		return
	var note_id: int = selected.get_metadata(0)
	if note_id <= 0:
		# 可能是分组标题，忽略
		return
	if _note_manager == null:
		return

	var result := _note_manager.get_note(note_id)
	if not result.get("success", false):
		_set_status("获取笔记失败")
		return
	var note: NoteEntity = result.get("data", null)
	if note == null:
		_set_status("笔记不存在")
		return

	_show_editor(note)


## 展开编辑面板并填充笔记数据。## 输入: note (NoteEntity)。
## 输出: 无。
func _show_editor(note: NoteEntity) -> void:
	_clear_editor_rows()

	_edit_title.text = "编辑笔记 #%d" % note.id
	_deck_label.text = "牌组: %s" % _get_deck_name(note.deck_id)
	_created_label.text = "创建: %s" % _format_timestamp(note.created_at)

	# 动态生成字段编辑器
	for field_name in note.fields_data:
		_add_editor_row(field_name, str(note.fields_data[field_name]))

	# 存储当前编辑的 note_id 到 metadata（供保存/删除使用）
	_edit_panel.set_meta("_editing_note_id", note.id)
	_edit_panel.visible = true


## 关闭编辑面板。## 输入: 无。
## 输出: 无。
func _on_close_edit_pressed() -> void:
	_edit_panel.visible = false
	_clear_editor_rows()


## 保存编辑面板中的字段变更到数据库。## 输入: 无。
## 输出: 无。
func _on_save_pressed() -> void:
	var note_id: int = _edit_panel.get_meta("_editing_note_id", 0)
	if note_id <= 0 or _note_manager == null:
		return

	var fields: Dictionary = {}
	for row in _editor_rows:
		fields[row.field_name] = row.input.text

	var result := _note_manager.update_note(note_id, fields)
	if result.get("success", false):
		_set_status("笔记 #%d 已保存 ✓" % note_id)
		_edit_panel.visible = false
		_clear_editor_rows()
	else:
		_set_status("保存失败: %s" % result.get("code", "unknown"))


## 删除当前编辑中的笔记。## 输入: 无。
## 输出: 无。
func _on_delete_pressed() -> void:
	var note_id: int = _edit_panel.get_meta("_editing_note_id", 0)
	if note_id <= 0 or _note_manager == null:
		return

	var result := _note_manager.delete_note(note_id)
	if result.get("success", false):
		_set_status("笔记 #%d 已删除 ✓" % note_id)
		_edit_panel.visible = false
		_clear_editor_rows()
	else:
		_set_status("删除失败: %s" % result.get("code", "unknown"))


## 向编辑面板动态添加一个字段编辑行（HBoxContainer: Label + LineEdit）。## 输入:
##   field_name (String) - 字段名。
##   field_value (String) - 字段当前值。
## 输出: 无。
func _add_editor_row(field_name: String, field_value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = field_name + ":"
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	var input := LineEdit.new()
	input.text = field_value
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "输入 %s…" % field_name
	row.add_child(input)

	_fields_edit.add_child(row)
	_editor_rows.append({"field_name": field_name, "input": input})


## 清除编辑面板中所有动态生成的字段编辑行。## 输入: 无。
## 输出: 无。
func _clear_editor_rows() -> void:
	for row in _editor_rows:
		if row.input != null and is_instance_valid(row.input):
			row.input.get_parent().queue_free()
	_editor_rows.clear()


# ──────────────────────────────────────────────────────────────
# 新建笔记
# ──────────────────────────────────────────────────────────────


## 打开新建笔记对话框，填充牌组下拉列表。## 输入: 无。
## 输出: 无。
func _on_new_note_pressed() -> void:
	_new_deck_select.clear()
	if _deck_manager != null:
		var result := _deck_manager.get_all_decks()
		if result.get("success", false):
			for deck in result.get("data", []):
				if deck is DeckEntity:
					_new_deck_select.add_item(deck.name, deck.id)
	_new_front_input.text = ""
	_new_back_input.text = ""
	_new_dialog.popup_centered()


## 确认新建笔记：收集表单数据并调用 NoteManager.create_note()。## 输入: 无。
## 输出: 无。
func _on_new_dialog_confirmed() -> void:
	if _note_manager == null:
		return

	var deck_id: int = _new_deck_select.get_selected_id()
	if deck_id < 0 and _new_deck_select.item_count > 0:
		deck_id = _new_deck_select.get_item_id(0)

	var fields := {
		"正面": _new_front_input.text.strip_edges(),
		"背面": _new_back_input.text.strip_edges()
	}

	var result := _note_manager.create_note(1, fields, deck_id)  # note_type_id=1 默认
	if result.get("success", false):
		_set_status("笔记已创建 ✓")
	else:
		_set_status("创建失败: %s" % result.get("code", "unknown"))


# ──────────────────────────────────────────────────────────────
# 返回
# ──────────────────────────────────────────────────────────────


## 返回主菜单。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	_switch_scene("res://scenes/ui/main_menu.tscn", "主菜单")


## 安全切换场景。## 输入:
##   path (String) - 场景文件路径。
##   label (String) - 场景名称。
## 输出: 无。
func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status("[color=#FF6666]场景不存在: %s[/color]" % label)
		return
	get_tree().change_scene_to_file(path)


## 设置底部状态栏文本（支持 BBCode）。## 输入: text (String) - 状态文本。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
