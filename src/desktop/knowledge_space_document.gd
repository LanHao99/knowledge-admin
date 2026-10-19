class_name KnowledgeSpaceDocument
extends Node3D
## 平行悬浮的文档窗口；折叠后的网格和射线选取共用实际可见矩形。

const TITLE_BAR_HEIGHT: float = 0.95
const BUTTON_SIZE: Vector2 = Vector2(0.8, 0.64)
const HIT_PLANE_Z: float = 0.16
const WINDOW_ACTIONS: Array[StringName] = [&"minimize", &"fullscreen", &"close"]

var document_id: String = ""
var document_title: String = ""
var body: String = ""
var source: String = ""
var is_archive: bool = false
var _settings: KnowledgeSpaceConfig
var _selected: bool = false
var _minimized: bool = false
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
	$TitleBar/Background.mesh = $TitleBar/Background.mesh.duplicate() as BoxMesh
	$TitleBar/Background.material_override = $TitleBar/Background.material_override.duplicate() as StandardMaterial3D
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
	(_paper.material_override as StandardMaterial3D).albedo_color = settings.archive_color if is_archive else settings.card_color
	var title_bar: Node3D = $TitleBar
	title_bar.position.y = (dimensions.y - TITLE_BAR_HEIGHT) * 0.5
	($TitleBar/Background.mesh as BoxMesh).size = Vector3(dimensions.x, TITLE_BAR_HEIGHT, 0.04)
	($TitleBar/Background.material_override as StandardMaterial3D).albedo_color = (settings.archive_border if is_archive else settings.card_border).darkened(0.55)
	for index: int in range(WINDOW_ACTIONS.size()):
		get_action_button(WINDOW_ACTIONS[index]).position.x = dimensions.x * 0.5 - 0.13 - BUTTON_SIZE.x * 0.5 - (2 - index) * 0.9
	var caption: Label3D = $TitleBar/Caption
	caption.position.x = -dimensions.x * 0.5 + 0.2
	caption.width = (dimensions.x - 3.05) / caption.pixel_size
	caption.modulate = settings.text_color
	caption.text = _fitted_excerpt(("档案 · " if is_archive else "") + document_title.replace("\n", " "), caption, 0.4, 48)
	var inset: float = 0.4
	var left_edge: float = -dimensions.x * 0.5 + inset
	var top_edge: float = dimensions.y * 0.5 - inset - TITLE_BAR_HEIGHT
	var labels: Array[Label3D] = [$Source, $Title, $Body, $Footer]
	for label: Label3D in labels:
		label.width = (dimensions.x - inset * 2.0) / label.pixel_size
		label.modulate = settings.text_color
	$Source.position = Vector3(left_edge, top_edge, 0.08)
	$Title.position = Vector3(left_edge, top_edge - 0.55, 0.08)
	$Body.position = Vector3(left_edge, top_edge - 2.1, 0.08)
	$Footer.position = Vector3(left_edge, -dimensions.y * 0.5 + inset + 0.05, 0.08)
	$Source.text = "档案 / XANAKU" if is_archive else "知识 / " + KnowledgeSpaceText.excerpt(source, 32)
	$Source.modulate = settings.archive_border if is_archive else Color("8eb1c5")
	$Title.text = _fitted_excerpt(document_title.replace("\n", " "), $Title, 1.35, 48)
	$Body.text = _fitted_excerpt(str(data.get("preview", body)), $Body, dimensions.y - 3.3 - TITLE_BAR_HEIGHT, clampi(settings.excerpt_length, 80, 360))
	$Footer.text = "ARCHIVE // " + document_id if is_archive else "CARD // " + document_id.trim_prefix("card:")
	$Footer.modulate = Color("7e9aa8")
	_layout_window()
	_refresh_border()
	set_process(is_archive)


## 返回指定窗口操作对应的场景按钮，命中和布局引用同一节点。## 输入: action (StringName)。输出: Node3D，未知操作返回 null。
func get_action_button(action: StringName) -> Node3D:
	match action:
		&"minimize":
			return $TitleBar/Minimize
		&"fullscreen":
			return $TitleBar/Fullscreen
		&"close":
			return $TitleBar/Close
	return null


## 折叠或展开正文，保留标题栏在原来的空间位置。## 输入: minimized (bool)。输出: 无。
func set_minimized(minimized: bool) -> void:
	_minimized = minimized
	_layout_window()


## 查询窗口是否只显示标题栏。## 输入: 无。输出: bool。
func is_minimized() -> bool:
	return _minimized


## 返回局部 XY 平面的实际窗口范围，折叠时缩至顶部标题栏。## 输入: 无。输出: Rect2。
func get_visible_rect() -> Rect2:
	var dimensions: Vector2 = _settings.page_size.max(Vector2(4, 5))
	var height: float = TITLE_BAR_HEIGHT if _minimized else dimensions.y
	return Rect2(Vector2(-dimensions.x * 0.5, dimensions.y * 0.5 - height), Vector2(dimensions.x, height))


## 同步背景尺寸与正文显隐，窗口折叠不改变其他文档位置。## 输入: 无。输出: 无。
func _layout_window() -> void:
	if _settings == null:
		return
	var bounds: Rect2 = get_visible_rect()
	(_frame.mesh as BoxMesh).size = Vector3(bounds.size.x + 0.1, bounds.size.y + 0.1, 0.06)
	(_paper.mesh as BoxMesh).size = Vector3(bounds.size.x, bounds.size.y, 0.06)
	_frame.position.y = bounds.get_center().y
	_paper.position.y = bounds.get_center().y
	for label: Label3D in [$Source, $Title, $Body, $Footer]:
		label.visible = not _minimized


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
	var distance: float = (HIT_PLANE_Z - local_origin.z) / local_direction.z
	if distance <= 0.0:
		return -1.0
	var hit: Vector3 = local_origin + local_direction * distance
	return distance if get_visible_rect().has_point(Vector2(hit.x, hit.y)) else -1.0


## 检查最近命中文档的正面标题栏操作；背面仍只支持选择与聚焦。## 输入: 世界射线原点与方向。
## 输出: minimize、fullscreen、close；普通区域或未命中返回空 StringName。
func get_window_action(ray_origin: Vector3, ray_direction: Vector3) -> StringName:
	var distance: float = ray_distance(ray_origin, ray_direction)
	var local_direction: Vector3 = global_basis.inverse() * ray_direction
	if distance < 0.0 or local_direction.z >= 0.0:
		return &""
	var hit: Vector3 = to_local(ray_origin) + local_direction * distance
	for action: StringName in WINDOW_ACTIONS:
		var button_position: Vector3 = get_action_button(action).position + $TitleBar.position
		if Rect2(Vector2(button_position.x, button_position.y) - BUTTON_SIZE * 0.5, BUTTON_SIZE).has_point(Vector2(hit.x, hit.y)):
			return action
	return &""
