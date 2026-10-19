extends Control
## 从预设资源生成虚拟目录，并编辑其中的文本文档。
## 玩家修改写入 user:// 覆盖档，不改预设资源，也不写真实磁盘目录。

const SELECTION_HINT: String = "选择左侧的文本文件以查看内容。"
const SAVE_PATH: String = "user://my_computer_documents.cfg"
const STATUS_CLEAN: String = "系统盘 (C:)    /    预设文件"
const STATUS_DIRTY: String = "未保存"
const STATUS_SAVE_FAILED: String = "保存失败，修改仍保留在窗口中。"
const DIRTY_SUFFIX: String = "*"

@export var file_catalog: DesktopFileCatalog

var documents_path: String = SAVE_PATH

var _baselines: Dictionary = {}
var _saved: Dictionary = {}
var _working: Dictionary = {}
var _file_items: Dictionary = {}
var _current_name: String = ""
var _applying_text: bool = false
var _close_dialog: ConfirmationDialog
var _pending_close: Callable = Callable()
var _close_choice: StringName = &""


## 读取覆盖档并生成目录。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	var overrides: Dictionary = _load_overrides()
	var tree: Tree = %DirList
	var root_item: TreeItem = tree.create_item()
	root_item.set_text(0, "我的电脑")
	var drive: TreeItem = tree.create_item(root_item)
	drive.set_text(0, "系统盘 (C:)")
	var programs: TreeItem = tree.create_item(drive)
	programs.set_text(0, "程序")
	var documents: TreeItem = tree.create_item(drive)
	documents.set_text(0, "文档")
	if file_catalog != null:
		drive.set_metadata(0, file_catalog.drive_description)
		programs.set_metadata(0, file_catalog.programs_description)
		for document: DesktopTextFile in file_catalog.documents:
			if document == null or document.file_name.is_empty() or _working.has(document.file_name):
				continue
			var file_name: String = document.file_name
			var baseline: String = document.content
			var saved: String = str(overrides[file_name]) if overrides.has(file_name) else baseline
			_baselines[file_name] = baseline
			_saved[file_name] = saved
			_working[file_name] = saved
			var file_item: TreeItem = tree.create_item(documents)
			file_item.set_metadata(0, {"file_name": file_name})
			_file_items[file_name] = file_item
			_refresh_file_label(file_name)
	var editor: TextEdit = %FileContent
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.editable = false
	editor.text_changed.connect(_on_text_changed)
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_selected)
	drive.select(0)
	_on_item_selected()


## 当前窗口用已注册的保存键写入正在编辑的文档。文本框焦点不拦截。## 输入: event (InputEvent) - 输入事件。
## 输出: 无。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed:
		return
	var sample: InputEventKey = key.duplicate() as InputEventKey
	sample.echo = false
	if ShortcutSettings.match_action(sample) != ShortcutSettings.ACTION_SAVE_DOCUMENT:
		return
	if not _save_shortcut_allowed():
		return
	get_viewport().set_input_as_handled()
	if key.echo:
		return
	var error: Error = save_current_document()
	if error == ERR_UNCONFIGURED:
		return
	if error != OK:
		_set_status(STATUS_SAVE_FAILED)
		return
	_refresh_status()


## 是否还有未写入覆盖档的文档。## 输入: 无。
## 输出: bool - 有草稿时返回 true。
func has_unsaved_documents() -> bool:
	_sync_editor_into_working()
	for file_name: String in _working.keys():
		if _is_dirty(file_name):
			return true
	return false


## 把当前文档写入覆盖档。没有打开文档时不写文件。## 输入: 无。
## 输出: Error - 成功、没有当前文档，或配置写入失败。
func save_current_document() -> Error:
	_sync_editor_into_working()
	if _current_name.is_empty():
		return ERR_UNCONFIGURED
	return _persist_document(_current_name)


## 写入全部未保存文档。## 输入: 无。
## 输出: Error - 第一份失败的结果；没有草稿时返回 OK。
func save_all_documents() -> Error:
	_sync_editor_into_working()
	for file_name: String in _working.keys():
		if not _is_dirty(file_name):
			continue
		var error: Error = _persist_document(file_name)
		if error != OK:
			return error
	return OK


## 丢弃全部草稿并回到上次保存的正文。## 输入: 无。
## 输出: 无。
func discard_unsaved_documents() -> void:
	for file_name: String in _working.keys():
		_working[file_name] = _saved[file_name]
		_refresh_file_label(file_name)
	if _current_name.is_empty():
		_refresh_status()
		return
	_show_document(_current_name)


## 没有草稿时立即关闭；否则询问保存、不保存或取消。## 输入: proceed (Callable) - 保存或放弃后继续关闭。
## 输出: 无。
func desktop_request_close(proceed: Callable) -> void:
	if not has_unsaved_documents():
		if proceed.is_valid():
			proceed.call()
		return
	if is_instance_valid(_close_dialog):
		return
	_pending_close = proceed
	_close_choice = &""
	_close_dialog = ConfirmationDialog.new()
	_close_dialog.title = "保存文档"
	_close_dialog.dialog_text = "有文档尚未保存。要在关闭前保存吗？"
	_close_dialog.ok_button_text = "保存"
	_close_dialog.cancel_button_text = "取消"
	_close_dialog.add_button("不保存", true, "discard")
	_close_dialog.confirmed.connect(_on_close_save)
	_close_dialog.custom_action.connect(_on_close_custom_action)
	_close_dialog.canceled.connect(_on_close_cancel)
	add_child(_close_dialog)
	_close_dialog.popup_centered()


## 显示所选目录说明或文档草稿。先收下当前编辑器里的文字。## 输入: 无。
## 输出: 无。
func _on_item_selected() -> void:
	_sync_editor_into_working()
	var selected: TreeItem = %DirList.get_selected()
	if selected == null:
		return
	var content: Variant = selected.get_metadata(0)
	if content is Dictionary and content.has("file_name"):
		_show_document(str(content["file_name"]))
		return
	_show_readonly(str(content) if content is String else SELECTION_HINT)


## 把编辑器内容记入当前文档的工作副本。## 输入: 无。
## 输出: 无。
func _on_text_changed() -> void:
	_sync_editor_into_working()


## 编辑器改动可能晚一帧才发信号，保存和关闭前直接读取正文。## 输入: 无。
## 输出: 无。
func _sync_editor_into_working() -> void:
	if _applying_text or _current_name.is_empty():
		return
	var editor: TextEdit = %FileContent
	if not editor.editable:
		return
	var text: String = editor.text
	if str(_working.get(_current_name, "")) == text:
		return
	_working[_current_name] = text
	_refresh_file_label(_current_name)
	_refresh_status()


## 保存后继续关闭。失败时留下窗口和对话框结果。## 输入: 无。
## 输出: 无。
func _on_close_save() -> void:
	_close_choice = &"save"
	var error: Error = save_all_documents()
	var proceed: Callable = _pending_close
	_pending_close = Callable()
	_release_close_dialog()
	_close_choice = &""
	if error != OK:
		_set_status(STATUS_SAVE_FAILED)
		return
	if proceed.is_valid():
		proceed.call()


## 不保存并继续关闭。## 输入: action (StringName) - 对话框自定义按钮。
## 输出: 无。
func _on_close_custom_action(action: StringName) -> void:
	if action != &"discard" or _close_choice != &"":
		return
	_close_choice = &"discard"
	discard_unsaved_documents()
	var proceed: Callable = _pending_close
	_pending_close = Callable()
	_release_close_dialog()
	_close_choice = &""
	if proceed.is_valid():
		proceed.call()


## 取消关闭。保存或不保存已经处理时忽略随后的关闭信号。## 输入: 无。
## 输出: 无。
func _on_close_cancel() -> void:
	if _close_choice != &"":
		return
	_close_choice = &"cancel"
	_pending_close = Callable()
	_release_close_dialog()
	_close_choice = &""


## 我的电脑位于前台，且没有开始菜单或确认框时才保存。## 输入: 无。
## 输出: bool - 可以保存时返回 true。
func _save_shortcut_allowed() -> bool:
	if not is_visible_in_tree():
		return false
	if WindowManager.is_available():
		if WindowManager.get_active_app_id() != "my_computer":
			return false
		var window: ManagedWindow = WindowManager.get_app_window("my_computer")
		if window == null or not window.is_ancestor_of(self):
			return false
	if ShortcutSettings.start_menu_blocks(get_tree()):
		return false
	if ShortcutSettings.visible_dialog_blocks(get_tree().root):
		return false
	return true


## 打开可编辑文档。## 输入: file_name (String) - 目录中的文件名。
## 输出: 无。
func _show_document(file_name: String) -> void:
	_current_name = file_name
	_applying_text = true
	%FileContent.editable = true
	%FileContent.text = str(_working.get(file_name, ""))
	_applying_text = false
	_refresh_status()


## 显示目录说明，禁止编辑。## 输入: text (String) - 说明或选择提示。
## 输出: 无。
func _show_readonly(text: String) -> void:
	_current_name = ""
	_applying_text = true
	%FileContent.editable = false
	%FileContent.text = text
	_applying_text = false
	_refresh_status()


## 工作副本与已保存正文不同。## 输入: file_name (String) - 文件名。
## 输出: bool - 不同时返回 true。
func _is_dirty(file_name: String) -> bool:
	return str(_working.get(file_name, "")) != str(_saved.get(file_name, ""))


## 在文件名末尾标出未保存草稿。## 输入: file_name (String) - 文件名。
## 输出: 无。
func _refresh_file_label(file_name: String) -> void:
	var item: TreeItem = _file_items.get(file_name) as TreeItem
	if item == null:
		return
	var suffix: String = DIRTY_SUFFIX if _is_dirty(file_name) else ""
	item.set_text(0, file_name + suffix)


## 当前文档有草稿时提示未保存。## 输入: 无。
## 输出: 无。
func _refresh_status() -> void:
	if not _current_name.is_empty() and _is_dirty(_current_name):
		_set_status(STATUS_DIRTY)
		return
	_set_status(STATUS_CLEAN)


## 替换状态行文字。## 输入: message (String) - 要显示的状态。
## 输出: 无。
func _set_status(message: String) -> void:
	%InfoLabel.text = message


## 读取玩家覆盖档。文件缺失或损坏时当作没有覆盖。## 输入: 无。
## 输出: Dictionary - 文件名到正文。
func _load_overrides() -> Dictionary:
	var loaded: Dictionary = {}
	if not FileAccess.file_exists(documents_path):
		return loaded
	var config: ConfigFile = ConfigFile.new()
	if config.load(documents_path) != OK or not config.has_section("documents"):
		return loaded
	for key: String in config.get_section_keys("documents"):
		var value: Variant = config.get_value("documents", key)
		if value is String:
			loaded[key] = value
	return loaded


## 写入一份文档。与预设相同则删除覆盖项。## 输入: file_name (String) - 文件名。
## 输出: Error - 配置读写结果。
func _persist_document(file_name: String) -> Error:
	var config: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(documents_path):
		var read_error: Error = config.load(documents_path)
		if read_error != OK:
			return read_error
	var text: String = str(_working.get(file_name, ""))
	if text == str(_baselines.get(file_name, "")):
		if config.has_section_key("documents", file_name):
			config.erase_section_key("documents", file_name)
	else:
		config.set_value("documents", file_name, text)
	var write_error: Error = config.save(documents_path)
	if write_error != OK:
		return write_error
	_saved[file_name] = text
	_refresh_file_label(file_name)
	return OK


## 关掉保存询问。## 输入: 无。
## 输出: 无。
func _release_close_dialog() -> void:
	if not is_instance_valid(_close_dialog):
		return
	var dialog: ConfirmationDialog = _close_dialog
	_close_dialog = null
	dialog.hide()
	dialog.queue_free()
