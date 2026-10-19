class_name WindowShatterEffect
extends MeshInstance2D
## 原窗口释放后，独立持有完整快照和三角碎片的运动状态。

var elapsed: float = 0.0
var shard_count: int = 0
var _centers: PackedVector2Array = PackedVector2Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _seeds: PackedFloat32Array = PackedFloat32Array()
var _gravity: float = 1800.0
var _initial_lift: float = 130.0
var _motion_material: ShaderMaterial
var _impact_amplitude: float = 0.0
var _impact_duration: float = 0.0
var _impact_frequency: float = 24.0


## 用抖动网格生成覆盖整个快照的三角碎片。## 输入: 快照、目标矩形、网格、随机种子与运动参数。输出: 是否生成成功。
func configure(snapshot: Texture2D, target: Rect2, grid: Vector2i, random_seed: int, gravity_value: float, speed: float, lift: float, spin: float) -> bool:
	position = target.position
	texture = snapshot
	_gravity = maxf(1.0, gravity_value)
	_initial_lift = maxf(0.0, lift)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = random_seed
	var points: PackedVector2Array = _make_points(target.size, grid, random)
	var triangles: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	if triangles.is_empty():
		return false
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for triangle: int in range(0, triangles.size(), 3):
		var center: Vector2 = (points[triangles[triangle]] + points[triangles[triangle + 1]] + points[triangles[triangle + 2]]) / 3.0
		var shard_seed: float = random.randf_range(0.02, 0.98)
		var radius: float = 0.0
		for corner: int in range(3):
			var point: Vector2 = points[triangles[triangle + corner]]
			vertices.append(Vector3(point.x, point.y, 0.0))
			uvs.append(point / target.size)
			colors.append(Color(center.x / target.size.x, center.y / target.size.y, shard_seed, 1.0))
			radius = maxf(radius, point.distance_to(center))
		_centers.append(center)
		_radii.append(radius)
		_seeds.append(shard_seed)
	shard_count = _centers.size()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var shard_mesh: ArrayMesh = ArrayMesh.new()
	shard_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = shard_mesh
	_motion_material = ShaderMaterial.new()
	_motion_material.shader = preload("res://src/shaders/desktop/window_shatter.gdshader")
	_motion_material.set_shader_parameter("source_size", target.size)
	_motion_material.set_shader_parameter("gravity", _gravity)
	_motion_material.set_shader_parameter("horizontal_speed", speed)
	_motion_material.set_shader_parameter("initial_lift", _initial_lift)
	_motion_material.set_shader_parameter("spin_speed", spin)
	material = _motion_material
	return true


## 配置完全碎裂前的整窗冲击，原应用仍在动画开始前释放。## 输入: 震幅、时长、频率。输出: 无。
func configure_impact(amplitude: float, duration: float, frequency: float) -> void:
	_impact_amplitude = maxf(0.0, amplitude)
	_impact_duration = maxf(0.0, duration) if _impact_amplitude > 0.0 else 0.0
	_impact_frequency = frequency


## 保持矩形边界并扰动内部网格，使 Delaunay 三角形完整铺满窗口。## 输入: 尺寸、网格和随机源。输出: 唯一顶点数组。
static func _make_points(extent: Vector2, grid: Vector2i, random: RandomNumberGenerator) -> PackedVector2Array:
	var columns: int = maxi(1, grid.x)
	var rows: int = maxi(1, grid.y)
	var step: Vector2 = extent / Vector2(columns, rows)
	var points: PackedVector2Array = PackedVector2Array()
	for row: int in range(rows + 1):
		for column: int in range(columns + 1):
			var point: Vector2 = Vector2(column, row) * step
			if column > 0 and column < columns:
				point.x += random.randf_range(-0.34, 0.34) * step.x
			if row > 0 and row < rows:
				point.y += random.randf_range(-0.34, 0.34) * step.y
			points.append(point)
	return points


## 推进单次动画；只有全部碎片越过屏幕底部才释放快照。## 输入: 帧间隔。输出: 无。
func _process(delta: float) -> void:
	if _motion_material == null:
		return
	elapsed += delta
	_motion_material.set_shader_parameter("progress", maxf(0.0, elapsed - _impact_duration))
	_motion_material.set_shader_parameter("impact_offset", WindowImpact.sample_offset(elapsed, _impact_amplitude, _impact_duration, _impact_frequency))
	if all_shards_below(get_viewport_rect().end.y):
		queue_free()


## 用旋转外接圆保守判断每块碎片是否已完全落出屏幕。## 输入: 屏幕底部纵坐标。输出: 全部离开时返回 true。
func all_shards_below(bottom: float) -> bool:
	if shard_count == 0:
		return false
	var fall_time: float = maxf(0.0, elapsed - _impact_duration)
	for index: int in range(shard_count):
		var vertical_speed: float = -_initial_lift * (0.4 + 0.6 * _seeds[index])
		var top: float = position.y + _centers[index].y + vertical_speed * fall_time + 0.5 * _gravity * fall_time * fall_time - _radii[index]
		if top <= bottom:
			return false
	return true
