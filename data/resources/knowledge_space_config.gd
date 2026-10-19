class_name KnowledgeSpaceConfig
extends Resource
## 知识空间的文档规模、飞行、配色与剧情档案，供场景统一引用。

@export_group("Documents")
@export_range(1, 64, 1) var card_limit: int = 24
@export var page_size: Vector2 = Vector2(7.2, 8.4)
@export_range(80, 360, 1) var excerpt_length: int = 360
@export var card_color: Color = Color("142a3c")
@export var card_border: Color = Color("4b748d")
@export var archive_color: Color = Color("30271b")
@export var archive_border: Color = Color("edb766")
@export var text_color: Color = Color("d9e7ee")
@export var background_color: Color = Color("050c17")
@export var archives: Array[KnowledgeSpaceArchive] = []

@export_group("Flight")
@export_range(1.0, 30.0, 0.1) var flight_speed: float = 9.0
@export_range(1.0, 5.0, 0.1) var boost_multiplier: float = 3.0
@export_range(0.001, 0.01, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(0.1, 2.0, 0.05) var focus_duration: float = 0.65
@export var entrance_position: Vector3 = Vector3(0, 3, 26)
