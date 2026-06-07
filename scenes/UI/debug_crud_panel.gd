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
@onready var _debug_mode_check: CheckButton = $RootMargin/MainVBox/Toolbar/DebugMode
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
@onready var _easy_all_btn: Button = $RootMargin/MainVBox/MainHSplit/LeftVSplit/StudyTestPanel/StudyTestVBox/EasyAllBtn


## 初始化调试场景，建立数据库连接、设定默认值、绑定事件、同步调试模式状态。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_default_inputs()
	_setup_parent_option()
	_bind_actions()

	# 同步调试模式状态
	_setup_debug_mode()

	var init_ok: bool = _ensure_database_ready()
	if init_ok:
		_refresh_deck_list()
		_refresh_note_list()
	_refresh_simulated_date_label()

	TutorialManager.check_and_show("debug_panel", self )


## 确保数据库管理器已初始化（创建 DeckManager + NoteManager）。## 输入: 无。
## 输出: bool — 初始化成功返回 true。
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
		push_error("[DebugCrudPanel] DeckManager 初始化失败")
		return false

	_note_manager = NoteManager.new()
	add_child(_note_manager)
	_note_manager.setup(db_path)

	return true


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


## 释放测试用 CardManager 和 Scheduler。## 输入: 无。
## 输出: 无。
func _cleanup_test_managers() -> void:
	if _test_card_manager != null:
		_test_card_manager.queue_free()
		_test_card_manager = null
	_test_scheduler = null


## 清空 fields 编辑器中的动态行。## 输入: 无。
## 输出: 无。
func _clear_fields_editor() -> void:
	for row in _fields_rows:
		if is_instance_valid(row):
			row.queue_free()
	_fields_rows.clear()


## 刷新牌组列表显示。## 输入: 无。
## 输出: 无。
func _refresh_deck_list() -> void:
	pass # TODO: 实现牌组列表刷新


## 刷新笔记列表显示。## 输入: 无。
## 输出: 无。
func _refresh_note_list() -> void:
	pass # TODO: 实现笔记列表刷新


## 更新模拟日期标签显示。## 输入: 无。
## 输出: 无。
func _refresh_simulated_date_label() -> void:
	pass # TODO: 显示当前模拟日期


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


## 初始化调试模式：同步 CheckButton 到 DebugSettings，连接信号。
func _setup_debug_mode() -> void:
	if _debug_mode_check == null:
		return
	# 同步初始状态
	_debug_mode_check.button_pressed = DebugSettings.debug_mode
	# 用户点击开关
	_debug_mode_check.toggled.connect(_on_debug_mode_toggled)
	# 外部设置变化（如通过代码切换）
	if not DebugSettings.debug_mode_changed.is_connected(_on_global_debug_changed):
		DebugSettings.debug_mode_changed.connect(_on_global_debug_changed)
	# 初始应用可见性
	_apply_debug_visibility(DebugSettings.debug_mode)


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
	_easy_all_btn.pressed.connect(_on_easy_all_pressed)


## 用户点击调试模式 CheckButton → 切换全局状态。## 输入: pressed (bool) — 按钮是否按下。
## 输出: 无。
func _on_debug_mode_toggled(pressed: bool) -> void:
	DebugSettings.set_debug_mode(pressed)


## Autoload 调试模式变化回调 → 同步 CheckButton 和 UI 可见性。## 输入: enabled (bool)。
## 输出: 无。
func _on_global_debug_changed(enabled: bool) -> void:
	if _debug_mode_check != null:
		_debug_mode_check.set_pressed_no_signal(enabled)
	_apply_debug_visibility(enabled)


## 根据调试模式控制 debugUI 分组节点的可见性。## 输入: enabled (bool)。
## 输出: 无。
func _apply_debug_visibility(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("debugUI"):
		if node is CanvasItem:
			node.visible = enabled