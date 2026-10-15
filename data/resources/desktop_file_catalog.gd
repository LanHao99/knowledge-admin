class_name DesktopFileCatalog
extends Resource
## 我的电脑预设目录说明与文档列表，不访问玩家的实际磁盘。

@export_multiline var drive_description: String = ""
@export_multiline var programs_description: String = ""
@export var documents: Array[DesktopTextFile] = []
