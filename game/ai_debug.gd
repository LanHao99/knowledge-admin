extends Control
## AI 调试控制台，用于测试 HTTPRequest 调用 DeepSeek API。
## 用 Godot 内置 HTTPRequest 节点发送 OpenAI 兼容请求。


# ── UI 引用 ──
@onready var _input_edit: TextEdit = $RootMargin/MainVBox/InputRow/InputEdit
@onready var _send_btn: Button = $RootMargin/MainVBox/InputRow/SendBtn
@onready var _output_edit: TextEdit = $RootMargin/MainVBox/OutputEdit
@onready var _status_label: Label = $RootMargin/MainVBox/StatusBar/StatusLabel
@onready var _back_btn: Button = $RootMargin/MainVBox/TopBar/BackBtn
@onready var _request: HTTPRequest = $HTTPRequest

# ── API 配置 ──
const API_URL: String = "https://api.deepseek.com/v1/chat/completions"
const API_KEY: String = ""  # TODO: 填入你的 API Key
const MODEL: String = "deepseek-chat"


## 连接按钮信号和 HTTP 回调。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_send_btn.pressed.connect(_on_send_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_request.request_completed.connect(_on_response)
	_set_status("就绪。输入消息后点击发送")


## 发送按钮回调：构建 JSON 并通过 HTTPRequest 发送。## 输入: 无。
## 输出: 无。
func _on_send_pressed() -> void:
	var user_text := _input_edit.text.strip_edges()
	if user_text == "":
		_set_status("输入不能为空")
		return

	if API_KEY == "":
		_append_output("[color=#FF6666]请先在代码中设置 API_KEY[/color]")
		return

	_send_btn.disabled = true
	_set_status("正在请求 AI…")

	var body := {
		"model": MODEL,
		"messages": [
			{"role": "system", "content": "你是一个知识学习助手的调试台。回答简洁。"},
			{"role": "user", "content": user_text}
		],
		"max_tokens": 512,
		"temperature": 0.7
	}

	var json_body := JSON.stringify(body)
	var headers: Array[String] = [
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY
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
		_append_output("[color=#FFAA44]错误响应:[/color]\n" + raw)
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
	_append_output("[b]AI:[/b] " + content)
	_set_status("就绪")
	_input_edit.text = ""


## 向输出区域追加文本。## 输入: text (String) - 要追加的 BBCode 文本。
## 输出: 无。
func _append_output(text: String) -> void:
	if _output_edit.text != "":
		_output_edit.text += "\n\n"
	_output_edit.text += text
	# 滚动到底部
	_output_edit.set_caret_line(_output_edit.get_line_count() - 1)


## 返回主菜单。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## 设置底部状态栏。## 输入: text (String)。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
