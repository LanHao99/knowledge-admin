class_name StoryDialogueOverlay
extends CanvasLayer
## 剧情对话覆盖层 UI，匹配 CardUI 的视觉尺寸和布局。
## 暂停复习时接管屏幕，显示角色名 + 对话文本 + 对话选项（替换评分按钮）。
## 使用 DialogueManager 单例驱动对话流程。
## 集成 TextAnimationController 实现打字机效果和文字动画。
## 对话结束后发出 dialogue_finished 信号。

# ── 信号 ──

## 对话序列结束（包括用户选择跳过或自然结束）。
signal dialogue_finished()

## 某条对话完成标记（如需要记录已完成）。
signal dialogue_completed(dialogue_key: String)


# ── 导出属性 ──

## 当前对话的唯一标识符（用于标记完成）。
@export var dialogue_key: String = ""

## 跳过对话的输入动作。
@export var skip_action: StringName = &"ui_cancel"

## 是否阻止其他输入。
@export var block_input: bool = true

## 打字机速度倍率（1.0 = 默认速度）。
@export var text_speed_multiplier: float = 1.0


# ── 内部状态 ──

## 当前显示的 DialogueLine。
var _current_line = null  # DialogueLine

## 当前对话资源。
var _current_resource = null  # DialogueResource

## DialogueManager 单例引用。
var _dialogue_manager = null

## StoryManager 引用（用于标记完成）。
var _story_manager: StoryManager = null

## 是否正在等待用户选择。
var _is_waiting_for_choice: bool = false

## 打字机是否正在播放中。
var _is_animating: bool = false


# ── 节点引用 ──

@onready var _main_control: Control = $StoryDialogueMain
@onready var _character_label: Label = $StoryDialogueMain/MainVBox/TopBar/CharacterLabel
@onready var _content_label: RichTextLabel = $StoryDialogueMain/MainVBox/CardPanel/CardContentVBox/ContentLabel
@onready var _click_hint: Label = $StoryDialogueMain/MainVBox/CardPanel/CardContentVBox/ClickHint
@onready var _answer_bar: HBoxContainer = $StoryDialogueMain/MainVBox/AnswerBar
@onready var _status_label: Label = $StoryDialogueMain/MainVBox/StatusBar/StatusLabel
@onready var _text_animator: TextAnimationController = $TextAnimationController


# ── 生命周期 ──


## 初始化时隐藏覆盖层，获取 DialogueManager 单例，设置文字动画控制器。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_main_control.hide()
	_dialogue_manager = Engine.get_singleton("DialogueManager")

	# 设置文字动画控制器
	if _text_animator != null:
		_text_animator.setup(_content_label)
		_text_animator.speed_multiplier = text_speed_multiplier
		_text_animator.typewriter_completed.connect(_on_typewriter_finished)
		_text_animator.auto_advance_requested.connect(_on_auto_advance_requested)


## 处理输入：跳过/阻止。## 输入: event (InputEvent)。
## 输出: 无。
func _unhandled_input(event: InputEvent) -> void:
	if not _main_control.visible:
		return

	if block_input:
		get_viewport().set_input_as_handled()

	# 打字机播放中，按跳过键跳过动画
	if _is_animating and event.is_action_pressed(skip_action):
		_skip_typewriter()
		return

	# 在等待选项时，按跳过键结束对话
	if _is_waiting_for_choice and event.is_action_pressed(skip_action):
		_end_dialogue()


# ── 公共接口 ──


## 注入 StoryManager 引用。## 输入: manager (StoryManager)。
## 输出: 无。
func set_story_manager(manager: StoryManager) -> void:
	_story_manager = manager


## 开始播放对话（由 study.gd 或 StoryManager 调用）。## 输入:
##   resource (DialogueResource) - 已加载的对话资源。
##   key (String) - 对话标识符（用于标记完成）。
##   start_title (String) - 起始标题/ID。
## 输出: 无。
func start(resource, key: String = "", start_title: String = "") -> void:
	if resource == null:
		_end_dialogue()
		return

	dialogue_key = key
	_current_resource = resource
	_main_control.show()
	_answer_bar.hide()
	_set_status("")

	var title: String = start_title
	if title.is_empty() and is_instance_valid(resource):
		title = resource.first_title if not resource.first_title.is_empty() else ""

	var line = await _dialogue_manager.get_next_dialogue_line(resource, title)
	await _show_line(line)


# ── 对话行显示 ──


## 展示一行对话（角色名 + 打字机动画文本 + 选项）。## 输入: line (DialogueLine)。
## 输出: 无。
func _show_line(line) -> void:
	if line == null:
		_end_dialogue()
		return

	_current_line = line

	# 角色名（含颜色区分）
	var character_name: String = tr(line.character, "dialogue") if not line.character.is_empty() else ""
	_character_label.text = character_name
	_set_character_color(character_name)

	# 选项或继续 — 先决定是否有选项（在打字机之前确定布局）
	_clear_answer_buttons()

	if line.responses.size() > 0:
		# 有选项：先播放打字机，完成后显示选项按钮
		_answer_bar.hide()
		_is_waiting_for_choice = false  # 先设为 false，打字机完成后由回调设置
	else:
		_answer_bar.hide()
		_is_waiting_for_choice = false

	# 启动打字机动画
	_start_typewriter(tr(line.text, "dialogue"), line)


## 对话面板点击：打字机播放中 → 跳过动画；打字机完成 → 推进到下一行。## 输入: event (InputEvent) — gui_input 信号参数。
## 输出: 无。
func _on_card_panel_clicked(event: InputEvent = null) -> void:
	if event != null:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
			return

	# 打字机播放中：点击 = 跳过动画
	if _is_animating:
		_skip_typewriter()
		return

	# 等待选项中：点击无效
	if _is_waiting_for_choice:
		return

	# 无当前行：不能推进
	if _current_line == null:
		return

	# 推进到下一行
	if not _current_line.next_id.is_empty():
		var next_line = await _dialogue_manager.get_next_dialogue_line(_current_resource, _current_line.next_id)
		await _show_line(next_line)


# ── 选项构建 ──


## 清除 AnswerBar 中所有旧按钮。## 输入: 无。
## 输出: 无。
func _clear_answer_buttons() -> void:
	for child in _answer_bar.get_children():
		child.queue_free()


## 根据 responses 数组动态创建选项按钮。## 输入: responses (Array[DialogueResponse])。
## 输出: 无。
func _build_response_buttons(responses: Array) -> void:
	for i in range(responses.size()):
		var response = responses[i]
		var btn := Button.new()
		btn.name = "OptionBtn%d" % i
		btn.custom_minimum_size = Vector2(140, 52)
		btn.text = tr(response.text, "dialogue")
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_option_selected.bind(i))
		_answer_bar.add_child(btn)


## 选项选择回调：获取下一行对话。## 输入: index (int) - 选项索引。
## 输出: 无。
func _on_option_selected(index: int) -> void:
	if _current_line == null:
		return

	var responses: Array = _current_line.responses
	if index < 0 or index >= responses.size():
		return

	var response = responses[index]
	var next_id: String = response.next_id

	if next_id.is_empty() or next_id in [DMConstants.ID_END, DMConstants.ID_END_CONVERSATION]:
		_end_dialogue()
		return

	_is_waiting_for_choice = false
	var next_line = await _dialogue_manager.get_next_dialogue_line(_current_resource, next_id)
	await _show_line(next_line)


# ── 对话结束 ──


## 结束当前对话序列，隐藏覆盖层，标记完成。## 输入: 无。
## 输出: 无。
func _end_dialogue() -> void:
	# 停止文字动画
	if _text_animator != null:
		_text_animator.clear()
	_is_animating = false

	_main_control.hide()
	_current_line = null
	_current_resource = null
	_is_waiting_for_choice = false
	_set_status("")
	_set_click_hint("")

	if not dialogue_key.is_empty() and _story_manager != null:
		_story_manager.complete_dialogue(dialogue_key)
		_story_manager.end_dialogue()
		dialogue_completed.emit(dialogue_key)

	dialogue_finished.emit()


# ── 打字机动画 ──


## 启动打字机动画显示当前行文本。## 输入:
##   text (String) — 翻译后的对话文本（可能含标记）。
##   line (DialogueLine) — 当前对话行（用于判断是否有选项）。
## 输出: 无。
func _start_typewriter(text: String, line) -> void:
	if _text_animator == null:
		# 无动画控制器：直接显示
		_content_label.text = "[center]%s[/center]" % text
		_on_typewriter_finished()
		return

	_is_animating = true
	_set_click_hint("点击跳过 →")

	# 构建完成回调（捕获 line 引用）
	var callback := func():
		_on_typewriter_done_for_line(line)

	_text_animator.play_line(text, callback)


## 跳过当前打字机动画（立即显示全部文字）。## 输入: 无。
## 输出: 无。
func _skip_typewriter() -> void:
	if _text_animator != null:
		_text_animator.skip_to_end()


## 打字机动画完成回调（由 TextAnimationController 信号触发）。## 输入: 无。
## 输出: 无。
func _on_typewriter_finished() -> void:
	_is_animating = false


## 打字机完成后的处理（根据行是否有选项决定 UI 状态）。## 输入: line (DialogueLine) — 当前行。
## 输出: 无。
func _on_typewriter_done_for_line(line) -> void:
	_is_animating = false

	if line == null:
		return

	# 有选项：显示选项按钮
	if line.responses.size() > 0:
		_build_response_buttons(line.responses)
		_answer_bar.show()
		_is_waiting_for_choice = true
		_set_click_hint("")
	else:
		_set_click_hint("点击继续 →")


## 自动推进请求回调（{auto} 标记触发）。## 输入: 无。
## 输出: 无。
func _on_auto_advance_requested() -> void:
	# 短暂延迟后自动推进
	await get_tree().create_timer(0.6).timeout

	if _current_line == null or _is_waiting_for_choice:
		return

	if not _current_line.next_id.is_empty():
		var next_line = await _dialogue_manager.get_next_dialogue_line(_current_resource, _current_line.next_id)
		await _show_line(next_line)


# ── 工具 ──


## 设置状态栏文本。## 输入: text (String)。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


## 设置点击提示文本（打字机播放中/完成后切换）。## 输入: text (String) — 提示文本，空字符串表示隐藏。
## 输出: 无。
func _set_click_hint(text: String) -> void:
	if _click_hint != null:
		_click_hint.text = text
		_click_hint.visible = not text.is_empty()


## 根据角色名设置 CharacterLabel 颜色。## 输入: name (String) — 角色名。
## 输出: 无。
func _set_character_color(character_name: String) -> void:
	if _character_label == null:
		return

	var sys_color: Color = _text_animator.color_system if _text_animator != null else Color(0.788, 0.659, 0.298)

	match character_name:
		"系统":
			_character_label.add_theme_color_override("font_color", sys_color)
		"MIRA":
			_character_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))  # 金色
		"???":
			_character_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))  # 灰色（未揭示身份）
		_:
			_character_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))  # 默认金色
