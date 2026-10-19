class_name KnowledgeSpace
extends Control
## 窗口中的知识空间：限量闪卡、剧情档案、自由飞行与只读全文阅读。

const DOCUMENT_SCENE: PackedScene = preload("res://scenes/desktop/knowledge_space_document.tscn")
@export var configuration: KnowledgeSpaceConfig
@export_file("*.db") var database_path: String = "user://knowledge_admin.db"
## 关闭自动读取可在隔离测试中注入文档，避免访问真实存档。
@export var auto_load_cards: bool = true

var _note_manager: NoteManager
var _host: ManagedWindow
var _documents: Dictionary[String, KnowledgeSpaceDocument] = {}
var _selected_id: String = ""
var _card_count: int = 0
var _archive_count: int = 0
var _load_error: String = ""
var _owns_mouse_capture: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _travel: Tween
@onready var _surface: Control = %FlightSurface
@onready var _viewport: SubViewport = %SpaceViewport
@onready var _camera: Camera3D = %SpaceCamera
@onready var _cards_root: Node3D = %CardDocuments
@onready var _archives_root: Node3D = %StoryDocuments
@onready var _reader: PanelContainer = %Reader


## 绑定窗口生命周期和只读数据入口，随后建立场景。## 输入: 无。输出: 无。
func _ready() -> void:
	if configuration == null:
		configuration = KnowledgeSpaceConfig.new()
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is ManagedWindow:
			_host = ancestor as ManagedWindow
			break
		ancestor = ancestor.get_parent()
	_surface.gui_input.connect(_on_surface_gui_input)
	%RefreshButton.pressed.connect(refresh_content)
	%HomeButton.pressed.connect(return_to_entrance)
	%FocusButton.pressed.connect(focus_selected)
	%ReadButton.pressed.connect(read_selected)
	%CloseReader.pressed.connect(close_reader)
	visibility_changed.connect(_sync_visibility)
	WindowManager.app_focused.connect(_on_app_focused)
	App.dialogue_opened.connect(_on_dialogue_opened)
	App.story_state_changed.connect(_on_story_state_changed)
	get_window().focus_exited.connect(_suspend_controls)
	_camera.position = configuration.entrance_position
	(%SpaceEnvironment.environment as Environment).background_color = configuration.background_color
	_build_atmosphere()
	sync_archives(App.get_story_progress())
	if auto_load_cards:
		refresh_content()
	_update_summary()
	_sync_visibility()


## 退出时撤销本窗口拥有的鼠标捕获及移动动画。## 输入: 无。输出: 无。
func _exit_tree() -> void:
	_suspend_controls()


## 父级禁用或暂停处理时也立即释放输入，避免剧情模态锁住鼠标。## 输入: what (int)。输出: 无。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED or what == NOTIFICATION_PAUSED:
		_suspend_controls()
		if is_instance_valid(_viewport):
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif (what == NOTIFICATION_ENABLED or what == NOTIFICATION_UNPAUSED) and is_node_ready():
		_sync_visibility()


## 从业务层刷新限量文档，失败时保留场景和已有内容。## 输入: 无。输出: 无。
func refresh_content() -> void:
	_suspend_controls()
	if _note_manager == null or not _note_manager.is_ready():
		if is_instance_valid(_note_manager):
			remove_child(_note_manager)
			_note_manager.queue_free()
		_note_manager = NoteManager.new()
		add_child(_note_manager)
		if not _note_manager.setup(database_path):
			_load_error = "读取失败。请点击「刷新内容」重试。"
			_update_summary()
			return
	var result: Dictionary = _note_manager.get_spatial_documents(configuration.card_limit)
	if not result.get("success", false):
		_load_error = "读取失败。请点击「刷新内容」重试。"
		_update_summary()
		return
	_load_error = ""
	var rows: Array[Dictionary] = []
	for row: Dictionary in result.get("data", []):
		rows.append(row)
	set_card_documents(rows)


## 用只读卡片快照建立文档群，刷新不改变摄像头位置。## 输入: rows (Array[Dictionary])。输出: 无。
func set_card_documents(rows: Array[Dictionary]) -> void:
	var previous_selection: String = _selected_id
	for child: Node in _cards_root.get_children():
		if child is KnowledgeSpaceDocument:
			_documents.erase((child as KnowledgeSpaceDocument).document_id)
		_cards_root.remove_child(child)
		child.queue_free()
	var grouped: Dictionary[int, Array] = {}
	var maximum: int = clampi(configuration.card_limit, 1, 64)
	for row: Dictionary in rows.slice(0, maximum):
		var deck_id: int = int(row.get("deck_id", 0))
		if not grouped.has(deck_id):
			grouped[deck_id] = []
		grouped[deck_id].append(row)
	var deck_ids: Array = grouped.keys()
	deck_ids.sort()
	_card_count = 0
	for group_index: int in range(deck_ids.size()):
		var group_rows: Array = grouped[deck_ids[group_index]]
		group_rows.sort_custom(_card_id_less)
		_build_card_group(group_rows, group_index)
	_select_document(_documents.get(previous_selection) as KnowledgeSpaceDocument)
	if _reader.visible and not _documents.has(previous_selection):
		close_reader()
	elif _reader.visible:
		read_selected()
	_update_summary()


## 按稳定卡片 ID 排列同组文档。## 输入: first、second (Dictionary)。输出: bool。
func _card_id_less(first: Dictionary, second: Dictionary) -> bool:
	return int(first.get("card_id", 0)) < int(second.get("card_id", 0))


## 将同一牌组布置在档案通道两侧，普通页面不占据档案预留位置。## 输入: rows (Array)、group_index (int)。输出: 无。
func _build_card_group(rows: Array, group_index: int) -> void:
	var lane_x: float = -17.0 if group_index % 2 == 0 else 17.0
	var group_depth: float = -floorf(group_index / 2.0) * 42.0
	for item_index: int in range(rows.size()):
		var row: Dictionary = rows[item_index]
		var front: String = KnowledgeSpaceText.plain_text(str(row.get("front", "")))
		var back: String = KnowledgeSpaceText.plain_text(str(row.get("back", "")))
		var card_id: int = int(row.get("card_id", 0))
		var data: Dictionary = {
			"id": "card:%d" % card_id,
			"title": front if not front.is_empty() else "未命名卡片 #%d" % card_id,
			"body": "问题\n%s\n\n答案\n%s" % [front, back],
			"preview": back if not back.is_empty() else front,
			"source": str(row.get("deck_name", "未命名牌组")),
		}
		var column: int = item_index % 2
		var row_index: int = int(floorf((item_index % 4) / 2.0))
		var page_position: Vector3 = Vector3(
			lane_x + (column - 0.5) * 8.6,
			(row_index - 0.5) * 10.2 + 1.0,
			group_depth - floorf(item_index / 4.0) * 16.0
		)
		_add_document(data, page_position, _cards_root)
		_card_count += 1


## 按当前完整完成记录同步档案，新增和移除不移动其他文档。## 输入: progress (StoryProgress)，可为 null。
## 输出: 无；阅读中的档案被重新锁定时关闭阅读层。
func sync_archives(progress: StoryProgress) -> void:
	var unlocked_ids: Dictionary[String, bool] = {}
	for archive: KnowledgeSpaceArchive in configuration.archives:
		if archive == null or archive.archive_id.is_empty() or not archive.is_unlocked(progress):
			continue
		var archive_key: String = "archive:" + archive.archive_id
		if unlocked_ids.has(archive_key):
			continue
		unlocked_ids[archive_key] = true
		if not _documents.has(archive_key):
			_add_document({"id": archive_key, "title": archive.title,
				"body": KnowledgeSpaceText.plain_text(archive.content), "source": "XANAKU", "is_archive": true},
				archive.spatial_position, _archives_root)
	for child: Node in _archives_root.get_children():
		var document: KnowledgeSpaceDocument = child as KnowledgeSpaceDocument
		if document != null and not unlocked_ids.has(document.document_id):
			_documents.erase(document.document_id)
			_archives_root.remove_child(document)
			document.queue_free()
	_archive_count = unlocked_ids.size()
	if not _selected_id.is_empty() and not _documents.has(_selected_id):
		_select_document(null)
		close_reader()
		_stop_travel()
	_update_summary()


## 实例化平行文档页面并登记选择身份。## 输入: data、page_position、parent_node。输出: 文档实例。
func _add_document(data: Dictionary, page_position: Vector3, parent_node: Node3D) -> KnowledgeSpaceDocument:
	var document: KnowledgeSpaceDocument = DOCUMENT_SCENE.instantiate() as KnowledgeSpaceDocument
	parent_node.add_child(document)
	document.position = page_position
	document.configure(data, configuration)
	_documents[document.document_id] = document
	return document


## 接收视图区中的选择与右键捕获，GUI 坐标按实际视口尺寸转换。## 输入: event (InputEvent)。输出: 无。
func _on_surface_gui_input(event: InputEvent) -> void:
	if not _allows_navigation() or _reader.visible or not event is InputEventMouseButton:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		_begin_flight()
		_surface.accept_event()
	elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed and not _owns_mouse_capture:
		_surface.grab_focus()
		var viewport_point: Vector2 = button.position * Vector2(_viewport.size) / _surface.size.max(Vector2.ONE)
		_select_document(pick_document(viewport_point))
		if button.double_click:
			focus_selected()
		_surface.accept_event()


## 捕获期间接收转向和释放事件，Esc 只处理本窗口的飞行或阅读。## 输入: event (InputEvent)。输出: 无。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_ESCAPE and _allows_navigation() and (_owns_mouse_capture or _reader.visible):
			if _owns_mouse_capture:
				_suspend_controls()
			else:
				close_reader()
			get_viewport().set_input_as_handled()
			return
	if not _owns_mouse_capture:
		return
	if not _allows_navigation():
		_suspend_controls()
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed:
			_suspend_controls()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= motion.screen_relative.x * configuration.mouse_sensitivity
		_pitch = clampf(_pitch - motion.screen_relative.y * configuration.mouse_sensitivity, -1.48, 1.48)
		_camera.rotation = Vector3(_pitch, _yaw, 0)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()


## 在有效捕获期间更新摄像头，不使用全局 InputMap。## 输入: delta (float)。输出: 无。
func _process(delta: float) -> void:
	if not _allows_navigation():
		if _owns_mouse_capture or is_instance_valid(_travel):
			_suspend_controls()
		return
	if not _owns_mouse_capture:
		return
	var movement: Vector3 = Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var direction: Vector3 = _camera.basis * Vector3(movement.x, 0, movement.z) + Vector3.UP * movement.y
	var speed: float = configuration.flight_speed * (configuration.boost_multiplier if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	_camera.position += direction.limit_length() * speed * delta


## 从当前摄像头选择最近的实际页面，不依赖物理帧或屏幕坐标猜测。## 输入: viewport_point (Vector2)。
## 输出: 命中文档或 null。
func pick_document(viewport_point: Vector2) -> KnowledgeSpaceDocument:
	var ray_origin: Vector3 = _camera.project_ray_origin(viewport_point)
	var ray_direction: Vector3 = _camera.project_ray_normal(viewport_point)
	var nearest_distance: float = _camera.far
	var nearest: KnowledgeSpaceDocument
	for document: KnowledgeSpaceDocument in _documents.values():
		var distance: float = document.ray_distance(ray_origin, ray_direction)
		if distance > _camera.near and distance < nearest_distance:
			nearest = document
			nearest_distance = distance
	return nearest


## 选择或清除当前文档，并同步工具栏。## 输入: document，可为 null。输出: 无。
func _select_document(document: KnowledgeSpaceDocument) -> void:
	_selected_id = document.document_id if document != null else ""
	for candidate: KnowledgeSpaceDocument in _documents.values():
		candidate.set_selected(candidate == document)
	%FocusButton.disabled = document == null
	%ReadButton.disabled = document == null
	%SelectionName.text = document.document_title.replace("\n", " ") if document != null else "单击选择文档 · 双击靠近阅读"
	%SelectionName.tooltip_text = document.document_title if document != null else ""


## 根据画面比例移动到所选文档正面，保证页面完整入镜。## 输入: 无。输出: 无。
func focus_selected() -> void:
	var document: KnowledgeSpaceDocument = _documents.get(_selected_id) as KnowledgeSpaceDocument
	if document == null or not _allows_navigation():
		return
	_suspend_controls()
	var dimensions: Vector2 = configuration.page_size.max(Vector2(4, 5))
	var aspect: float = float(_viewport.size.x) / maxf(1.0, _viewport.size.y)
	var half_span: float = maxf(dimensions.y, dimensions.x / aspect) * 0.5
	var distance: float = half_span / tan(deg_to_rad(_camera.fov) * 0.5) * 1.2
	_move_camera(document.global_position + document.global_basis.z * distance, document.quaternion)


## 平滑回到入口，不重载文档和剧情。## 输入: 无。输出: 无。
func return_to_entrance() -> void:
	_suspend_controls()
	_move_camera(configuration.entrance_position, Quaternion.IDENTITY)


## 建立可被手动操作中断的摄像头移动。## 输入: target_position、target_orientation。输出: 无。
func _move_camera(target_position: Vector3, target_orientation: Quaternion) -> void:
	_stop_travel()
	_travel = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_travel.tween_property(_camera, "position", target_position, configuration.focus_duration)
	_travel.tween_property(_camera, "quaternion", target_orientation, configuration.focus_duration)


## 撤销自动移动，随后手动转向从实际姿态接续。## 输入: 无。输出: 无。
func _stop_travel() -> void:
	if is_instance_valid(_travel):
		_travel.kill()
	_travel = null


## 在有效视图区持有右键时捕获鼠标，并中断自动聚焦。## 输入: 无。输出: 无。
func _begin_flight() -> void:
	if not _allows_navigation() or _reader.visible:
		return
	_stop_travel()
	_surface.grab_focus()
	_yaw = _camera.rotation.y
	_pitch = _camera.rotation.x
	_owns_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 清除本窗口的飞行捕获及自动移动，不影响其他窗口的焦点。## 输入: 无。输出: 无。
func _suspend_controls() -> void:
	_stop_travel()
	if _owns_mouse_capture:
		_owns_mouse_capture = false
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 检查窗口可见性、处理状态和活动应用，独立运行也可导航。## 输入: 无。输出: bool。
func _allows_navigation() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or not can_process():
		return false
	if not get_window().has_focus():
		return false
	return _host == null or (WindowManager.get_active_app_id() == "knowledge_space" and not _host.is_shattering())


## 展示选择文档的完整纯文本，并停止所有飞行。## 输入: 无。输出: 无。
func read_selected() -> void:
	var document: KnowledgeSpaceDocument = _documents.get(_selected_id) as KnowledgeSpaceDocument
	if document == null:
		return
	_suspend_controls()
	%ReaderTitle.text = KnowledgeSpaceText.excerpt(document.document_title.replace("\n", " "), 60)
	%ReaderSource.text = "剧情档案 / XANAKU" if document.is_archive else "来源牌组 / " + document.source
	%ReaderText.text = document.body
	%ReaderScroll.scroll_vertical = 0
	_reader.show()
	%CloseReader.grab_focus()


## 关闭阅读层并保留当前位置。## 输入: 无。输出: 无。
func close_reader() -> void:
	_reader.hide()
	if is_visible_in_tree():
		_surface.grab_focus()


## 应用切换立即终止飞行，恢复激活不会移动摄像头。## 输入: app_id (String)。输出: 无。
func _on_app_focused(app_id: String) -> void:
	if app_id != "knowledge_space":
		_suspend_controls()


## 剧情或帮助弹出前释放鼠标，适配随后发生的父级处理禁用。## 输入: _key (String)。输出: 无。
func _on_dialogue_opened(_key: String) -> void:
	_suspend_controls()


## 根据正式存档更新档案显隐，不读取调试草稿。## 输入: 无。输出: 无。
func _on_story_state_changed() -> void:
	sync_archives(App.get_story_progress())


## 隐藏或禁用时停掉 3D 渲染，恢复只重启视口。## 输入: 无。输出: 无。
func _sync_visibility() -> void:
	if not is_node_ready():
		return
	var render_enabled: bool = is_visible_in_tree() and can_process()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if render_enabled else SubViewport.UPDATE_DISABLED
	if not render_enabled:
		_suspend_controls()


## 更新文档数量、空库说明与可重试错误，不显示未解锁档案标题。## 输入: 无。输出: 无。
func _update_summary() -> void:
	%Summary.text = "本地知识 %d  /  已解锁档案 %d" % [_card_count, _archive_count]
	%Status.text = _load_error if not _load_error.is_empty() else "右键 + WASD 飞行 · Q/E 升降 · Shift 加速 · Esc 释放鼠标"
	%EmptyMessage.visible = _card_count == 0
	%EmptyMessage.text = "暂无闪卡。添加卡片后点击「刷新内容」。\n已解锁的剧情档案仍可探索。" if _load_error.is_empty() else _load_error
	if _archive_count > 0:
		%EmptyMessage.visible = false


## 生成静止的低亮度空间参照点，所有文档仍共用一个视口。## 输入: 无。输出: 无。
func _build_atmosphere() -> void:
	var points: MultiMeshInstance3D = %ReferencePoints
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 4
	mesh.rings = 2
	var point_material: StandardMaterial3D = StandardMaterial3D.new()
	point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	point_material.albedo_color = Color("29485d")
	mesh.material = point_material
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = 220
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 241019
	for index: int in range(instances.instance_count):
		var point_position: Vector3 = Vector3(random.randf_range(-85, 85), random.randf_range(-32, 40), random.randf_range(-180, 20))
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, point_position))
	points.multimesh = instances
