extends GutTest
## 验证预设资源、目录生成、文档编辑与覆盖档，不使用玩家存档。

const VIEW_SCENE: PackedScene = preload("res://scenes/desktop/my_computer.tscn")

var _documents_path: String = ""


## 每项测试使用单独的覆盖档。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_documents_path = "user://my_computer_test_%d.cfg" % Time.get_ticks_usec()


## 删除测试覆盖档。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	_remove_documents(_documents_path)


## 场景必须绑定包含现有两份文档的原生资源。## 输入: 无。输出: 无。
func test_default_scene_binds_existing_documents() -> void:
	var view: Control = _open_view(false)
	var catalog: DesktopFileCatalog = view.file_catalog as DesktopFileCatalog
	assert_not_null(catalog)
	assert_eq(catalog.resource_path, "res://data/desktop/my_computer_files.tres")
	assert_eq(catalog.documents.size(), 2)
	assert_eq(catalog.documents[0].file_name, "使用说明.txt")
	assert_eq(catalog.documents[1].file_name, "学习指南.txt")
	assert_eq(view.get_node("%FileContent").text, catalog.drive_description)


## 新增资源条目应自动出现在目录中，选中后显示完整多行正文。## 输入: 无。输出: 无。
func test_resource_entry_populates_directory_and_viewer() -> void:
	var document: DesktopTextFile = DesktopTextFile.new()
	document.file_name = "新的说明.txt"
	document.content = "第一行\n\n第二段"
	var catalog: DesktopFileCatalog = DesktopFileCatalog.new()
	catalog.documents = [document]
	var view: Control = _open_view(true, catalog)
	var tree: Tree = view.get_node("%DirList") as Tree
	var drive: TreeItem = tree.get_root().get_first_child()
	var documents: TreeItem = drive.get_first_child().get_next()
	var file_item: TreeItem = documents.get_first_child()
	assert_not_null(file_item)
	assert_eq(file_item.get_text(0), document.file_name)
	file_item.select(0)
	tree.item_selected.emit()
	assert_eq(view.get_node("%FileContent").text, document.content)
	assert_null(file_item.get_next())


## 缺失资源时仍可打开空目录，显示提示而不是崩溃。## 输入: 无。输出: 无。
func test_missing_catalog_keeps_viewer_usable() -> void:
	var view: Control = _open_view(true, null)
	assert_eq(view.get_node("%FileContent").text, view.SELECTION_HINT)
	var tree: Tree = view.get_node("%DirList") as Tree
	var documents: TreeItem = tree.get_root().get_first_child().get_first_child().get_next()
	assert_null(documents.get_first_child())


## 编辑后标出未保存，Ctrl+S 写入覆盖档，再次打开仍是新正文。## 输入: 无。
## 输出: 无。
func test_edit_and_shortcut_save_round_trip() -> void:
	var document: DesktopTextFile = DesktopTextFile.new()
	document.file_name = "笔记.txt"
	document.content = "原文"
	var catalog: DesktopFileCatalog = DesktopFileCatalog.new()
	catalog.documents = [document]
	var view: Control = _open_view(true, catalog)
	var editor: TextEdit = _select_document(view, document.file_name)
	assert_true(editor.editable)
	editor.text = "改过的正文"
	assert_true(view.has_unsaved_documents())
	assert_eq(_file_item(view, document.file_name).get_text(0), document.file_name + "*")
	assert_eq(view.get_node("%InfoLabel").text, "未保存")
	view._input(_key(KEY_S, true))
	assert_false(view.has_unsaved_documents())
	assert_eq(_file_item(view, document.file_name).get_text(0), document.file_name)
	var reopened: Control = _open_view(true, catalog)
	assert_eq(_select_document(reopened, document.file_name).text, "改过的正文")


## 正文改回预设后，覆盖档不再保留该文件。## 输入: 无。
## 输出: 无。
func test_saving_original_text_removes_override() -> void:
	var document: DesktopTextFile = DesktopTextFile.new()
	document.file_name = "笔记.txt"
	document.content = "原文"
	var catalog: DesktopFileCatalog = DesktopFileCatalog.new()
	catalog.documents = [document]
	var view: Control = _open_view(true, catalog)
	var editor: TextEdit = _select_document(view, document.file_name)
	editor.text = "临时修改"
	assert_eq(view.save_current_document(), OK)
	editor.text = document.content
	assert_eq(view.save_current_document(), OK)
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(view.documents_path), OK)
	assert_false(config.has_section_key("documents", document.file_name))


## 关闭时取消不会继续，不保存会继续并丢掉草稿。## 输入: 无。
## 输出: 无。
func test_close_prompt_cancel_and_discard() -> void:
	var document: DesktopTextFile = DesktopTextFile.new()
	document.file_name = "笔记.txt"
	document.content = "原文"
	var catalog: DesktopFileCatalog = DesktopFileCatalog.new()
	catalog.documents = [document]
	var view: Control = _open_view(true, catalog)
	var editor: TextEdit = _select_document(view, document.file_name)
	editor.text = "还没保存"
	var proceeded: Array[bool] = [false]
	view.desktop_request_close(func() -> void: proceeded[0] = true)
	assert_false(proceeded[0])
	var dialog: ConfirmationDialog = _close_dialog(view)
	assert_not_null(dialog)
	dialog.canceled.emit()
	assert_false(proceeded[0])
	assert_true(view.has_unsaved_documents())
	view.desktop_request_close(func() -> void: proceeded[0] = true)
	dialog = _close_dialog(view)
	dialog.custom_action.emit(&"discard")
	assert_true(proceeded[0])
	assert_false(view.has_unsaved_documents())
	assert_eq(editor.text, document.content)
	assert_false(FileAccess.file_exists(view.documents_path))


## 开始菜单打开时，保存键不写入文档。## 输入: 无。
## 输出: 无。
func test_start_menu_blocks_save_shortcut() -> void:
	var document: DesktopTextFile = DesktopTextFile.new()
	document.file_name = "笔记.txt"
	document.content = "原文"
	var catalog: DesktopFileCatalog = DesktopFileCatalog.new()
	catalog.documents = [document]
	var view: Control = _open_view(true, catalog)
	var editor: TextEdit = _select_document(view, document.file_name)
	editor.text = "草稿"
	var menu: Control = Control.new()
	add_child(menu)
	menu.add_to_group(&"start_menu")
	menu.visible = true
	view._input(_key(KEY_S, true))
	assert_true(view.has_unsaved_documents())
	menu.free()


## 用独立覆盖档打开页面。replace_catalog 为真时替换场景上的预设资源。## 输入:
##   replace_catalog (bool) - 是否替换 file_catalog。
##   catalog (DesktopFileCatalog) - 替换用的资源，可以是 null。
## 输出: Control - 已进入场景树的页面。
func _open_view(replace_catalog: bool, catalog: DesktopFileCatalog = null) -> Control:
	var view: Control = VIEW_SCENE.instantiate() as Control
	view.documents_path = _documents_path
	if replace_catalog:
		view.file_catalog = catalog
	return add_child_autofree(view) as Control


## 选中指定文档并返回编辑器。## 输入:
##   view (Control) - 我的电脑页面。
##   file_name (String) - 文件名。
## 输出: TextEdit - 正文编辑器。
func _select_document(view: Control, file_name: String) -> TextEdit:
	var tree: Tree = view.get_node("%DirList") as Tree
	var file_item: TreeItem = _file_item(view, file_name)
	file_item.select(0)
	tree.item_selected.emit()
	return view.get_node("%FileContent") as TextEdit


## 按文件名找到目录项，忽略未保存标记。## 输入:
##   view (Control) - 我的电脑页面。
##   file_name (String) - 文件名。
## 输出: TreeItem - 对应文件；找不到时返回 null。
func _file_item(view: Control, file_name: String) -> TreeItem:
	var tree: Tree = view.get_node("%DirList") as Tree
	var documents: TreeItem = tree.get_root().get_first_child().get_first_child().get_next()
	var item: TreeItem = documents.get_first_child()
	while item != null:
		if item.get_text(0) == file_name or item.get_text(0) == file_name + "*":
			return item
		item = item.get_next()
	return null


## 找到页面上的保存询问。## 输入: view (Node) - 我的电脑页面。
## 输出: ConfirmationDialog - 对话框；没有时返回 null。
func _close_dialog(view: Node) -> ConfirmationDialog:
	for child: Node in view.get_children():
		if child is ConfirmationDialog and is_instance_valid(child) and not child.is_queued_for_deletion():
			return child as ConfirmationDialog
	return null


## 删除测试覆盖档。## 输入: path (String) - user:// 路径。
## 输出: 无。
func _remove_documents(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 构造一次 Ctrl 组合的按下事件。## 输入:
##   code (Key) - 键码。
##   ctrl_pressed (bool) - 是否按住 Ctrl。
## 输出: InputEventKey - 按下事件。
func _key(code: Key, ctrl_pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = ctrl_pressed
	return event
