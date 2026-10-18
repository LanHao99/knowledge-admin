extends Node
## 管理学习快捷键的默认值、改键、冲突检查和存档。
## 不写入 InputMap，避免覆盖引擎的 ui_accept 与 ui_cancel。

signal bindings_changed
signal settings_save_failed(error: int)

const SAVE_PATH: String = "user://shortcut_settings.cfg"
const ACTION_FLIP: StringName = &"flip_card"
const ACTION_AGAIN: StringName = &"rate_again"
const ACTION_HARD: StringName = &"rate_hard"
const ACTION_GOOD: StringName = &"rate_good"
const ACTION_EASY: StringName = &"rate_easy"
const ACTION_EXIT: StringName = &"exit_study"
const ACTION_SAVE_DOCUMENT: StringName = &"save_computer_document"

const ACTION_LABELS: Dictionary = {
	&"flip_card": "翻面",
	&"rate_again": "重来",
	&"rate_hard": "困难",
	&"rate_good": "良好",
	&"rate_easy": "简单",
	&"exit_study": "退出学习",
	&"save_computer_document": "保存文档",
}
const ACTION_HINTS: Dictionary = {
	&"flip_card": "卡片正面",
	&"rate_again": "卡片背面",
	&"rate_hard": "卡片背面",
	&"rate_good": "卡片背面",
	&"rate_easy": "卡片背面",
	&"exit_study": "学习中或完成统计",
	&"save_computer_document": "我的电脑正在编辑文档",
}

var settings_path: String = SAVE_PATH
var _bindings: Dictionary = {}


## 先放上默认绑定，进入场景树后再读存档。## 输入: 无。
## 输出: 无。
func _init() -> void:
	_apply_defaults()


## 读取玩家快捷键配置。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	load_settings()


## 按界面顺序返回全部动作。## 输入: 无。
## 输出: Array[StringName] - 动作标识。
func get_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	actions.append(ACTION_FLIP)
	actions.append(ACTION_AGAIN)
	actions.append(ACTION_HARD)
	actions.append(ACTION_GOOD)
	actions.append(ACTION_EASY)
	actions.append(ACTION_EXIT)
	actions.append(ACTION_SAVE_DOCUMENT)
	return actions


## 返回动作的中文名。## 输入: action (StringName) - 动作标识。
## 输出: String - 显示名称，未知动作返回空字符串。
func get_action_label(action: StringName) -> String:
	return str(ACTION_LABELS.get(action, ""))


## 返回动作的生效说明。## 输入: action (StringName) - 动作标识。
## 输出: String - 说明文字。
func get_action_hint(action: StringName) -> String:
	return str(ACTION_HINTS.get(action, ""))


## 复制当前绑定，避免外部改到内部状态。## 输入: action (StringName) - 动作标识。
## 输出: Dictionary - 含 keycode 与修饰键；未绑定为空字典。
func get_binding(action: StringName) -> Dictionary:
	var binding: Dictionary = _bindings.get(action, {})
	return binding.duplicate()


## 返回按钮和提示用的短名。## 输入: action (StringName) - 动作标识。
## 输出: String - 本地化按键名；未绑定返回空字符串。
func get_display_text(action: StringName) -> String:
	var binding: Dictionary = _bindings.get(action, {})
	if binding.is_empty():
		return ""
	return format_binding(binding, true)


## 判断按下的键对应哪个学习动作。松开和长按重复不匹配。## 输入: event (InputEvent) - 输入事件。
## 输出: StringName - 命中的动作；未命中返回空名。
func match_action(event: InputEvent) -> StringName:
	if event == null or not (event is InputEventKey):
		return &""
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return &""
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	var candidate := _binding(code, key.shift_pressed, key.ctrl_pressed, key.alt_pressed, key.meta_pressed)
	for action: StringName in get_actions():
		if _same_binding(_bindings.get(action, {}), candidate):
			return action
	return &""


## 写入绑定。冲突或无效按键不修改原值。## 输入:
##   action (StringName) - 要修改的动作。
##   event (InputEventKey) - 玩家按下的键。
## 输出: Dictionary - ok 表示已写入；error 为 CONFLICT、INVALID 或 SAVE_FAILED。
func set_binding(action: StringName, event: InputEventKey) -> Dictionary:
	var invalid := {"ok": false, "error": "INVALID", "conflict_action": &""}
	if not get_actions().has(action) or event == null or not event.pressed or event.echo:
		return invalid
	var code := event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if code == KEY_NONE or _is_modifier_keycode(code):
		return invalid
	var candidate := _binding(code, event.shift_pressed, event.ctrl_pressed, event.alt_pressed, event.meta_pressed)
	var conflict := _conflict_action(action, candidate)
	if conflict != &"":
		return {"ok": false, "error": "CONFLICT", "conflict_action": conflict}
	_bindings[action] = candidate
	var error := save_settings()
	bindings_changed.emit()
	if error != OK:
		return {"ok": true, "error": "SAVE_FAILED", "conflict_action": &""}
	return {"ok": true, "error": "", "conflict_action": &""}


## 清除一个动作的绑定。## 输入: action (StringName) - 动作标识。
## 输出: Error - 保存结果；未知动作返回 ERR_INVALID_PARAMETER。
func clear_binding(action: StringName) -> Error:
	if not get_actions().has(action):
		return ERR_INVALID_PARAMETER
	_bindings[action] = {}
	var error := save_settings()
	bindings_changed.emit()
	return error


## 恢复全部默认快捷键并保存。## 输入: 无。
## 输出: Error - 保存结果。
func reset_defaults() -> Error:
	_apply_defaults()
	var error := save_settings()
	bindings_changed.emit()
	return error


## 读取配置。缺失或损坏时恢复默认；单条冲突或无法解析时只放弃该条。## 输入: path (String) - 配置路径，空字符串表示沿用当前路径。
## 输出: 无。
func load_settings(path: String = "") -> void:
	if not path.is_empty():
		settings_path = path
	for action: StringName in get_actions():
		_bindings[action] = {}
	var config := ConfigFile.new()
	if not FileAccess.file_exists(settings_path) or config.load(settings_path) != OK:
		_apply_defaults()
		bindings_changed.emit()
		return
	var pending: Array[StringName] = []
	for action: StringName in get_actions():
		var key := String(action)
		if not config.has_section_key("bindings", key):
			pending.append(action)
			continue
		var raw: Variant = config.get_value("bindings", key)
		if not (raw is String):
			pending.append(action)
			continue
		var text := str(raw).strip_edges()
		if text.is_empty():
			_bindings[action] = {}
			continue
		var parsed := parse_binding(text)
		if parsed.is_empty() or _conflicts(action, parsed):
			pending.append(action)
			continue
		_bindings[action] = parsed
	for action: StringName in pending:
		var fallback := _default_binding(action)
		if _conflicts(action, fallback):
			_bindings[action] = {}
		else:
			_bindings[action] = fallback
	bindings_changed.emit()


## 把当前绑定写成独立配置，不碰字号存档。## 输入: 无。
## 输出: Error - 保存结果。
func save_settings() -> Error:
	var config := ConfigFile.new()
	for action: StringName in get_actions():
		config.set_value("bindings", String(action), encode_binding(_bindings.get(action, {})))
	var error := config.save(settings_path)
	if error != OK:
		settings_save_failed.emit(error)
	return error


## 焦点在文本框时，学习键和录制都要把按键留给输入框。## 输入: control (Control) - 当前焦点。
## 输出: bool - 需要让出按键时返回 true。
static func focus_blocks_shortcuts(control: Control) -> bool:
	return control is LineEdit or control is TextEdit


## 开始菜单打开时，Esc 先关闭菜单。## 输入: tree (SceneTree) - 当前场景树。
## 输出: bool - 菜单可见时返回 true。
static func start_menu_blocks(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(&"start_menu"):
		var item := node as CanvasItem
		if item != null and item.visible:
			return true
	return false


## 可见确认框优先处理 Esc。## 输入: node (Node) - 开始查找的节点。
## 输出: bool - 子树中有可见 AcceptDialog 时返回 true。
static func visible_dialog_blocks(node: Node) -> bool:
	if node == null:
		return false
	for child: Node in node.get_children():
		var dialog := child as AcceptDialog
		if dialog != null and dialog.visible:
			return true
		if visible_dialog_blocks(child):
			return true
	return false


## 把存档文本解析成绑定。空字符串和非法文本都返回空字典。## 输入: source (String) - 如 "Ctrl+Shift+F"。
## 输出: Dictionary - 合法绑定时含 keycode 与修饰键。
static func parse_binding(source: String) -> Dictionary:
	var text := source.strip_edges()
	if text.is_empty():
		return {}
	var parts: PackedStringArray = text.split("+", false)
	if parts.is_empty():
		return {}
	var shift := false
	var ctrl := false
	var alt := false
	var meta := false
	var key_token := parts[parts.size() - 1].strip_edges()
	if key_token.is_empty():
		return {}
	for index: int in range(parts.size() - 1):
		match parts[index].strip_edges().to_lower():
			"shift":
				shift = true
			"ctrl", "control":
				ctrl = true
			"alt":
				alt = true
			"meta", "cmd", "command":
				meta = true
			_:
				return {}
	var code := OS.find_keycode_from_string(key_token)
	if code == KEY_NONE or _is_modifier_keycode(code):
		return {}
	return {
		"keycode": code,
		"shift": shift,
		"ctrl": ctrl,
		"alt": alt,
		"meta": meta,
	}


## 写成存档用的英文键名。## 输入: binding (Dictionary) - 当前绑定。
## 输出: String - 未绑定时返回空字符串。
func encode_binding(binding: Dictionary) -> String:
	return format_binding(binding, false)


## 组装修饰键和主键。## 输入:
##   binding (Dictionary) - 当前绑定。
##   localized (bool) - true 时主键使用中文短名。
## 输出: String - 显示或存档文本。
static func format_binding(binding: Dictionary, localized: bool) -> String:
	if binding.is_empty() or int(binding.get("keycode", KEY_NONE)) == KEY_NONE:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if bool(binding.get("ctrl", false)):
		parts.append("Ctrl")
	if bool(binding.get("alt", false)):
		parts.append("Alt")
	if bool(binding.get("shift", false)):
		parts.append("Shift")
	if bool(binding.get("meta", false)):
		parts.append("Meta")
	var code := int(binding.get("keycode", KEY_NONE))
	if localized:
		parts.append(_localized_key(code))
	else:
		parts.append(OS.get_keycode_string(code as Key))
	return "+".join(parts)


## 填入默认键。## 输入: 无。
## 输出: 无。
func _apply_defaults() -> void:
	_bindings.clear()
	for action: StringName in get_actions():
		_bindings[action] = _default_binding(action)


## 返回某个动作的默认绑定副本。## 输入: action (StringName) - 动作标识。
## 输出: Dictionary - 默认绑定。
func _default_binding(action: StringName) -> Dictionary:
	match action:
		ACTION_FLIP:
			return _binding(KEY_SPACE, false, false, false, false)
		ACTION_AGAIN:
			return _binding(KEY_1, false, false, false, false)
		ACTION_HARD:
			return _binding(KEY_2, false, false, false, false)
		ACTION_GOOD:
			return _binding(KEY_3, false, false, false, false)
		ACTION_EASY:
			return _binding(KEY_4, false, false, false, false)
		ACTION_EXIT:
			return _binding(KEY_ESCAPE, false, false, false, false)
		ACTION_SAVE_DOCUMENT:
			return _binding(KEY_S, false, true, false, false)
		_:
			return {}


## 构造一条绑定字典。## 输入: 键码和四个修饰键。
## 输出: Dictionary - 绑定。
func _binding(code: int, shift: bool, ctrl: bool, alt: bool, meta: bool) -> Dictionary:
	return {
		"keycode": code,
		"shift": shift,
		"ctrl": ctrl,
		"alt": alt,
		"meta": meta,
	}


## 判断两条非空绑定是否是同一组合。## 输入: left, right (Dictionary) - 两条绑定。
## 输出: bool - 键码和修饰键都相同才返回 true。
func _same_binding(left: Dictionary, right: Dictionary) -> bool:
	if left.is_empty() or right.is_empty():
		return false
	return int(left.get("keycode", -1)) == int(right.get("keycode", -2)) \
		and bool(left.get("shift", false)) == bool(right.get("shift", false)) \
		and bool(left.get("ctrl", false)) == bool(right.get("ctrl", false)) \
		and bool(left.get("alt", false)) == bool(right.get("alt", false)) \
		and bool(left.get("meta", false)) == bool(right.get("meta", false))


## 检查候选键是否已被其他动作占用。## 输入:
##   action (StringName) - 准备写入的动作。
##   candidate (Dictionary) - 候选绑定。
## 输出: bool - 冲突时返回 true。
func _conflicts(action: StringName, candidate: Dictionary) -> bool:
	return _conflict_action(action, candidate) != &""


## 找到占用候选键的动作。## 输入:
##   action (StringName) - 准备写入的动作。
##   candidate (Dictionary) - 候选绑定。
## 输出: StringName - 占用者；没有冲突时返回空名。
func _conflict_action(action: StringName, candidate: Dictionary) -> StringName:
	for other: StringName in get_actions():
		if other == action:
			continue
		if _same_binding(_bindings.get(other, {}), candidate):
			return other
	return &""


## 修饰键本身不能作为主键。## 输入: code (int) - 键码。
## 输出: bool - Shift、Ctrl、Alt、Meta 返回 true。
static func _is_modifier_keycode(code: int) -> bool:
	return code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META


## 把常见键显示成中文短名。## 输入: code (int) - 键码。
## 输出: String - 短名。
static func _localized_key(code: int) -> String:
	match code:
		KEY_SPACE:
			return "空格"
		KEY_ESCAPE:
			return "Esc"
		KEY_ENTER:
			return "回车"
		KEY_KP_ENTER:
			return "小键盘回车"
		KEY_TAB:
			return "Tab"
		KEY_BACKSPACE:
			return "Backspace"
		KEY_DELETE:
			return "Delete"
		_:
			if code >= KEY_KP_0 and code <= KEY_KP_9:
				return "小键盘 %d" % [code - KEY_KP_0]
			return OS.get_keycode_string(code as Key)
