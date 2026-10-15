extends Control
## 我的电脑 - 演示深度。显示预设目录信息和系统说明文字。

const DIRS: Array[String] = [
	"C:\\Users\\Administrator\\Documents",
	"C:\\Users\\Administrator\\Desktop",
	"C:\\Program Files",
	"D:\\Knowledge Base",
]


## 填充演示目录列表。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	var list: ItemList = %DirList
	if list == null:
		return
	for d: String in DIRS:
		list.add_item(d)
