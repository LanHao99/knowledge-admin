extends Control
## 预设目录及只读文本查看器，不访问真实文件系统。

const CONTENTS: Dictionary = {
	"系统盘 (C:)": "Knowledge Admin\nClassic98 Desktop\n\n系统状态：运行正常\n界面：中文\n学习引擎：FSRS",
	"程序": "双击桌面或开始菜单中的应用图标，即可启动对应软件。",
	"使用说明.txt": "欢迎使用 Knowledge Admin。\n\n双击桌面图标打开软件。拖动标题栏移动窗口，拖动边框调整大小。\n\n任务栏可切换、最小化或恢复应用。学习和输入内容在最小化后仍会保留。",
	"学习指南.txt": "在 Knowledge Admin 中创建牌组并添加笔记，也可以使用 JSON 导入或 AI 制卡助手。\n\n进入学习后，先回忆答案，再翻面并选择评分。已完成的评分会自动保存。",
}

## 构建树形目录并连接文件查看。## 输入: 无。输出: 无。
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
	for filename: String in ["使用说明.txt", "学习指南.txt"]:
		tree.create_item(documents).set_text(0, filename)
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_selected)
	drive.select(0)
	_on_item_selected()

## 显示所选目录的信息或预设文本。## 输入: 无。输出: 无。
func _on_item_selected() -> void:
	var selected: TreeItem = %DirList.get_selected()
	if selected != null:
		%FileContent.text = str(CONTENTS.get(selected.get_text(0), "选择左侧的文本文件以查看内容。"))
