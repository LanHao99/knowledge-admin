extends GutTest
## 验证预设资源、目录生成与只读文本显示，不使用玩家存档。

const VIEW_SCENE: PackedScene = preload("res://scenes/desktop/my_computer.tscn")


## 场景必须绑定包含现有两份文档的原生资源。## 输入: 无。输出: 无。
func test_default_scene_binds_existing_documents() -> void:
	var view: Control = add_child_autofree(VIEW_SCENE.instantiate())
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
	var view: Control = VIEW_SCENE.instantiate() as Control
	view.file_catalog = catalog
	add_child_autofree(view)
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
	var view: Control = VIEW_SCENE.instantiate() as Control
	view.file_catalog = null
	add_child_autofree(view)
	assert_eq(view.get_node("%FileContent").text, view.SELECTION_HINT)
	var tree: Tree = view.get_node("%DirList") as Tree
	var documents: TreeItem = tree.get_root().get_first_child().get_first_child().get_next()
	assert_null(documents.get_first_child())
