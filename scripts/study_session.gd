class_name StudySession
extends Control

const FLASH_CARD_SCENE := preload("res://scenes/flash_card.tscn")
const SAMPLE_DATA_PATH := "res://data/sample_cards.json"

@onready var _progress_label: Label = $TopBar/ProgressLabel
@onready var _stats_label: Label = $TopBar/StatsLabel
@onready var _card_container: CenterContainer = $CardContainer
@onready var _prev_btn: Button = $BottomBar/PrevButton
@onready var _next_btn: Button = $BottomBar/NextButton
@onready var _restart_btn: Button = $BottomBar/RestartButton
@onready var _summary_panel: Panel = $SummaryPanel
@onready var _summary_text: RichTextLabel = $SummaryPanel/SummaryText
@onready var _summary_restart: Button = $SummaryPanel/SummaryRestartButton

var _deck: DeckManager = DeckManager.new()
var _current_index: int = 0
var _current_card: FlashCard = null

func _ready() -> void:
	# 加载卡组
	var err := _deck.load_from_json(SAMPLE_DATA_PATH)
	if err != OK or _deck.total_cards() == 0:
		_push_status("⚠ 数据加载失败，请检查 data/sample_cards.json")
		return

	_deck.start_session(true)
	_setup_ui_connections()
	_show_card(0)

func _setup_ui_connections() -> void:
	_prev_btn.pressed.connect(_on_prev)
	_next_btn.pressed.connect(_on_next)
	_restart_btn.pressed.connect(_on_restart)
	_summary_restart.pressed.connect(_on_restart)

func _show_card(index: int) -> void:
	if index < 0 or index >= _deck.total_cards():
		_show_summary()
		return

	_current_index = index
	_update_progress()

	# 移除旧卡片
	if _current_card != null:
		_current_card.queue_free()

	# 实例化新卡片
	_current_card = FLASH_CARD_SCENE.instantiate() as FlashCard
	var data := _deck.get_card(index)
	_current_card.setup(data)
	_current_card.marked_known.connect(_on_card_known)
	_current_card.marked_unknown.connect(_on_card_unknown)
	_card_container.add_child(_current_card)

	_update_buttons()

func _update_progress() -> void:
	var total := _deck.total_cards()
	_progress_label.text = "第 %d / %d 张" % [_current_index + 1, total]
	var known := _deck.get_known_count()
	var unk := _deck.get_unknown_count()
	_stats_label.text = "会了 %d  |  不会 %d" % [known, unk]

func _update_buttons() -> void:
	_prev_btn.disabled = _current_index <= 0
	var is_last := _current_index >= _deck.total_cards() - 1
	_next_btn.text = "下一张 →" if not is_last else "结束复习"

func _on_card_known() -> void:
	_deck.mark_known(_current_index)
	_update_progress()
	_show_card(_current_index + 1)

func _on_card_unknown() -> void:
	_deck.mark_unknown(_current_index)
	_update_progress()
	_show_card(_current_index + 1)

func _on_prev() -> void:
	_show_card(_current_index - 1)

func _on_next() -> void:
	if _current_index >= _deck.total_cards() - 1:
		_show_summary()
	else:
		_show_card(_current_index + 1)

func _on_restart() -> void:
	_summary_panel.visible = false
	_deck.start_session(true)
	_show_card(0)

func _show_summary() -> void:
	if _current_card != null:
		_current_card.queue_free()
		_current_card = null

	var known := _deck.get_known_count()
	var unk := _deck.get_unknown_count()
	var total := _deck.total_cards()
	var lines := PackedStringArray()

	lines.append("[center][color=#534AB7][font_size=18]复习完成！[/font_size][/color][/center]")
	lines.append("")
	lines.append("总卡片数：%d" % total)
	lines.append("[color=#2FA139]会了：%d[/color]  （%.0f%%）" % [known, float(known) / total * 100])
	lines.append("[color=#CD3838]不会：%d[/color]  （%.0f%%）" % [unk, float(unk) / total * 100])

	var unk_cards := _deck.get_unknown_cards()
	if unk_cards.size() > 0:
		lines.append("")
		lines.append("[color=#CD3838]需重点复习：[/color]")
		for c in unk_cards:
			lines.append("  • " + c.question.substr(0, 30) + "..." if c.question.length() > 30 else "  • " + c.question)

	_summary_text.text = "\n".join(lines)
	_summary_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _summary_panel.visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if _current_card != null:
					_current_card._on_flip()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				_on_prev()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_on_next()
				get_viewport().set_input_as_handled()
			KEY_K:
				_on_card_known()
				get_viewport().set_input_as_handled()
			KEY_U:
				_on_card_unknown()
				get_viewport().set_input_as_handled()

func _push_status(msg: String) -> void:
	_progress_label.text = msg
	_progress_label.modulate = Color(0.8, 0.2, 0.2)
