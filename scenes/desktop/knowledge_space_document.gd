class_name KnowledgeSpaceDocument
extends Node3D
## 平行悬浮的文档面板；文本、边框和射线选取共用实际页面尺寸。

var document_id: String = ""
var document_title: String = ""
var body: String = ""
var source: String = ""
var is_archive: bool = false
var _settings: KnowledgeSpaceConfig
var _selected: bool = false
var _pulse_time: float = 0.0
var _frame_material: StandardMaterial3D
@onready var _frame: MeshInstance3D = $Frame
@onready var _paper: MeshInstance3D = $Paper


## 初始化每个面板独立的网格及材质。## 输入: 无。输出: 无。
func _ready() -> void:
	_frame.mesh = _frame.mesh.duplicate() as BoxMesh
	_paper.mesh = _paper.mesh.duplicate() as BoxMesh
	_frame_material = _frame.material_override.duplicate() as StandardMaterial3D
	_frame.material_override = _frame_material
	_paper.material_override = _paper.material_override.duplicate() as StandardMaterial3D
	set_process(false)


## 设置全文、来源、身份及视觉配置，正文仅显示摘录。## 输入: data (Dictionary)、settings (KnowledgeSpaceConfig)。
## 输出: 无；本节点保持原来的朝向，不启用 billboard。
func configure(data: Dictionary, settings: KnowledgeSpaceConfig) -> void:
	_settings = settings
	document_id = str(data.get("id", ""))
	document_title = str(data.get("title", "未命名文档"))
	body = str(data.get("body", ""))
	source = str(data.get("source", ""))
	is_archive = bool(data.get("is_archive", false))
	var dimensions: Vector2 = settings.page_size.max(Vector2(4, 5))
	(_frame.mesh as BoxMesh).size = Vector3(dimensions.x + 0.1, dimensions.y + 0.1, 0.06)
	(_paper.mesh as BoxMesh).size = Vector3(dimensions.x, dimensions.y, 0.06)
	(_paper.material_override as StandardMaterial3D).albedo_color = settings.archive_color if is_archive else settings.card_color
	var inset: float = 0.4
	var left_edge: float = -dimensions.x * 0.5 + inset
	var top_edge: float = dimensions.y * 0.5 - inset
	var labels: Array[Label3D] = [$Source, $Title, $Body, $Footer]
	for label: Label3D in labels:
		label.width = (dimensions.x - inset * 2.0) / label.pixel_size
		label.modulate = settings.text_color
	$Source.position = Vector3(left_edge, top_edge, 0.08)
	$Title.position = Vector3(left_edge, top_edge - 0.55, 0.08)
	$Body.position = Vector3(left_edge, top_edge - 2.1, 0.08)
	$Footer.position = Vector3(left_edge, -top_edge + 0.05, 0.08)
	$Source.text = "档案 / XANAKU" if is_archive else "知识 / " + KnowledgeSpaceText.excerpt(source, 32)
	$Source.modulate = settings.archive_border if is_archive else Color("8eb1c5")
	$Title.text = _fitted_excerpt(document_title.replace("\n", " "), $Title, 1.35, 48)
	$Body.text = _fitted_excerpt(str(data.get("preview", body)), $Body, dimensions.y - 3.3, clampi(settings.excerpt_length, 80, 360))
	$Footer.text = "ARCHIVE // " + document_id if is_archive else "CARD // " + document_id.trim_prefix("card:")
	$Footer.modulate = Color("7e9aa8")
	_refresh_border()
	set_process(is_archive)


## 使用与 Label3D 相同的字体及换行规则限制摘录实际高度。## 输入: 文本、标签、可用世界高度、字符上限。
## 输出: 能放入页面的摘录，完整正文保持在 body 中。
func _fitted_excerpt(text: String, label: Label3D, available_height: float, character_limit: int) -> String:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.width = label.width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var lower: int = 1
	var upper: int = mini(text.length(), character_limit)
	var best: String = ""
	while lower <= upper:
		var middle: int = int(floorf((lower + upper) * 0.5))
		var candidate: String = KnowledgeSpaceText.excerpt(text, middle)
		paragraph.clear()
		paragraph.add_string(candidate, label.font, label.font_size)
		if paragraph.get_size().y * label.pixel_size <= available_height:
			best = candidate
			lower = middle + 1
		else:
			upper = middle - 1
	return best


## 在剧情档案边框上施加轻微亮度变化，不改变透明度与页面位置。## 输入: delta (float)。输出: 无。
func _process(delta: float) -> void:
	_pulse_time += delta
	_refresh_border()


## 更新选择状态，普通文档不进行持续处理。## 输入: selected (bool)。输出: 无。
func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh_border()


## 按类型、选择状态和脉冲更新独立边框材质。## 输入: 无。输出: 无。
func _refresh_border() -> void:
	if _settings == null or _frame_material == null:
		return
	var tint: Color = _settings.archive_border if is_archive else _settings.card_border
	if _selected:
		tint = tint.lerp(Color.WHITE, 0.6)
	elif is_archive:
		tint = tint.darkened(0.1 + 0.08 * sin(_pulse_time * 1.6))
	_frame_material.albedo_color = tint


## 计算射线到真实页面矩形的距离，忽略矩形外及摄像头后方。## 输入: ray_origin、ray_direction (Vector3)。
## 输出: float - 命中距离；未命中为 -1，支持从页面背面选择后聚焦到正面。
func ray_distance(ray_origin: Vector3, ray_direction: Vector3) -> float:
	if _settings == null:
		return -1.0
	var local_origin: Vector3 = to_local(ray_origin)
	var local_direction: Vector3 = global_basis.inverse() * ray_direction
	if absf(local_direction.z) < 0.00001:
		return -1.0
	var distance: float = (0.06 - local_origin.z) / local_direction.z
	if distance <= 0.0:
		return -1.0
	var hit: Vector3 = local_origin + local_direction * distance
	var half_size: Vector2 = _settings.page_size.max(Vector2(4, 5)) * 0.5
	return distance if absf(hit.x) <= half_size.x and absf(hit.y) <= half_size.y else -1.0
