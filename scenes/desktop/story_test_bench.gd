extends Control
## 调试用剧情测试台。只通过 App 读取状态和提交操作。

const AdaptiveGrid: GDScript = preload("res://src/ui/adaptive_row.gd")

@onready var _chapter_label: Label = %ChapterValue
@onready var _playing_label: Label = %PlayingValue
@onready var _next_label: Label = %NextValue
@onready var _progress_label: Label = %ProgressValue
@onready var _bond_label: Label = %BondValue
@onready var _hint_label: Label = %HintLabel
@onready var _start_button: Button = %StartButton
@onready var _apply_button: Button = %ApplyButton
@onready var _revert_button: Button = %RevertButton
@onready var _clear_button: Button = %ClearButton
@onready var _restore_button: Button = %RestoreButton
@onready var _reset_button: Button = %ResetButton
@onready var _control_list: VBoxContainer = %ControlList
@onready var _progress_spin: SpinBox = %ProgressSpin
@onready var _threshold_spin: SpinBox = %ThresholdSpin
@onready var _bond_spin: SpinBox = %BondSpin
@onready var _tier_label: Label = %TierValue
@onready var _cooldown_label: Label = %CooldownValue
@onready var _derived_box: VBoxContainer = %DerivedBox
@onready var _completion_box: VBoxContainer = %CompletionBox
@onready var _flag_box: VBoxContainer = %FlagBox
@onready var _complex_box: VBoxContainer = %ComplexBox
@onready var _new_flag_name: LineEdit = %NewFlagName
@onready var _path_label: Label = %SavePath
@onready var _snapshot: TextEdit = %Snapshot
@onready var _backup_list: ItemList = %BackupList
@onready var _blocker: Control = %PlaybackBlocker
@onready var _chapter_filter: OptionButton = %ChapterFilter
@onready var _main_tabs: TabContainer = %MainTabs
@onready var _backup_empty: Label = %BackupEmpty

var _draft: Dictionary = {}
var _jump_buttons: Array[Button] = []
var _building: bool = false
var _notice: String = ""


## 连接场景控件并开始跟踪剧情状态。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_connect_controls()
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


## 连接固定布局中的操作控件，动态内容由各列表填充。## 输入: 无。
## 输出: 无。
func _connect_controls() -> void:
	_start_button.pressed.connect(_on_start_next)
	_apply_button.pressed.connect(_on_apply)
	_revert_button.pressed.connect(_on_revert)
	_clear_button.pressed.connect(_on_clear_cooldown)
	_restore_button.pressed.connect(_on_restore_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_progress_spin.value_changed.connect(_on_progress_changed)
	_threshold_spin.value_changed.connect(_on_threshold_changed)
	_bond_spin.value_changed.connect(_on_bond_changed)
	%AddFlagButton.pressed.connect(_on_add_flag)
	%DerivedToggle.toggled.connect(_on_derived_toggled)
	_chapter_filter.item_selected.connect(_on_chapter_selected)
	_main_tabs.tab_changed.connect(_on_tab_changed)
	_backup_list.item_selected.connect(_on_backup_selected)


## 切换只读派生信息，不改变草稿。## 输入: expanded (bool) - 是否展开。
## 输出: 无。
func _on_derived_toggled(expanded: bool) -> void:
	_derived_box.visible = expanded
	%DerivedToggle.text = "收起派生标记（只读）" if expanded else "查看派生标记（只读）"


## 切换主页面后同步底部保存操作。## 输入: _index (int) - 页码。
## 输出: 无。
func _on_tab_changed(_index: int) -> void:
	_refresh_actions()


## 选中备份后更新恢复按钮。## 输入: _index (int) - 列表索引。
## 输出: 无。
func _on_backup_selected(_index: int) -> void:
	_refresh_actions()


## 按所选章节筛选剧情，保留当前存档和编辑草稿。## 输入: _index (int) - 筛选索引。
## 输出: 无。
func _on_chapter_selected(_index: int) -> void:
	_rebuild_catalog()
	%ControlScroll.scroll_vertical = 0
	_refresh_actions()


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


## 按章节筛选重建剧情列表，标题与条件分别显示。## 输入: 无。
## 输出: 无。
func _rebuild_catalog() -> void:
	_building = true
	_clear(_control_list)
	_jump_buttons.clear()
	var catalog: Dictionary = App.get_story_catalog()
	var selected_chapter: String = str(_chapter_filter.get_item_metadata(_chapter_filter.selected)) if _chapter_filter.item_count > 0 else str(_draft.get("current_chapter", ""))
	_chapter_filter.clear()
	_chapter_filter.add_item("全部章节")
	_chapter_filter.set_item_metadata(0, "")
	for chapter: Dictionary in catalog.get("chapters", []):
		_chapter_filter.add_item(str(chapter.get("title", "")))
		var index: int = _chapter_filter.item_count - 1
		_chapter_filter.set_item_metadata(index, str(chapter.get("id", "")))
		if str(chapter.get("id", "")) == selected_chapter:
			_chapter_filter.select(index)
	for chapter: Dictionary in catalog.get("chapters", []):
		if not selected_chapter.is_empty() and str(chapter.get("id", "")) != selected_chapter:
			continue
		var entries: Array = chapter.get("entries", [])
		_control_list.add_child(_label("%s · %d 段剧情" % [str(chapter.get("title", "")), entries.size()], &"UiCaption"))
		var titles: Dictionary = {}
		for entry: Dictionary in entries:
			titles[str(entry.get("key", ""))] = str(entry.get("title", ""))
		for index: int in range(entries.size()):
			_control_list.add_child(_catalog_row(entries[index], index + 1, titles))
	_building = false


## 创建分层剧情行；长标题和前置条件可换行，动作保持独立。## 输入: entry、ordinal、titles。
## 输出: PanelContainer。
func _catalog_row(entry: Dictionary, ordinal: int, titles: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"DesktopStatus"
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var number: Label = _label("%02d" % ordinal, &"UiMuted")
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	details.add_child(_label(str(entry.get("title", "")), &"UiBody"))
	var is_bond: bool = str(entry.get("kind", "")) == "bond"
	var state_text: String = "已完成" if bool(entry.get("completed", false)) else "未完成"
	var metadata: String = "%s · %s" % ["羁绊" if is_bond else "主线", state_text]
	if is_bond:
		var prerequisite: String = str(entry.get("prerequisite", ""))
		metadata += " · 前置：%s · 羁绊等级 %d" % [str(titles.get(prerequisite, prerequisite)), int(entry.get("tier", 0))]
	details.add_child(_label(metadata, &"UiMuted"))
	panel.tooltip_text = "%s/%s\n%s" % [entry.get("chapter", ""), entry.get("key", ""), entry.get("path", "")]
	var action: Button = _button("跳转并播放", _on_jump.bind(str(entry.get("chapter", "")), str(entry.get("key", ""))))
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.tooltip_text = "重排完成记录，保留好感度和分支标记。"
	_jump_buttons.append(action)
	row.add_child(action)
	return panel


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
		_completion_box.add_child(_label(str(chapter.get("title", "")), &"UiBody"))
		var grid: GridContainer = AdaptiveGrid.new() as GridContainer
		grid.preferred_columns = 2
		grid.minimum_column_width = 260.0
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_completion_box.add_child(grid)
		for entry_variant in chapter.get("entries", []):
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			var token := _completion_token(entry)
			seen[token] = true
			grid.add_child(_completion_check(entry, _draft_has_completion(entry)))
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
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_text = true
	box.tooltip_text = box.text
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
	if _flag_box.get_child_count() == 0:
		_flag_box.add_child(_label("暂无自定义标记，可在上方添加。", &"UiMuted"))


## 把标记名与类型、值分行，避免长名称挤压编辑控件。## 输入: flag_name、value。
## 输出: VBoxContainer。
func _flag_row(flag_name: String, value: Variant) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(_label(flag_name, &"UiBody"))
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	section.add_child(row)
	var kind: OptionButton = OptionButton.new()
	for text: String in ["布尔", "数字", "字符串", "空值"]:
		kind.add_item(text)
	kind.selected = _flag_kind(value)
	kind.item_selected.connect(_on_flag_kind_selected.bind(flag_name))
	row.add_child(kind)
	var value_editor: Control = _flag_value_editor(flag_name, value)
	value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_editor.custom_minimum_size.x = 160.0
	row.add_child(value_editor)
	row.add_child(_button("删除", _on_delete_flag.bind(flag_name)))
	section.add_child(HSeparator.new())
	return section


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
			check.text = "启用"
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
	_chapter_label.text = str(state.get("chapter_title", ""))
	_chapter_label.tooltip_text = str(state.get("chapter", ""))
	_playing_label.text = "播放中：" + str(state.get("playing_title", "")) if not str(state.get("playing_key", "")).is_empty() else "待机"
	_next_label.text = _display_story(str(state.get("next_title", "")), str(state.get("next_key", "")))
	_next_label.tooltip_text = _next_label.text
	_progress_label.text = "%d / %d" % [int(state.get("progress", 0)), int(state.get("threshold", 1))]
	_bond_label.text = "%d · %s" % [int(state.get("bond", 0)), str(state.get("tier_name", ""))]
	_path_label.text = "存档位置：%s" % str(state.get("save_path", ""))
	_path_label.tooltip_text = str(state.get("save_path", ""))
	_snapshot.text = App.get_story_snapshot_text()
	_refresh_backups()
	_refresh_cooldown_label()
	_refresh_actions()


## 更新固定操作栏、保存状态和播放遮罩，不重建正在编辑的内容。## 输入: 无。
## 输出: 无。
func _refresh_actions() -> void:
	var state: Dictionary = App.get_story_test_state()
	var busy: bool = bool(state.get("busy", false)) or not bool(state.get("debug", false))
	var dirty: bool = bool(state.get("draft_dirty", false))
	var conflict: bool = bool(state.get("draft_conflict", false)) and dirty
	_start_button.disabled = busy or dirty or str(state.get("next_key", "")).is_empty()
	for action: Button in _jump_buttons:
		action.disabled = busy or dirty
	_apply_button.disabled = busy or not dirty or conflict
	_revert_button.disabled = busy or not dirty
	_clear_button.disabled = busy
	_restore_button.disabled = busy or dirty or _backup_list.get_selected_items().is_empty()
	_reset_button.disabled = busy or dirty
	_chapter_filter.disabled = busy
	_apply_button.visible = _main_tabs.current_tab == 1 or dirty
	_revert_button.visible = _apply_button.visible
	_blocker.visible = bool(state.get("busy", false))
	_hint_label.theme_type_variation = &"UiError" if conflict else &"UiMuted"
	if conflict:
		_hint_label.text = "存档已变化，请撤销后重读。"
	elif dirty:
		_hint_label.text = "有未保存修改"
	elif bool(state.get("busy", false)):
		_hint_label.text = "剧情播放中，测试台已暂停。"
	else:
		_hint_label.text = _notice if not _notice.is_empty() else "就绪 · 存档已同步"
	_hint_label.tooltip_text = _hint_label.text


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


## 显示备份时间与操作来源，完整文件位置保留在提示中。## 输入: 无。
## 输出: 无。
func _refresh_backups() -> void:
	var selected: String = "" if _backup_list.get_selected_items().is_empty() else str(_backup_list.get_item_metadata(_backup_list.get_selected_items()[0]))
	_backup_list.clear()
	var reasons: Dictionary = {"apply": "应用存档", "jump": "跳转剧情", "start": "开启测试", "reset": "重置剧情", "restore": "恢复备份", "migration": "旧档迁移", "migrate": "旧档迁移"}
	for row: Dictionary in App.list_story_backups():
		var stamp: String = Time.get_datetime_string_from_unix_time(int(row.get("modified", 0))).replace("T", " ") + " UTC"
		var filename: String = str(row.get("name", ""))
		var reason: String = filename.get_basename().get_slice("_", filename.get_basename().get_slice_count("_") - 1)
		_backup_list.add_item("%s · %s" % [stamp, str(reasons.get(reason, "剧情备份"))])
		var index: int = _backup_list.item_count - 1
		_backup_list.set_item_metadata(index, str(row.get("path", "")))
		_backup_list.set_item_tooltip(index, str(row.get("path", "")))
		if str(row.get("path", "")) == selected:
			_backup_list.select(index)
	_backup_empty.visible = _backup_list.item_count == 0


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
	_notice = text
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
