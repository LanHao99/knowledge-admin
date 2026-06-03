extends Control


var _deck_manager: DeckManager = null
var _note_manager: NoteManager = null
var _fields_rows: Array = []
var _test_card_manager: CardManager = null
var _test_scheduler: SimpleScheduler = null
var _date_offset: int = 0
var _last_offset: int = 0

@onready var _deck_name_input: LineEdit = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckNameInput
@onready var _deck_target_id_input: SpinBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckTargetIdInput
@onready var _deck_parent_option: OptionButton = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckParentOption
@onready var _deck_parent_custom_spin: SpinBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckParentCustomSpin
@onready var _deck_sort_order_input: SpinBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckSortOrderInput
@onready var _deck_archived_check: CheckBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckForm/DeckArchivedCheck
@onready var _deck_list_view: ItemList = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckListView
@onready var _note_id_input: SpinBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/NoteIdInput
@onready var _note_deck_id_input: SpinBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/NoteTypeInput
@onready var _fields_editor: VBoxContainer = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/FieldsEditorWrapper/FieldsEditor
@onready var _add_field_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesForm/FieldsEditorWrapper/AddFieldButton
@onready var _note_list_view: ItemList = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NoteListView
@onready var _log_output: TextEdit = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogOutput

@onready var _create_deck_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/CreateDeckButton
@onready var _read_deck_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/ReadDeckButton
@onready var _update_deck_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/UpdateDeckButton
@onready var _delete_deck_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/DeleteDeckButton
@onready var _list_deck_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/DeckPanel/DeckVBox/DeckButtons/ListDeckButton
@onready var _create_note_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/CreateNoteButton
@onready var _read_note_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/ReadNoteButton
@onready var _update_note_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/UpdateNoteButton
@onready var _delete_note_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/DeleteNoteButton
@onready var _list_note_button: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/ContentHBox/NotesPanel/NotesVBox/NotesButtons/ListNoteButton
@onready var _clear_all_button: Button = $RootMargin/MainVBox/Toolbar/ClearAllDataButton
@onready var _refresh_all_button: Button = $RootMargin/MainVBox/Toolbar/RefreshAllButton
@onready var _back_btn: Button = $RootMargin/MainVBox/Toolbar/BackBtn
@onready var _copy_log_button: Button = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogToolbar/CopyLogButton
@onready var _clear_log_button: Button = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogToolbar/ClearLogButton
@onready var _export_log_button: Button = $RootMargin/MainVBox/MainHSplit/LogPanel/LogVBox/LogToolbar/ExportLogButton
@onready var _clear_data_confirm: ConfirmationDialog = $ClearDataConfirm

## 研究测试面板控件
@onready var _gen_test_data_btn: Button = $RootMargin/MainVBox/Toolbar/GenTestDataBtn
@onready var _gen_card_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/GenCardBtn
@onready var _test_summary: RichTextLabel = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/TestSummary
@onready var _offset_spin: SpinBox = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/OffsetRow/OffsetSpinBox
@onready var _apply_offset_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/OffsetRow/ApplyOffsetBtn
@onready var _undo_offset_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/OffsetRow/UndoOffsetBtn
@onready var _simulated_date_label: Label = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/SimulatedDateLabel
@onready var _minus1_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/QuickBtnRow/Minus1Btn
@onready var _today_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/QuickBtnRow/TodayBtn
@onready var _plus1_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/QuickBtnRow/Plus1Btn
@onready var _plus7_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/QuickBtnRow/Plus7Btn
@onready var _plus30_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/QuickBtnRow/Plus30Btn


## 初始化调试场景，建立数据库连接、设定默认值、绑定事件。
func _ready() -> void:
	_setup_default_inputs()
	_setup_parent_option()
	_bind_actions()
	var init_ok: bool = _ensure_database_ready()
	if init_ok:
		_refresh_deck_list()
		_refresh_note_list()
	_refresh_simulated_date_label()


## 退出场景时释放管理器节点。
func _exit_tree() -> void:
	_clear_fields_editor()
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null
	if _note_manager != null:
		_note_manager.queue_free()
		_note_manager = null
	_cleanup_test_managers()


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
	_back_btn.pressed.connect(_on_back_pressed)
	_copy_log_button.pressed.connect(_on_copy_log_pressed)
	_clear_log_button.pressed.connect(_on_clear_log_pressed)
	_export_log_button.pressed.connect(_on_export_log_pressed)
	_clear_data_confirm.confirmed.connect(_on_clear_data_confirmed)

	# 研究测试面板
	_gen_test_data_btn.pressed.connect(_on_gen_test_data_pressed)
	_gen_card_btn.pressed.connect(_on_gen_test_data_pressed)
	_apply_offset_btn.pressed.connect(_on_apply_offset_pressed)
	_undo_offset_btn.pressed.connect(_on_undo_offset_pressed)
	_minus1_btn.pressed.connect(func(): _apply_date_offset(-1))
	_today_btn.pressed.connect(_on_reset_to_today_pressed)
	_plus1_btn.pressed.connect(func(): _apply_date_offset(1))
	_plus7_btn.pressed.connect(func(): _apply_date_offset(7))
	_plus30_btn.pressed.connect(func(): _apply_date_offset(30))


## 当 Parent OptionButton 切换时，显示/隐藏自定义 SpinBox。
func _on_parent_option_changed(index: int) -> void:
	_deck_parent_custom_spin.visible = (_deck_parent_option.get_item_id(index) == -1)


## 获取当前选中的 parent_id 值。
func _get_selected_parent_id() -> int:
	var selected_id: int = _deck_parent_option.get_item_id(_deck_parent_option.selected)
	if selected_id == -1:
		return roundi(_deck_parent_custom_spin.value)
	return selected_id


## 创建并初始化 Manager。
func _ensure_database_ready() -> bool:
	if _deck_manager != null and _deck_manager.is_ready() and _note_manager != null and _note_manager.is_ready():
		return true
	
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null
	if _note_manager != null:
		_note_manager.queue_free()
		_note_manager = null
	
	const db_path: String = "user://knowledge_admin.db"
	
	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	if not _deck_manager.setup(db_path):
		_append_log("DeckManager 初始化失败")
		return false
	
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
	else:
		_append_log("")


func _on_update_deck_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_id: int = roundi(_deck_target_id_input.value)
	var new_name: String = _deck_name_input.text.strip_edges()
	var is_archived: bool = _deck_archived_check.button_pressed
	_log_operation_header("update_deck", "id=%d name=%s archived=%s" % [deck_id, new_name, str(is_archived)])
	var result: Dictionary = _deck_manager.rename_deck(deck_id, new_name)
	if not result.get("success", false):
		_log_result(result)
		_refresh_deck_list()
		return
	result = _deck_manager.set_deck_archived(deck_id, is_archived)
	_log_result(result)
	if result.get("success", false):
		var deck_result: Dictionary = _deck_manager.get_deck(deck_id)
		if deck_result.get("success", false):
			var deck: DeckEntity = deck_result.get("data", null)
			if deck != null:
				_log_data(_stringify_deck(deck))
	_refresh_deck_list()


func _on_delete_deck_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_id: int = roundi(_deck_target_id_input.value)
	_log_operation_header("delete_deck", "id=%d" % deck_id)
	var result: Dictionary = _deck_manager.delete_deck(deck_id)
	_log_result(result)
	_refresh_deck_list()


func _on_list_decks_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_db: DeckDB = _deck_manager.get_deck_db()
	var result: Dictionary = deck_db.get_all_decks(false)
	_log_operation_header("list_decks", "include_archived=false")
	_log_result(result)
	if result.get("success", false):
		var decks: Array[DeckEntity] = result.get("data", [])
		_append_log("  count: %d" % decks.size())
		for deck in decks:
			_append_log("    " + _stringify_deck(deck))
	_refresh_deck_list()


func _on_deck_item_double_clicked(index: int) -> void:
	var deck_id: int = roundi(_deck_list_view.get_item_metadata(index))
	_deck_target_id_input.value = deck_id
	_on_read_deck_pressed()


# ──────────────────────────────────────────────────────────────
# Note CRUD
# ──────────────────────────────────────────────────────────────


func _on_create_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var deck_id: int = roundi(_note_deck_id_input.value)
	var fields: Dictionary = _read_fields_from_editor()
	var note_type_id: int = 0
	_log_operation_header("create_note", "deck_id=%d fields=%s" % [deck_id, str(fields)])
	var result: Dictionary = _note_manager.create_note(note_type_id, fields, deck_id)
	_log_result(result)
	if result.get("success", false):
		var note: NoteEntity = result.get("data", null)
		if note != null:
			_log_data(_stringify_note(note))
			_note_id_input.value = note.id
	_refresh_note_list()


func _on_read_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var note_id: int = roundi(_note_id_input.value)
	_log_operation_header("read_note", "id=%d" % note_id)
	var result: Dictionary = _note_manager.get_note(note_id)
	_log_result(result)
	if result.get("success", false):
		var note: NoteEntity = result.get("data", null)
		if note != null:
			_log_data(_stringify_note(note))
			_populate_note_form(note)
		else:
			_append_log("  data: null (not found)")
	else:
		_append_log("")


func _on_update_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var note_id: int = roundi(_note_id_input.value)
	var deck_id: int = roundi(_note_deck_id_input.value)
	var fields: Dictionary = _read_fields_from_editor()
	var note_type_id: int = 0
	_log_operation_header("update_note", "id=%d deck_id=%d fields=%s" % [note_id, deck_id, str(fields)])
	var result: Dictionary = _note_manager.update_note_fields(note_id, note_type_id, fields, deck_id)
	_log_result(result)
	if result.get("success", false):
		var note_result: Dictionary = _note_manager.get_note(note_id)
		if note_result.get("success", false):
			var note: NoteEntity = note_result.get("data", null)
			if note != null:
				_log_data(_stringify_note(note))
	_refresh_note_list()


func _on_delete_note_pressed() -> void:
	if not _ensure_database_ready():
		return
	var note_id: int = roundi(_note_id_input.value)
	_log_operation_header("delete_note", "id=%d" % note_id)
	var result: Dictionary = _note_manager.delete_note(note_id)
	_log_result(result)
	_refresh_note_list()


func _on_list_notes_pressed() -> void:
	if not _ensure_database_ready():
		return
	var result: Dictionary = _note_manager.get_all_notes()
	_log_operation_header("list_notes", "")
	_log_result(result)
	if result.get("success", false):
		var notes: Array = result.get("data", [])
		_append_log("  count: %d" % notes.size())
		for note in notes:
			_append_log("    " + _stringify_note(note))
	_refresh_note_list()


func _on_note_item_double_clicked(index: int) -> void:
	var note_id: int = roundi(_note_list_view.get_item_metadata(index))
	_note_id_input.value = note_id
	_on_read_note_pressed()


# ──────────────────────────────────────────────────────────────
# 研究测试 — 功能 A：生成测试数据
# ──────────────────────────────────────────────────────────────


## 生成4张测试卡片（分别模拟 Again/Hard/Good/Easy 评分历史）。
func _on_gen_test_data_pressed() -> void:
	if not _ensure_database_ready():
		return
	_setup_test_managers()

	var db_path: String = "user://knowledge_admin.db"
	var deck_id: int = _ensure_test_deck(db_path)
	if deck_id <= 0:
		_append_log("[生成测试数据] 无法创建 Test Deck")
		return

	var ratings: Array[Dictionary] = [
		{front = "问题1: 遗忘型", back = "答案1", rating = Scheduler.Rating.AGAIN},
		{front = "问题2: 困难型", back = "答案2", rating = Scheduler.Rating.HARD},
		{front = "问题3: 正常型", back = "答案3", rating = Scheduler.Rating.GOOD},
		{front = "问题4: 轻松型", back = "答案4", rating = Scheduler.Rating.EASY},
	]

	var now_ts: int = int(Time.get_unix_time_from_system())
	var summaries: Array[String] = []
	summaries.append("[b]Test Deck (id=%d) 已就绪[/b]" % deck_id)

	for info in ratings:
		var front: String = info["front"]
		var back: String = info["back"]
		var rating: int = info["rating"]

		# 创建笔记
		var fields := {"front": front, "back": back}
		var note_result := _note_manager.create_note(0, fields, deck_id)
		if not note_result.get("success", false):
			summaries.append("  ❌ 笔记创建失败: %s" % str(note_result.get("error", "")))
			continue
		var note: NoteEntity = note_result.get("data")
		if note == null:
			continue

		# 创建卡片
		var card_result := _test_card_manager.create_card(note.id, deck_id)
		if not card_result.get("success", false):
			summaries.append("  ❌ 卡片创建失败")
			continue
		var card: CardEntity = card_result.get("data")

		# 模拟评分
		var next_state := _test_scheduler.calculate_next_state(card, rating, now_ts)
		card.queue = int(next_state.get("queue", card.queue))
		card.due = int(next_state.get("due", card.due))
		card.reps = int(next_state.get("reps", 1))
		card.lapses = int(next_state.get("lapses", 0))
		card.stability = float(next_state.get("stability", 0.0))
		card.difficulty = float(next_state.get("difficulty", 0.0))
		card.step = int(next_state.get("step", -1))
		card.last_review_time = now_ts
		card.last_rating = rating

		var rating_name: String = ""
		match rating:
			Scheduler.Rating.AGAIN: rating_name = "Again"
			Scheduler.Rating.HARD:  rating_name = "Hard"
			Scheduler.Rating.GOOD:  rating_name = "Good"
			Scheduler.Rating.EASY:  rating_name = "Easy"

		# 直接通过 CardDB 写回
		var card_db: CardDB = _test_card_manager.get_card_db()
		card_db.update_card(card)

		var queue_name: String = ""
		match card.queue:
			CardEntity.QUEUE_LEARNING: queue_name = "LEARNING"
			CardEntity.QUEUE_REVIEW:   queue_name = "REVIEW"
		summaries.append("  [color=#55CC55]%s(%s)[/color] → %s, stability=%.2f, lapses=%d" % [rating_name, front, queue_name, card.stability, card.lapses])

	var summary_text: String = "\n".join(summaries)
	_test_summary.text = summary_text
	_append_log("[生成测试数据] 4张卡片已就绪 (deck_id=%d)" % deck_id)


## 确认 Test Deck 牌组存在，若不存在则创建。
func _ensure_test_deck(db_path: String) -> int:
	var deck_db := _deck_manager.get_deck_db()
	var result := deck_db.fetch_all("SELECT id FROM decks WHERE name = 'Test Deck' LIMIT 1;", [])
	if not result.get("success", false):
		return -1
	var rows: Array = result.get("data", [])
	if rows.size() > 0:
		return int(rows[0].get("id", -1))

	var create_result := _deck_manager.create_deck("Test Deck", 0)
	if not create_result.get("success", false):
		return -1
	var deck: DeckEntity = create_result.get("data", null)
	if deck == null:
		return -1
	return deck.id


## 初始化测试专用 CardManager + SimpleScheduler。
func _setup_test_managers() -> void:
	if _test_card_manager != null:
		return
	const db_path: String = "user://knowledge_admin.db"
	_test_card_manager = CardManager.new()
	add_child(_test_card_manager)
	_test_card_manager.setup(db_path)
	_test_scheduler = SimpleScheduler.new()
	_test_card_manager.set_scheduler(_test_scheduler)


## 释放测试专用 Manager 实例。
func _cleanup_test_managers() -> void:
	if _test_card_manager != null:
		_test_card_manager.queue_free()
		_test_card_manager = null
	_test_scheduler = null


# ──────────────────────────────────────────────────────────────
# 研究测试 — 功能 B：日期模拟
# ──────────────────────────────────────────────────────────────


## 应用偏移按钮回调。
func _on_apply_offset_pressed() -> void:
	var delta: int = roundi(_offset_spin.value)
	_apply_date_offset(delta)


## 重置为今日按钮回调。
func _on_reset_to_today_pressed() -> void:
	_setup_test_managers()
	var card_db: CardDB = _test_card_manager.get_card_db()
	var today: int = int(Time.get_unix_time_from_system() / 86400)

	var count_result := card_db.scalar("SELECT COUNT(*) FROM cards WHERE queue = ?", [CardEntity.QUEUE_REVIEW])
	var affected: int = int(count_result.get("data", 0))

	card_db.execute_bind("UPDATE cards SET due = ? WHERE queue = ?", [today, CardEntity.QUEUE_REVIEW])

	_last_offset = 0
	_date_offset = 0
	_refresh_simulated_date_label()
	_append_log("[日期偏移] 重置为今天，影响 %d 张 REVIEW 卡片" % affected)


## 撤销上次偏移按钮回调。
func _on_undo_offset_pressed() -> void:
	if _last_offset == 0:
		_append_log("[撤销] 无上次偏移可撤销")
		return
	_apply_date_offset(-_last_offset, true)
	_append_log("[撤销] 已反向执行偏移")


## 执行日期偏移（SQL 层）。
func _apply_date_offset(delta_days: int, is_undo: bool = false) -> void:
	_setup_test_managers()
	var card_db: CardDB = _test_card_manager.get_card_db()

	var count_result := card_db.scalar("SELECT COUNT(*) FROM cards WHERE queue = ?", [CardEntity.QUEUE_REVIEW])
	var affected: int = int(count_result.get("data", 0))

	card_db.execute_bind("UPDATE cards SET due = due - ? WHERE queue = ?", [delta_days, CardEntity.QUEUE_REVIEW])

	if not is_undo:
		_date_offset += delta_days
		_last_offset = delta_days
	else:
		_last_offset = 0

	_refresh_simulated_date_label()
	_append_log("[日期偏移] %+d 天，影响 %d 张 REVIEW 卡片" % [delta_days, affected])


## 刷新日期模拟标签。
func _refresh_simulated_date_label() -> void:
	if _simulated_date_label == null:
		return
	var today := Time.get_date_string_from_system()
	if _date_offset == 0:
		_simulated_date_label.text = "当前模拟: %s（未偏移）" % today
	else:
		_simulated_date_label.text = "当前模拟: %s %+d 天" % [today, _date_offset]


# ──────────────────────────────────────────────────────────────
# Deck List / Note List 刷新
# ──────────────────────────────────────────────────────────────


func _refresh_deck_list() -> void:
	if _deck_list_view == null:
		return
	_deck_list_view.clear()
	if _deck_manager == null:
		return
	var deck_db: DeckDB = _deck_manager.get_deck_db()
	if deck_db == null:
		return
	var result: Dictionary = deck_db.get_all_decks(false)
	if not result.get("success", false):
		return
	var decks: Array[DeckEntity] = result.get("data", [])
	for deck in decks:
		var idx: int = _deck_list_view.add_item(deck.name)
		_deck_list_view.set_item_metadata(idx, deck.id)


func _refresh_note_list() -> void:
	if _note_list_view == null:
		return
	_note_list_view.clear()
	if _note_manager == null:
		return
	var result: Dictionary = _note_manager.get_all_notes()
	if not result.get("success", false):
		return
	var notes: Array = result.get("data", [])
	for note in notes:
		var fields: Dictionary = note.fields_data if note is NoteEntity else {}
		var front: String = str(fields.get("front", fields.get("Front", "?")))
		var idx: int = _note_list_view.add_item("id=%d %s" % [note.id, front])
		_note_list_view.set_item_metadata(idx, note.id)


# ──────────────────────────────────────────────────────────────
# Log Helpers
# ──────────────────────────────────────────────────────────────


func _log_operation_header(op: String, input_info: String) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	_log_output.text += "[%s] === %s ===\n" % [timestamp, op]
	_log_output.text += "  input: %s\n" % input_info
	_scroll_to_bottom()


func _log_result(result: Dictionary) -> void:
	if result.get("success", false):
		_log_output.text += "  result: OK\n"
	else:
		var code: String = str(result.get("code", "UNKNOWN"))
		var error_msg: String = str(result.get("error", "未知错误"))
		_log_output.text += "  result: FAIL (%s) %s\n" % [code, error_msg]
	_scroll_to_bottom()


func _log_data(message: String) -> void:
	_log_output.text += "  data: " + message + "\n"
	_scroll_to_bottom()


func _append_log(message: String) -> void:
	_log_output.text += message + "\n"
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	if _log_output != null:
		_log_output.set_caret_line(_log_output.get_line_count() - 1)


# ──────────────────────────────────────────────────────────────
# Utility
# ──────────────────────────────────────────────────────────────


func _stringify_deck(deck: DeckEntity) -> String:
	return "Deck(id=%d, name='%s', parent_id=%d, archived=%s)" % [deck.id, deck.name, deck.parent_id, str(deck.is_archived)]


func _stringify_note(note: NoteEntity) -> String:
	var fields: Dictionary = note.fields_data
	return "Note(id=%d, deck_id=%d, fields=%s)" % [note.id, note.deck_id, str(fields)]


func _read_fields_from_editor() -> Dictionary:
	var fields: Dictionary = {}
	for row in _fields_rows:
		var key_edit: LineEdit = row.get("key_edit", null)
		var value_edit: LineEdit = row.get("value_edit", null)
		if key_edit == null or value_edit == null:
			continue
		var key: String = key_edit.text.strip_edges()
		if key.is_empty():
			continue
		fields[key] = value_edit.text
	return fields


func _add_field_row(key: String = "", value: String = "") -> void:
	var row_hbox := HBoxContainer.new()
	row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_hbox.add_theme_constant_override("separation", 4)

	var key_edit := LineEdit.new()
	key_edit.size_flags_horizontal = 3
	key_edit.placeholder_text = "key"
	key_edit.text = key
	row_hbox.add_child(key_edit)

	var value_edit := LineEdit.new()
	value_edit.size_flags_horizontal = 3
	value_edit.placeholder_text = "value"
	value_edit.text = value
	row_hbox.add_child(value_edit)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.pressed.connect(func(): _remove_field_row(row_hbox))
	row_hbox.add_child(remove_btn)

	_fields_editor.add_child(row_hbox)
	_fields_rows.append({"row": row_hbox, "key_edit": key_edit, "value_edit": value_edit})


func _remove_field_row(row: HBoxContainer) -> void:
	for i in range(_fields_rows.size() - 1, -1, -1):
		if _fields_rows[i].get("row") == row:
			_fields_rows.remove_at(i)
			break
	row.queue_free()


func _clear_fields_editor() -> void:
	for row_data in _fields_rows:
		var row: HBoxContainer = row_data.get("row", null)
		if row != null:
			row.queue_free()
	_fields_rows.clear()


func _populate_deck_form(deck: DeckEntity) -> void:
	_deck_name_input.text = deck.name
	_deck_archived_check.button_pressed = deck.is_archived


func _populate_note_form(note: NoteEntity) -> void:
	_note_deck_id_input.value = note.deck_id
	_clear_fields_editor()
	var fields: Dictionary = note.fields_data
	for key in fields:
		_add_field_row(key, str(fields[key]))


func _on_add_field_pressed() -> void:
	_add_field_row()


func _on_clear_all_pressed() -> void:
	_clear_data_confirm.popup_centered()


func _on_clear_data_confirmed() -> void:
	if not _ensure_database_ready():
		return
	var deck_db: DeckDB = _deck_manager.get_deck_db()
	deck_db.execute_bind("DELETE FROM cards;", [])
	deck_db.execute_bind("DELETE FROM notes;", [])
	deck_db.execute_bind("DELETE FROM decks;", [])
	_append_log("[清空] 已清空 cards / notes / decks 三张表")
	_refresh_deck_list()
	_refresh_note_list()


func _on_refresh_all_pressed() -> void:
	_refresh_deck_list()
	_refresh_note_list()
	_append_log("[刷新] 牌组和笔记列表已刷新")


func _on_back_pressed() -> void:
	_switch_scene("res://scenes/ui/main_menu.tscn", "主菜单")


func _on_copy_log_pressed() -> void:
	DisplayServer.clipboard_set(_log_output.text)
	_append_log("[日志] 已复制到剪贴板")


func _on_clear_log_pressed() -> void:
	_log_output.text = ""


func _on_export_log_pressed() -> void:
	_append_log("[日志] 导出功能尚未实现")


func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_append_log("[color=#FF6666]场景不存在: %s[/color]" % label)
		return
	get_tree().change_scene_to_file(path)
