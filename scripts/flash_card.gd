class_name FlashCard
extends Control

##  emitted when user marks card as known
signal marked_known
##  emitted when user marks card as not known
signal marked_unknown
##  emitted when card is flipped (front -> back or back -> front)
signal flipped(is_back: bool)

@onready var _front_panel: Panel = $FrontPanel
@onready var _back_panel: Panel = $BackPanel
@onready var _front_text: RichTextLabel = $FrontPanel/TextContent
@onready var _back_text: RichTextLabel = $BackPanel/TextContent
@onready var _type_badge: Label = $FrontPanel/TypeBadge
@onready var _category_label: Label = $FrontPanel/CategoryLabel
@onready var _hint_label: Label = $FrontPanel/HintLabel
@onready var _flip_btn_front: Button = $FrontPanel/FlipButton
@onready var _flip_btn_back: Button = $BackPanel/FlipButton
@onready var _known_btn: Button = $BackPanel/KnownButton
@onready var _unknown_btn: Button = $BackPanel/UnknownButton

var _data: CardData
var _is_flipped: bool = false

func _ready() -> void:
	_flip_btn_front.pressed.connect(_on_flip)
	_flip_btn_back.pressed.connect(_on_flip)
	_known_btn.pressed.connect(_on_marked_known)
	_unknown_btn.pressed.connect(_on_marked_unknown)
	# Allow clicking anywhere on the card to flip (when not on buttons)
	_front_panel.gui_input.connect(_on_panel_input)
	_back_panel.gui_input.connect(_on_panel_input)

## Setup the card with data. Must be called after adding to tree.
func setup(data: CardData) -> void:
	_data = data
	_type_badge.text = data.get_type_label()
	_category_label.text = data.category if not data.category.is_empty() else ""
	_front_text.text = data.build_front()
	_back_text.text = data.build_answer()
	if not data.explanation.is_empty():
		_back_text.text += "\n\n[color=#888888]解析：" + data.explanation + "[/color]"
	_show_front()

func _show_front() -> void:
	_is_flipped = false
	_front_panel.visible = true
	_back_panel.visible = false
	flipped.emit(false)

func _show_back() -> void:
	_is_flipped = true
	_front_panel.visible = false
	_back_panel.visible = true
	flipped.emit(true)

func _on_flip() -> void:
	if _is_flipped:
		_show_front()
	else:
		_show_back()

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_flip()

func _on_marked_known() -> void:
	marked_known.emit()

func _on_marked_unknown() -> void:
	marked_unknown.emit()

## Reset card to front side. Call before reusing this instance.
func reset() -> void:
	_show_front()
