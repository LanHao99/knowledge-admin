extends Control
## 从预设资源生成虚拟目录及只读文本查看器，不访问玩家实际磁盘。

const SELECTION_HINT: String = "选择左侧的文本文件以查看内容。"

@export var file_catalog: DesktopFileCatalog

## 按预设资源构建树形目录并连接文件查看。## 输入: 无。输出: 无。
func _ready() -> void:
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
			if document == null or document.file_name.is_empty():
				continue
			var file_item: TreeItem = tree.create_item(documents)
			file_item.set_text(0, document.file_name)
			file_item.set_metadata(0, document.content)
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_selected)
	drive.select(0)
	_on_item_selected()

## 显示所选条目从资源取得的正文，目录无正文时显示选择提示。## 输入: 无。输出: 无。
func _on_item_selected() -> void:
	var selected: TreeItem = %DirList.get_selected()
	if selected != null:
		var content: Variant = selected.get_metadata(0)
		%FileContent.text = str(content) if content is String else SELECTION_HINT
