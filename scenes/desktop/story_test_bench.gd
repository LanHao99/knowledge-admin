extends Control
## 调试用剧情测试台。只通过 App 读取状态和提交操作。

var _chapter_label: Label
var _playing_label: Label
var _next_label: Label
var _progress_label: Label
var _bond_label: Label
var _hint_label: Label
var _start_button: Button
var _apply_button: Button
var _revert_button: Button
var _clear_button: Button
var _restore_button: Button
var _reset_button: Button
var _control_list: VBoxContainer
var _progress_spin: SpinBox
var _threshold_spin: SpinBox
var _bond_spin: SpinBox
var _tier_label: Label
var _cooldown_label: Label
var _derived_box: VBoxContainer
var _completion_box: VBoxContainer
var _flag_box: VBoxContainer
var _complex_box: VBoxContainer
var _new_flag_name: LineEdit
var _path_label: Label
var _snapshot: TextEdit
var _backup_list: ItemList
var _blocker: Control
var _draft: Dictionary = {}
var _jump_buttons: Array[Button] = []
var _building: bool = false


## 搭建界面并开始跟踪剧情状态。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not App.story_state_changed.is_connected(_on_story_state_changed):
		App.story_state_changed.connect(_on_story_state_changed)
	if not App.dialogue_opened.is_connected(_on_playback_changed):
		App.dialogue_opened.connect(_on_playback_changed)
	if not App.dialogue_closed.is_connected(_on_playback_changed):
		App.dialogue_closed.connect(_on_playback_changed)
	if not App.story_test_stopped.is_connected(_on_test_stopped):
		App.story_test_stopped.connect(_on_test_stopped)
	_load_draft(false)
	_refresh()


## 离开窗口时断开主逻辑信号。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if App.story_state_changed.is_connected(_on_story_state_changed):
		App.story_state_changed.disconnect(_on_story_state_changed)
	if App.dialogue_opened.is_connected(_on_playback_changed):
		App.dialogue_opened.disconnect(_on_playback_changed)
	if App.dialogue_closed.is_connected(_on_playback_changed):
		App.dialogue_closed.disconnect(_on_playback_changed)
	if App.story_test_stopped.is_connected(_on_test_stopped):
		App.story_test_stopped.disconnect(_on_test_stopped)


## 创建状态栏、三个滚动页和播放遮罩。## 输入: 无。
## 输出: 无。
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	root.add_child(_build_status())
	_hint_label = _label("", &"UiMuted")
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint_label)
	var body := Control.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	tabs.add_child(_build_control_page())
	tabs.add_child(_build_editor_page())
	tabs.add_child(_build_backup_page())
	_blocker = ColorRect.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.color = Color(0, 0, 0, 0.28)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	body.add_child(_blocker)
	var blocker_label := _label("剧情播放中", &"UiHeading")
	blocker_label.set_anchors_preset(Control.PRESET_CENTER)
	_blocker.add_child(blocker_label)


## 创建顶部状态文字。## 输入: 无。
## 输出: GridContainer。
func _build_status() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_label = _label("", &"UiBody")
	_playing_label = _label("", &"UiBody")
	_next_label = _label("", &"UiBody")
	_progress_label = _label("", &"UiBody")
	_bond_label = _label("", &"UiBody")
	for text in ["章节", "正在播放", "下一段", "进度 / 阈值", "好感度"]:
		var caption := _label(text, &"UiCaption")
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size = Vector2(220, 0)
		grid.add_child(caption)
		var value := _chapter_label
		match text:
			"正在播放":
				value = _playing_label
			"下一段":
				value = _next_label
			"进度 / 阈值":
				value = _progress_label
			"好感度":
				value = _bond_label
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	return grid


## 创建剧情控制页。## 输入: 无。
## 输出: ScrollContainer。
func _build_control_page() -> ScrollContainer:
	var scroll := _scroll("ControlScroll")
	scroll.name = "剧情控制"
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_start_button = _button("一键开启下一段", _on_start_next)
	box.add_child(_start_button)
	_control_list = VBoxContainer.new()
	_control_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_control_list)
	return scroll


## 创建存档编辑页。## 输入: 无。
## 输出: ScrollContainer。
func _build_editor_page() -> ScrollContainer:
	var scroll := _scroll("EditorScroll")
	scroll.name = "存档编辑"
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_label("章节通过跳转修改。", &"UiCaption"))
	_progress_spin = _spin(0)
	_threshold_spin = _spin(1)
	_bond_spin = _spin(0)
	box.add_child(_number_row("进度", _progress_spin, _on_progress_changed))
	box.add_child(_number_row("触发阈值", _threshold_spin, _on_threshold_changed))
	box.add_child(_number_row("好感度", _bond_spin, _on_bond_changed))
	_tier_label = _label("", &"UiBody")
	box.add_child(_tier_label)
	_derived_box = VBoxContainer.new()
	box.add_child(_derived_box)
	_cooldown_label = _label("", &"UiBody")
	box.add_child(_cooldown_label)
	var actions := HBoxContainer.new()
	_clear_button = _button("清除冷却", _on_clear_cooldown)
	_apply_button = _button("应用并保存", _on_apply)
	_revert_button = _button("撤销修改", _on_revert)
	actions.add_child(_clear_button)
	actions.add_child(_apply_button)
	actions.add_child(_revert_button)
	box.add_child(actions)
	box.add_child(_label("完成记录", &"UiHeading"))
	_completion_box = VBoxContainer.new()
	box.add_child(_completion_box)
	box.add_child(_label("剧情标记", &"UiHeading"))
	_flag_box = VBoxContainer.new()
	box.add_child(_flag_box)
	var add_row := HBoxContainer.new()
	_new_flag_name = LineEdit.new()
	_new_flag_name.placeholder_text = "新标记名"
	_new_flag_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_new_flag_name)
	add_row.add_child(_button("添加标记", _on_add_flag))
	box.add_child(add_row)
	box.add_child(_label("复杂标记只读保留", &"UiCaption"))
	_complex_box = VBoxContainer.new()
	box.add_child(_complex_box)
	return scroll


## 创建备份页。## 输入: 无。
## 输出: ScrollContainer。
func _build_backup_page() -> ScrollContainer:
	var scroll := _scroll("BackupScroll")
	scroll.name = "备份"
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_path_label = _label("", &"UiCaption")
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_path_label)
	_snapshot = TextEdit.new()
	_snapshot.editable = false
	_snapshot.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_snapshot.custom_minimum_size = Vector2(0, 220)
	_snapshot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_snapshot)
	_backup_list = ItemList.new()
	_backup_list.custom_minimum_size = Vector2(0, 160)
	_backup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_backup_list)
	var actions := HBoxContainer.new()
	_restore_button = _button("恢复所选备份", _on_restore_pressed)
	_reset_button = _button("重置剧情", _on_reset_pressed)
	actions.add_child(_restore_button)
	actions.add_child(_reset_button)
	box.add_child(actions)
	return scroll


## 创建纵向滚动容器。## 输入: node_name。
## 输出: ScrollContainer。
func _scroll(node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


## 创建跟随主题字号的标签。## 输入: text、variation。
## 输出: Label。
func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## 创建按钮并接上回调。## 输入: text、callback。
## 输出: Button。
func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


## 创建整数输入框。## 输入: minimum。
## 输出: SpinBox。
func _spin(minimum: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = 10000000
	spin.step = 1
	spin.rounded = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


## 创建数字编辑行。## 输入: caption、spin、callback。
## 输出: HBoxContainer。
func _number_row(caption: String, spin: SpinBox, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption_label := _label(caption, &"UiBody")
	caption_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(caption_label)
	row.add_child(spin)
	spin.value_changed.connect(callback)
	return row


## 重新读取真实存档到草稿。## 输入: announce。
## 输出: 无。
func _load_draft(announce: bool) -> void:
	_draft = App.read_story_draft()
	_rebuild_editor()
	_rebuild_catalog()
	if announce:
		_set_hint("已撤销修改")
	_refresh()


## 把草稿交回 App，供脏检查和保存使用。## 输入: 无。
## 输出: 无。
func _push_draft() -> void:
	if _building:
		return
	App.update_story_draft(_draft)
	_refresh_actions()


## 按目录重建剧情列表。## 输入: 无。
## 输出: 无。
func _rebuild_catalog() -> void:
	_building = true
	_clear(_control_list)
	_jump_buttons.clear()
	var catalog: Dictionary = App.get_story_catalog()
	for chapter_variant in catalog.get("chapters", []):
		if typeof(chapter_variant) != TYPE_DICTIONARY:
			continue
		var chapter: Dictionary = chapter_variant
		_control_list.add_child(_label(str(chapter.get("title", "")), &"UiHeading"))
		for entry_variant in chapter.get("entries", []):
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			_control_list.add_child(_catalog_row(entry_variant))
	_building = false


## 创建一条剧情和它的跳转按钮。## 输入: entry。
## 输出: HBoxContainer。
func _catalog_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var kind := "羁绊" if str(entry.get("kind", "")) == "bond" else "主线"
	var state := "已完成" if bool(entry.get("completed", false)) else "未完成"
	var title := "%s　%s　%s" % [str(entry.get("title", "")), kind, state]
	if str(entry.get("kind", "")) == "bond":
		title += "　前置 %s / 羁绊 %d" % [str(entry.get("prerequisite", "")), int(entry.get("tier", 0))]
	var label := _label(title, &"UiBody")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := _button("跳转并播放", _on_jump.bind(str(entry.get("chapter", "")), str(entry.get("key", ""))))
	_jump_buttons.append(button)
	row.add_child(button)
	return row


## 按草稿重建编辑控件，不触发新的修改。## 输入: 无。
## 输出: 无。
func _rebuild_editor() -> void:
	_building = true
	_progress_spin.set_value_no_signal(float(int(_draft.get("total_progress", 0))))
	_threshold_spin.set_value_no_signal(float(maxi(1, int(_draft.get("trigger_threshold", 1)))))
	_bond_spin.set_value_no_signal(float(int(_draft.get("bond", 0))))
	_rebuild_completions()
	_rebuild_flags()
	_refresh_derived()
	_building = false


## 重建完成记录勾选框，包含目录外的未知记录。## 输入: 无。
## 输出: 无。
func _rebuild_completions() -> void:
	_clear(_completion_box)
	var seen: Dictionary = {}
	var catalog: Dictionary = App.get_story_catalog()
	for chapter_variant in catalog.get("chapters", []):
		if typeof(chapter_variant) != TYPE_DICTIONARY:
			continue
		var chapter: Dictionary = chapter_variant
		for entry_variant in chapter.get("entries", []):
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			var token := _completion_token(entry)
			seen[token] = true
			_completion_box.add_child(_completion_check(entry, _draft_has_completion(entry)))
	_add_unknown_completions("completed_dialogues", seen, "main")
	_add_unknown_completions("bond_dialogues_triggered", seen, "bond")


## 为未知完成记录补勾选框。## 输入: field、seen、kind。
## 输出: 无。
func _add_unknown_completions(field: String, seen: Dictionary, kind: String) -> void:
	for item in _draft.get(field, []):
		var record := str(item)
		if seen.has(record):
			continue
		seen[record] = true
		var entry := {"title": record, "kind": kind, "key": record, "record": record, "chapter": ""}
		_completion_box.add_child(_completion_check(entry, true))


## 创建一条完成记录勾选框。## 输入: entry、pressed。
## 输出: CheckBox。
func _completion_check(entry: Dictionary, pressed: bool) -> CheckBox:
	var box := CheckBox.new()
	var kind := "羁绊" if str(entry.get("kind", "")) == "bond" else "主线"
	box.text = "%s（%s）" % [str(entry.get("title", "")), kind]
	box.button_pressed = pressed
	box.set_meta("entry", entry)
	box.toggled.connect(_on_completion_toggled.bind(box))
	return box


## 重建可编辑标记和只读复杂标记。## 输入: 无。
## 输出: 无。
func _rebuild_flags() -> void:
	_clear(_flag_box)
	_clear(_complex_box)
	var flags: Dictionary = _draft.get("flags", {})
	for key_variant in flags.keys():
		var name := str(key_variant)
		if StoryCatalog.is_derived_flag(name):
			continue
		var value: Variant = flags[key_variant]
		if StoryCatalog.is_complex_value(value):
			var label := _label("%s（只读） %s" % [name, JSON.stringify(value)], &"UiCaption")
			_complex_box.add_child(label)
		else:
			_flag_box.add_child(_flag_row(name, value))


## 创建一条普通标记编辑行。## 输入: flag_name、value。
## 输出: HBoxContainer。
func _flag_row(flag_name: String, value: Variant) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := _label(flag_name, &"UiBody")
	name_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(name_label)
	var kind := OptionButton.new()
	for text in ["布尔", "数字", "字符串", "空值"]:
		kind.add_item(text)
	kind.selected = _flag_kind(value)
	kind.item_selected.connect(_on_flag_kind_selected.bind(flag_name))
	row.add_child(kind)
	row.add_child(_flag_value_editor(flag_name, value))
	row.add_child(_button("删除", _on_delete_flag.bind(flag_name)))
	return row


## 按标记值选择编辑器类型。## 输入: value。
## 输出: int。0 布尔，1 数字，2 字符串，3 空值。
func _flag_kind(value: Variant) -> int:
	match typeof(value):
		TYPE_BOOL:
			return 0
		TYPE_INT, TYPE_FLOAT:
			return 1
		TYPE_STRING:
			return 2
		_:
			return 3


## 创建标记值编辑控件。## 输入: flag_name、value。
## 输出: Control。
func _flag_value_editor(flag_name: String, value: Variant) -> Control:
	match _flag_kind(value):
		0:
			var check := CheckButton.new()
			check.button_pressed = bool(value)
			check.toggled.connect(func(pressed: bool) -> void: _set_flag_value(flag_name, pressed))
			return check
		1:
			var spin := SpinBox.new()
			spin.min_value = -10000000
			spin.max_value = 10000000
			spin.step = 1
			spin.rounded = true
			spin.value = float(value)
			spin.value_changed.connect(func(next: float) -> void: _set_flag_value(flag_name, int(next)))
			return spin
		2:
			var edit := LineEdit.new()
			edit.text = str(value)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(next: String) -> void: _set_flag_value(flag_name, next))
			return edit
		_:
			return _label("空", &"UiCaption")


## 刷新状态、按钮、备份文本和遮罩。## 输入: 无。
## 输出: 无。
func _refresh() -> void:
	var state: Dictionary = App.get_story_test_state()
	_chapter_label.text = "%s（%s）" % [str(state.get("chapter_title", "")), str(state.get("chapter", ""))]
	_playing_label.text = _display_story(str(state.get("playing_title", "")), str(state.get("playing_key", "")))
	_next_label.text = _display_story(str(state.get("next_title", "")), str(state.get("next_key", "")))
	_progress_label.text = "%d / %d" % [int(state.get("progress", 0)), int(state.get("threshold", 1))]
	_bond_label.text = "%d　%s（%d）" % [int(state.get("bond", 0)), str(state.get("tier_name", "")), int(state.get("tier", 0))]
	_path_label.text = "存档路径：%s" % str(state.get("save_path", ""))
	_snapshot.text = App.get_story_snapshot_text()
	_refresh_backups()
	_refresh_cooldown_label()
	_refresh_actions()


## 只更新按钮、提示和遮罩。## 输入: 无。
## 输出: 无。
func _refresh_actions() -> void:
	var state: Dictionary = App.get_story_test_state()
	var busy := bool(state.get("busy", false)) or not bool(state.get("debug", false))
	var dirty := bool(state.get("draft_dirty", false))
	var blocked := busy or dirty
	_start_button.disabled = blocked
	for button in _jump_buttons:
		button.disabled = blocked
	_apply_button.disabled = busy or not dirty
	_revert_button.disabled = not dirty
	_clear_button.disabled = busy
	_restore_button.disabled = busy
	_reset_button.disabled = busy
	_blocker.visible = bool(state.get("busy", false))
	if bool(state.get("draft_conflict", false)) and dirty:
		_hint_label.text = "剧情状态已变化，请重新读取"
	elif dirty:
		_hint_label.text = "有未保存修改。应用或撤销后才能启动剧情。"
	elif bool(state.get("busy", false)):
		_hint_label.text = "剧情播放中，测试台已暂停。"
	elif _hint_label.text == "剧情播放中，测试台已暂停。":
		_hint_label.text = ""


## 按草稿显示冷却。## 输入: 无。
## 输出: 无。
func _refresh_cooldown_label() -> void:
	var last := float(_draft.get("last_triggered_at", 0.0))
	if last <= 0.0:
		_cooldown_label.text = "冷却：已清除"
	else:
		_cooldown_label.text = "上次触发：%s" % Time.get_datetime_string_from_unix_time(int(last))


## 按草稿中的好感度显示只读羁绊等级和派生标记。## 输入: 无。
## 输出: 无。
func _refresh_derived() -> void:
	_clear(_derived_box)
	var probe := StoryProgress.new()
	probe.bond = int(_draft.get("bond", 0))
	probe.sync_bond_flags()
	_tier_label.text = "羁绊等级：%s（%d）" % [probe.get_bond_tier_name(), probe.get_bond_tier()]
	for flag_name in StoryCatalog.DERIVED_FLAGS:
		_derived_box.add_child(_label("%s = %s（只读）" % [flag_name, str(probe.flags.get(flag_name))], &"UiCaption"))


## 按时间刷新备份列表。## 输入: 无。
## 输出: 无。
func _refresh_backups() -> void:
	var selected := "" if _backup_list.get_selected_items().is_empty() else str(_backup_list.get_item_metadata(_backup_list.get_selected_items()[0]))
	_backup_list.clear()
	for row in App.list_story_backups():
		var stamp := Time.get_datetime_string_from_unix_time(int(row.get("modified", 0)))
		_backup_list.add_item("%s  %s" % [stamp, str(row.get("name", ""))])
		var index := _backup_list.item_count - 1
		_backup_list.set_item_metadata(index, str(row.get("path", "")))
		if str(row.get("path", "")) == selected:
			_backup_list.select(index)


## 真实状态变化后，没有本地修改就重新读取。## 输入: 无。
## 输出: 无。
func _on_story_state_changed() -> void:
	if App.has_story_draft_conflict():
		if not App.is_story_draft_dirty():
			_load_draft(false)
			return
		_refresh()
		return
	_refresh()


## 播放开始或结束后刷新暂停状态。## 输入: _dialogue_key。
## 输出: 无。
func _on_playback_changed(_dialogue_key: String) -> void:
	_refresh()


## 停止测试后显示原因。## 输入: reason。
## 输出: 无。
func _on_test_stopped(reason: String) -> void:
	_set_hint(reason)
	_refresh()


## 开启下一段。## 输入: 无。
## 输出: 无。
func _on_start_next() -> void:
	_report(App.start_next_story(), "已开启下一段")


## 跳转并播放所选剧情。## 输入: chapter、key。
## 输出: 无。
func _on_jump(chapter: String, key: String) -> void:
	_report(App.jump_to_story(chapter, key), "已跳转并播放")


## 把进度写进草稿。## 输入: value。
## 输出: 无。
func _on_progress_changed(value: float) -> void:
	if _building:
		return
	_draft["total_progress"] = int(value)
	_push_draft()


## 把触发阈值写进草稿。## 输入: value。
## 输出: 无。
func _on_threshold_changed(value: float) -> void:
	if _building:
		return
	_draft["trigger_threshold"] = maxi(1, int(value))
	_push_draft()


## 把好感度写进草稿，并刷新只读羁绊等级。## 输入: value。
## 输出: 无。
func _on_bond_changed(value: float) -> void:
	if _building:
		return
	_draft["bond"] = int(value)
	_refresh_derived()
	_push_draft()


## 在草稿中清除冷却时间。## 输入: 无。
## 输出: 无。
func _on_clear_cooldown() -> void:
	_draft["last_triggered_at"] = 0.0
	_refresh_cooldown_label()
	_push_draft()


## 校验、备份并保存草稿。## 输入: 无。
## 输出: 无。
func _on_apply() -> void:
	_push_draft()
	var result: Dictionary = App.apply_story_draft()
	if result.success:
		_load_draft(false)
		_set_hint("已应用并保存")
	else:
		_set_hint(str(result.get("message", "保存失败")))
		_refresh()


## 丢弃草稿并重新读取。## 输入: 无。
## 输出: 无。
func _on_revert() -> void:
	_load_draft(true)


## 切换一条完成记录。## 输入: pressed、box。
## 输出: 无。
func _on_completion_toggled(pressed: bool, box: CheckBox) -> void:
	if _building:
		return
	var entry: Dictionary = box.get_meta("entry")
	var field := "bond_dialogues_triggered" if str(entry.get("kind", "")) == "bond" else "completed_dialogues"
	var token := _completion_token(entry)
	var rows: Array = []
	for item in _draft.get(field, []):
		rows.append(str(item))
	rows.erase(token)
	rows.erase(str(entry.get("key", "")))
	rows.erase(str(entry.get("record", "")))
	if pressed:
		rows.append(token)
	_draft[field] = rows
	_push_draft()


## 切换标记类型并重建这一行的值编辑器。## 输入: index、flag_name。
## 输出: 无。
func _on_flag_kind_selected(index: int, flag_name: String) -> void:
	if _building:
		return
	match index:
		0:
			_set_flag_value(flag_name, false)
		1:
			_set_flag_value(flag_name, 0)
		2:
			_set_flag_value(flag_name, "")
		_:
			_set_flag_value(flag_name, null)
	_rebuild_flags()


## 写入一个普通标记。## 输入: flag_name、value。
## 输出: 无。
func _set_flag_value(flag_name: String, value: Variant) -> void:
	if _building:
		return
	var flags: Dictionary = _draft.get("flags", {})
	flags[flag_name] = value
	_draft["flags"] = flags
	_push_draft()


## 添加一个默认关闭的布尔标记。## 输入: 无。
## 输出: 无。
func _on_add_flag() -> void:
	var flag_name := _new_flag_name.text.strip_edges()
	var flags: Dictionary = _draft.get("flags", {})
	if flag_name.is_empty() or flags.has(flag_name):
		_set_hint("标记名不能为空或重复")
		return
	flags[flag_name] = false
	_draft["flags"] = flags
	_new_flag_name.text = ""
	_rebuild_flags()
	_push_draft()


## 从草稿删除一个普通标记。## 输入: flag_name。
## 输出: 无。
func _on_delete_flag(flag_name: String) -> void:
	var flags: Dictionary = _draft.get("flags", {})
	flags.erase(flag_name)
	_draft["flags"] = flags
	_rebuild_flags()
	_push_draft()


## 询问后恢复所选备份。## 输入: 无。
## 输出: 无。
func _on_restore_pressed() -> void:
	var selected: PackedInt32Array = _backup_list.get_selected_items()
	if selected.is_empty():
		_set_hint("请先选择一份备份")
		return
	var path := str(_backup_list.get_item_metadata(selected[0]))
	_confirm("恢复备份", "恢复会覆盖当前剧情，并先备份现在的状态。确定继续？", _restore_backup.bind(path))


## 执行备份恢复。## 输入: path。
## 输出: 无。
func _restore_backup(path: String) -> void:
	var result: Dictionary = App.restore_story_backup(path)
	if result.success:
		_load_draft(false)
		_set_hint("已恢复备份")
	else:
		_set_hint(str(result.get("message", "恢复失败")))
		_refresh()


## 询问后只重置剧情数据。## 输入: 无。
## 输出: 无。
func _on_reset_pressed() -> void:
	_confirm("重置剧情", "只清空剧情进度、好感度、标记和完成记录，不会重置教程。确定继续？", _reset_story)


## 执行剧情重置。## 输入: 无。
## 输出: 无。
func _reset_story() -> void:
	var result: Dictionary = App.reset_story_data()
	if result.success:
		_load_draft(false)
		_set_hint("已重置剧情")
	else:
		_set_hint(str(result.get("message", "重置失败")))
		_refresh()


## 弹出游戏内确认框。## 输入: title、text、callback。
## 输出: 无。
func _confirm(title: String, text: String, callback: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.confirmed.connect(callback)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


## 显示操作结果；失败时保留服务返回的原因。## 输入: result、success_text。
## 输出: 无。
func _report(result: Dictionary, success_text: String) -> void:
	if result.success:
		_set_hint(success_text)
	else:
		_set_hint(str(result.get("message", "操作失败")))
	_refresh()


## 设置页面提示。## 输入: text。
## 输出: 无。
func _set_hint(text: String) -> void:
	_hint_label.text = text


## 返回完成记录在草稿数组中的标识。## 输入: entry。
## 输出: String。羁绊用剧情标识，主线用章节记录。
func _completion_token(entry: Dictionary) -> String:
	if str(entry.get("kind", "")) == "bond":
		return str(entry.get("key", ""))
	var record := str(entry.get("record", ""))
	return record if not record.is_empty() else str(entry.get("key", ""))


## 草稿里是否已经包含这条完成记录。## 输入: entry。
## 输出: bool。
func _draft_has_completion(entry: Dictionary) -> bool:
	var field := "bond_dialogues_triggered" if str(entry.get("kind", "")) == "bond" else "completed_dialogues"
	var token := _completion_token(entry)
	for item in _draft.get(field, []):
		if str(item) == token:
			return true
	return false


## 空标题时显示“无”。## 输入: title、key。
## 输出: String。
func _display_story(title: String, key: String) -> String:
	if title.is_empty() and key.is_empty():
		return "无"
	if title.is_empty():
		return key
	return title


## 立即释放容器中的子节点。## 输入: node。
## 输出: 无。
func _clear(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		node.remove_child(child)
		child.free()
