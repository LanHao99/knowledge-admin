extends Control
## AI 制卡助手 — 支持 DeepSeek API 对话制卡、文件上传、JSON Mode 自动导入。
## System prompt 保存到 user://ai_settings.cfg，API Key 从 res://api.cfg 读取。

# ── UI 引用 ──
@onready var _input_edit: TextEdit = $RootMargin/MainVBox/InputRow/InputEdit
@onready var _send_btn: Button = $RootMargin/MainVBox/InputRow/SendBtn
@onready var _upload_btn: Button = $RootMargin/MainVBox/InputRow/UploadBtn
@onready var _chat_scroll: ScrollContainer = $RootMargin/MainVBox/ChatScroll
@onready var _chat_display: RichTextLabel = $RootMargin/MainVBox/ChatScroll/ChatDisplay
@onready var _status_label: Label = $RootMargin/MainVBox/StatusBar/StatusLabel
@onready var _back_btn: Button = $RootMargin/MainVBox/TopBar/BackBtn
@onready var _settings_btn: Button = $RootMargin/MainVBox/TopBar/SettingsBtn
@onready var _request: HTTPRequest = $HTTPRequest
@onready var _settings_panel: PanelContainer = $RootMargin/MainVBox/SettingsPanel
@onready var _prompt_edit: TextEdit = $RootMargin/MainVBox/SettingsPanel/SettingsMargin/SettingsVBox/PromptEdit
@onready var _save_settings_btn: Button = $RootMargin/MainVBox/SettingsPanel/SettingsMargin/SettingsVBox/SettingsBtnRow/SaveSettingsBtn
@onready var _reset_prompt_btn: Button = $RootMargin/MainVBox/SettingsPanel/SettingsMargin/SettingsVBox/SettingsBtnRow/ResetPromptBtn

# ── API 配置 ──
const API_URL: String = "https://api.deepseek.com/v1/chat/completions"
const API_CFG_PATH: String = "res://api.cfg"
const SETTINGS_PATH: String = "user://ai_settings.cfg"
const MODEL_DEFAULT: String = "deepseek-chat"
const MAX_HISTORY_TURNS: int = 20

# ── 默认系统提示词（适配平面 JSON 格式） ──
const DEFAULT_SYSTEM_PROMPT: String = """你是一个专业的学习卡片生成助手。你的任务是根据用户提供的学习材料或问题，提取核心知识点，生成 JSON 格式的学习卡片。

## 输出格式

严格要求：仅输出一个 JSON 数组，不包含任何 Markdown 标记（例如 json 代码块）、解释性文字或额外文本。

示例格式：
[
  {"正面": "知识点问题/术语", "背面": "简洁准确的答案或解释"}
]

## 规则

- 每个卡片聚焦一个知识点
- 正面应简洁明确（≤30字），背面写核心解释（≤200字）
- 确保覆盖材料中的所有核心概念
- 知识点必须准确，与材料一致
- JSON 必须可直接解析，不带任何额外文本"""

var _api_key: String = ""
var _model: String = MODEL_DEFAULT
var _system_prompt: String = DEFAULT_SYSTEM_PROMPT
var _temperature: float = 0.7
var _max_tokens: int = 2048

## 对话历史
var _conversation_history: Array[Dictionary] = []

# ── 导入管理器 ──
var _notetype_manager: NoteTypeManager = null
var _import_manager: ImportManager = null
var _note_manager: NoteManager = null
var _deck_db: DeckDB = null


func _ready() -> void:
	_load_api_key()
	_load_settings()
	_bind_actions()
	_init_managers()
	_set_status("就绪。输入消息或点击 📎 上传文档")

	TutorialManager.check_and_show("ai_debug", self)


func _bind_actions() -> void:
	_send_btn.pressed.connect(_on_send_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_upload_btn.pressed.connect(_on_upload_pressed)
	_settings_btn.pressed.connect(_on_settings_toggle)
	_save_settings_btn.pressed.connect(_on_save_settings)
	_reset_prompt_btn.pressed.connect(_on_reset_prompt)
	_request.request_completed.connect(_on_response)


# ── API Key ──

func _load_api_key() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(API_CFG_PATH)
	if err != OK:
		_set_status("[color=#FFAA44]api.cfg 未配置[/color]")
		return
	_api_key = cfg.get_value("api", "key", "")
	if _api_key == "" or _api_key.begins_with("sk-your-"):
		_set_status("[color=#FFAA44]请编辑 api.cfg 填入 API Key[/color]")


# ── 设置 ──

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_system_prompt = DEFAULT_SYSTEM_PROMPT
		return
	_system_prompt = cfg.get_value("ai", "system_prompt", DEFAULT_SYSTEM_PROMPT)
	_model = cfg.get_value("ai", "model", MODEL_DEFAULT)
	_temperature = cfg.get_value("ai", "temperature", 0.7)
	_max_tokens = cfg.get_value("ai", "max_tokens", 2048)
	_prompt_edit.text = _system_prompt


func _on_settings_toggle() -> void:
	_prompt_edit.text = _system_prompt
	_settings_panel.visible = not _settings_panel.visible


func _on_save_settings() -> void:
	_system_prompt = _prompt_edit.text.strip_edges()
	if _system_prompt == "":
		_system_prompt = DEFAULT_SYSTEM_PROMPT
		_prompt_edit.text = _system_prompt

	var cfg := ConfigFile.new()
	cfg.set_value("ai", "system_prompt", _system_prompt)
	cfg.set_value("ai", "model", _model)
	cfg.set_value("ai", "temperature", _temperature)
	cfg.set_value("ai", "max_tokens", _max_tokens)
	cfg.save(SETTINGS_PATH)
	_settings_panel.visible = false
	_set_status("[color=#33CC55]设置已保存 ✓[/color]")


func _on_reset_prompt() -> void:
	_system_prompt = DEFAULT_SYSTEM_PROMPT
	_prompt_edit.text = _system_prompt
	_set_status("[color=#FFAA44]已恢复默认提示词[/color]")


# ── 管理器初始化 ──

func _init_managers() -> void:
	const db_path: String = "user://knowledge_admin.db"

	_notetype_manager = NoteTypeManager.new()
	add_child(_notetype_manager)
	if not _notetype_manager.setup(db_path):
		push_error("[AIDebug] NoteTypeManager 初始化失败")
		return

	_note_manager = NoteManager.new()
	add_child(_note_manager)
	if not _note_manager.setup(db_path):
		push_error("[AIDebug] NoteManager 初始化失败")
		return

	var deck_manager := DeckManager.new()
	add_child(deck_manager)
	if not deck_manager.setup(db_path):
		push_error("[AIDebug] DeckManager 初始化失败")
		return
	_deck_db = deck_manager.get_deck_db()

	_import_manager = ImportManager.new()
	add_child(_import_manager)
	_import_manager.setup(_note_manager, _notetype_manager, _deck_db)


# ── 发送消息 ──

func _on_send_pressed() -> void:
	_send_message(_input_edit.text)


func _send_message(raw_text: String) -> void:
	var user_text := raw_text.strip_edges()
	if user_text == "":
		_set_status("输入不能为空")
		return

	if _api_key == "":
		_append_chat_bubble("system", "请先在 api.cfg 中设置 API Key")
		_render_chat()
		return

	_send_btn.disabled = true
	_upload_btn.disabled = true
	_set_status("正在请求 AI…")

	_conversation_history.append({"role": "user", "content": user_text})
	_render_chat()
	_input_edit.text = ""

	var messages: Array[Dictionary] = _build_messages()

	var body := {
		"model": _model,
		"messages": messages,
		"max_tokens": _max_tokens,
		"temperature": _temperature,
		"response_format": {"type": "json_object"}
	}

	var json_body := JSON.stringify(body)
	var headers: Array[String] = [
		"Content-Type: application/json",
		"Authorization: Bearer " + _api_key
	]

	var error := _request.request(API_URL, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		_set_status("[color=#FF6666]请求发送失败 (err=%d)[/color]" % error)
		_send_btn.disabled = false
		_upload_btn.disabled = false


# ── 文件上传 ──

func _on_upload_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.name = "TempUploadDialog"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "选择文档 (.md / .txt)"
	file_dialog.add_filter("*.md ; *.txt", "文档文件 (*.md, *.txt)")
	file_dialog.file_selected.connect(_on_file_uploaded)
	file_dialog.canceled.connect(file_dialog.queue_free)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(600, 500))


func _on_file_uploaded(path: String) -> void:
	for child in get_children():
		if child is FileDialog and child.name == "TempUploadDialog":
			child.queue_free()
			break

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("[color=#FF6666]无法打开文件[/color]")
		return

	var content: String = file.get_as_text()
	file.close()

	if content.length() > 50000:
		content = content.substr(0, 50000) + "\n\n…(内容过长，已截断)"
		_set_status("[color=#FFAA44]文档过长，已截取前 50000 字符[/color]")

	var filename := path.get_file()
	var prompt := "请根据以下文档内容生成学习卡片：\n\n[文档: %s]\n\n%s" % [filename, content]
	_append_chat_bubble("system", "已上传: %s (%d 字符)" % [filename, content.length()])
	_render_chat()
	_send_message(prompt)


# ── HTTP 响应 ──

func _on_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_send_btn.disabled = false
	_upload_btn.disabled = false

	if code != 200:
		_set_status("[color=#FF6666]HTTP %d[/color]" % code)
		var raw := body.get_string_from_utf8()
		if raw.length() > 500:
			raw = raw.substr(0, 500) + "…"
		_append_chat_bubble("error", raw)
		_render_chat()
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		_set_status("[color=#FF6666]API 响应解析失败[/color]")
		return

	var data: Dictionary = json.data
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		_set_status("[color=#FFAA44]无 choices[/color]")
		return

	var message: Dictionary = choices[0].get("message", {})
	var content: String = message.get("content", "")

	_conversation_history.append({"role": "assistant", "content": content})
	_render_chat()
	_set_status("就绪")

	# 尝试检测 JSON 卡片并弹出导入
	_try_import_cards(content)


# ── 自动导入 ──

func _try_import_cards(content: String) -> void:
	# 尝试解析 AI 返回的 JSON 中的卡片数组
	var parsed := _extract_card_array(content)
	if parsed.is_empty():
		return

	_show_import_dialog(parsed)


func _extract_card_array(content: String) -> Array:
	var json := JSON.new()
	var err := json.parse(content.strip_edges())
	if err != OK:
		return []

	var data: Variant = json.data
	var cards: Array = []

	if typeof(data) == TYPE_ARRAY:
		# 直接是卡片数组
		for item in data:
			if item is Dictionary and (item.has("正面") or item.has("front")):
				cards.append(item)
	elif typeof(data) == TYPE_DICTIONARY:
		# JSON Mode 返回 {"cards": [...]} 或嵌套结构
		var dict := data as Dictionary
		for key in ["cards", "items", "data", "flashcards"]:
			if dict.has(key) and dict[key] is Array:
				cards = dict[key]
				break
		if cards.is_empty():
			# 浅层扁平：如果 dict 本身就有 正面 键，说明是单张卡
			if dict.has("正面") or dict.has("front"):
				cards = [dict]

	return cards


func _show_import_dialog(cards: Array) -> void:
	if _deck_db == null or _import_manager == null:
		_append_chat_bubble("system", "检测到 %d 张卡片，但导入模块未就绪" % cards.size())
		_render_chat()
		return

	var dialog := ConfirmationDialog.new()
	dialog.name = "ImportDeckDialog"
	dialog.title = "导入卡片"
	dialog.dialog_text = "AI 生成了 %d 张卡片，请选择目标牌组：" % cards.size()
	dialog.get_ok_button().text = "导入"
	dialog.get_cancel_button().text = "取消"

	var deck_select := OptionButton.new()
	deck_select.name = "DeckSelect"
	var deck_result := _deck_db.get_all_decks(false)
	if deck_result.get("success", false):
		for d in deck_result.get("data", []):
			var deck: DeckEntity = d
			deck_select.add_item(deck.name, deck.id)
	dialog.add_child(deck_select)
	# 把下拉移到对话框中央
	deck_select.position = Vector2(20, 60)

	var cards_ref: Array = cards.duplicate()
	dialog.confirmed.connect(func():
		var idx := deck_select.selected
		if idx < 0:
			_set_status("[color=#FFAA44]未选择牌组[/color]")
			dialog.queue_free()
			return
		var deck_id_int: int = deck_select.get_item_id(idx)
		var deck_id: String = str(deck_id_int)

		# 用 import_from_dict 导入
		var result := _import_manager.import_from_dict(cards_ref, deck_id, "__default__", {})
		if result.get("success", false) or result.get("data", {}).get("imported", 0) > 0:
			var info: Dictionary = result.get("data", {})
			var ok_count: int = info.get("imported", cards_ref.size())
			_append_chat_bubble("system", "✅ 已导入 %d 张卡片到牌组" % ok_count)
			_set_status("[color=#33CC55]导入 %d 张卡片 ✓[/color]" % ok_count)
		else:
			_append_chat_bubble("system", "❌ 导入失败: %s" % result.get("error", "未知错误"))
			_set_status("[color=#FF6666]导入失败[/color]")
		_render_chat()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2(400, 200))


# ── messages 构建 ──

func _build_messages() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	messages.append({"role": "system", "content": _system_prompt})

	var start_idx: int = max(_conversation_history.size() - MAX_HISTORY_TURNS * 2, 0)
	for i in range(start_idx, _conversation_history.size()):
		messages.append(_conversation_history[i].duplicate(true))

	return messages


# ── 聊天渲染 ──

func _append_chat_bubble(role: String, content: String) -> void:
	_conversation_history.append({"role": role, "content": content})


func _render_chat() -> void:
	if _chat_display == null:
		return

	var bbcode: String = ""
	for msg in _conversation_history:
		var role: String = msg.get("role", "")
		var text: String = msg.get("content", "")

		# 截断长 JSON 用于显示
		var display: String = text
		if role == "assistant" and text.begins_with("[") and text.length() > 600:
			display = text.substr(0, 600) + "\n…(已截断，完整数据通过导入)…"

		match role:
			"user":
				bbcode += "[right][color=#66AAFF][b]你[/b][/color] %s[/right]\n" % display
			"assistant":
				bbcode += "[color=#33CC55][b]AI[/b][/color] %s\n\n" % display
			"error":
				bbcode += "[color=#FFAA44][b]错误[/b][/color]\n%s\n\n" % display
			"system":
				bbcode += "[color=#888888][b]·[/b][/color] %s\n\n" % display

	_chat_display.text = bbcode
	_scroll_to_bottom.call_deferred()


func _scroll_to_bottom() -> void:
	if _chat_scroll == null:
		return
	var vbar := _chat_scroll.get_v_scroll_bar()
	if vbar != null:
		await get_tree().process_frame
		vbar.value = vbar.max_value


# ── 导航 ──

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
