extends Control
## AI 调试控制台，用于测试 HTTPRequest 调用 DeepSeek API。
## 支持多轮对话滚动显示，完整上下文记忆。


# ── UI 引用 ──
@onready var _input_edit: TextEdit = $RootMargin/MainVBox/InputRow/InputEdit
@onready var _send_btn: Button = $RootMargin/MainVBox/InputRow/SendBtn
@onready var _chat_scroll: ScrollContainer = $RootMargin/MainVBox/ChatScroll
@onready var _chat_display: RichTextLabel = $RootMargin/MainVBox/ChatScroll/ChatDisplay
@onready var _status_label: Label = $RootMargin/MainVBox/StatusBar/StatusLabel
@onready var _back_btn: Button = $RootMargin/MainVBox/TopBar/BackBtn
@onready var _request: HTTPRequest = $HTTPRequest

# ── API 配置 ──
const API_URL: String = "https://api.deepseek.com/v1/chat/completions"
const API_CFG_PATH: String = "res://api.cfg"
const MODEL: String = "deepseek-chat"
const MAX_HISTORY_TURNS: int = 20  ## 每次请求携带的最大对话轮数

var _api_key: String = ""

## 对话历史数组，元素为 {role: String, content: String}
var _conversation_history: Array[Dictionary] = []

## 系统提示词
var _system_prompt: String = "你是一个知识学习助手的调试台。回答简洁。"


## 连接按钮信号和 HTTP 回调。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_load_api_key()
	_send_btn.pressed.connect(_on_send_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_request.request_completed.connect(_on_response)
	_set_status("就绪。输入消息后点击发送")


## 从 res://api.cfg 读取 API Key（ConfigFile 格式）。## 输入: 无。
## 输出: 无。
func _load_api_key() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(API_CFG_PATH)
	if err != OK:
		_set_status("[color=#FFAA44]api.cfg 未配置[/color]")
		return
	_api_key = cfg.get_value("api", "key", "")
	if _api_key == "" or _api_key.begins_with("sk-your-"):
		_set_status("[color=#FFAA44]请编辑 api.cfg 填入 API Key[/color]")


## 发送按钮回调：记录用户消息、构建带上下文的 JSON 并发送。
func _on_send_pressed() -> void:
	var user_text := _input_edit.text.strip_edges()
	if user_text == "":
		_set_status("输入不能为空")
		return

	if _api_key == "":
		_append_chat_bubble("system", "请先在 api.cfg 中设置 API Key")
		_render_chat()
		return

	_send_btn.disabled = true
	_set_status("正在请求 AI…")

	# 记录用户消息
	_conversation_history.append({"role": "user", "content": user_text})
	_render_chat()
	_input_edit.text = ""

	var messages: Array[Dictionary] = _build_messages(user_text)

	var body := {
		"model": MODEL,
		"messages": messages,
		"max_tokens": 512,
		"temperature": 0.7
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


## HTTP 响应回调。## 输入: result, code, headers, body 由 HTTPRequest 节点传入。
## 输出: 无。
func _on_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_send_btn.disabled = false

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
		_set_status("[color=#FF6666]JSON 解析失败[/color]")
		return

	var data: Dictionary = json.data
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		_set_status("[color=#FFAA44]无 choices[/color]")
		return

	var message: Dictionary = choices[0].get("message", {})
	var content: String = message.get("content", "")

	# 记录 AI 回复
	_conversation_history.append({"role": "assistant", "content": content})
	_render_chat()
	_set_status("就绪")


## 构建发送给 API 的 messages 数组（含系统提示词 + 最近 N 轮历史）。## 输入: _unused (无)。
## 输出: Array[Dictionary]。
func _build_messages(_unused: String = "") -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	messages.append({"role": "system", "content": _system_prompt})

	var start_idx: int = max(_conversation_history.size() - MAX_HISTORY_TURNS * 2, 0)
	for i in range(start_idx, _conversation_history.size()):
		messages.append(_conversation_history[i].duplicate(true))

	return messages


## 追加一条对话气泡到聊天显示（仅修改渲染缓冲，不发请求）。## 输入:
##   role (String) - "user" / "assistant" / "system" / "error"。
##   content (String) - 对话文本。
## 输出: 无。
func _append_chat_bubble(role: String, content: String) -> void:
	_conversation_history.append({"role": role, "content": content})


## 从 _conversation_history 重新渲染整个聊天区域（BBCode 格式化）。## 输入: 无。
## 输出: 无。
func _render_chat() -> void:
	if _chat_display == null:
		return

	var bbcode: String = ""
	for msg in _conversation_history:
		var role: String = msg.get("role", "")
		var text: String = msg.get("content", "")

		match role:
			"user":
				bbcode += "[right][color=#66AAFF][b]你[/b][/color] %s[/right]\n" % text
			"assistant":
				bbcode += "[color=#33CC55][b]AI[/b][/color] %s\n\n" % text
			"error":
				bbcode += "[color=#FFAA44][b]错误[/b][/color]\n%s\n\n" % text
			"system":
				bbcode += "[color=#FF6666][b]系统[/b][/color] %s\n\n" % text

	_chat_display.text = bbcode
	_scroll_to_bottom.call_deferred()


## 将 ScrollContainer 滚动到底部（deferred 调用确保 RichTextLabel 已更新布局）。## 输入: 无。
## 输出: 无。
func _scroll_to_bottom() -> void:
	if _chat_scroll == null:
		return
	var vbar := _chat_scroll.get_v_scroll_bar()
	if vbar != null:
		await get_tree().process_frame
		vbar.value = vbar.max_value


## 返回主菜单。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## 设置底部状态栏。## 输入: text (String)。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
