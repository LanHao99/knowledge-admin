@tool
extends Control
## 摄像头画面与 CRT 参数入口；编辑器和运行时共用同一套立绘合成。

@export_group("Portrait")
## MIRA 立绘，可拖入带透明通道的 Texture2D。
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		_refresh_feed()
## 保持原始比例；1 表示完整显示，较大值用于拉近镜头。
@export_range(0.25, 4.0, 0.01) var portrait_zoom: float = 1.0:
	set(value):
		portrait_zoom = value
		_refresh_feed()
## 相对画面大小的位移，正值向右、向下。
@export var portrait_offset: Vector2 = Vector2.ZERO:
	set(value):
		portrait_offset = value
		_refresh_feed()
@export var portrait_flip_h: bool = false:
	set(value):
		portrait_flip_h = value
		_refresh_feed()
@export var background_color: Color = Color("102521"):
	set(value):
		background_color = value
		_refresh_feed()

@export_group("CRT")
@export var crt_enabled: bool = true:
	set(value):
		crt_enabled = value
		_refresh_feed()
@export var resolution: Vector2 = Vector2(320, 240):
	set(value):
		resolution = value.max(Vector2.ONE)
		_refresh_feed()
@export var pixelate: bool = false:
	set(value):
		pixelate = value
		_refresh_feed()
@export_range(0.0, 1.0, 0.01) var scanlines_opacity: float = 0.22:
	set(value):
		scanlines_opacity = value
		_refresh_feed()
@export_range(0.0, 1.0, 0.01) var grille_opacity: float = 0.06:
	set(value):
		grille_opacity = value
		_refresh_feed()
@export_range(0.0, 5.0, 0.01) var warp_amount: float = 0.6:
	set(value):
		warp_amount = value
		_refresh_feed()
@export_range(0.0, 0.1, 0.001) var aberration: float = 0.008:
	set(value):
		aberration = value
		_refresh_feed()
@export_range(0.0, 2.0, 0.01) var brightness: float = 1.18:
	set(value):
		brightness = value
		_refresh_feed()
@export_range(0.0, 1.0, 0.01) var vignette_opacity: float = 0.35:
	set(value):
		vignette_opacity = value
		_refresh_feed()

@export_group("Signal")
@export_range(0.0, 1.0, 0.001) var static_noise_intensity: float = 0.035:
	set(value):
		static_noise_intensity = value
		_refresh_feed()
@export var roll: bool = true:
	set(value):
		roll = value
		_refresh_feed()
@export_range(-10.0, 10.0, 0.1) var roll_speed: float = 2.0:
	set(value):
		roll_speed = value
		_refresh_feed()
@export_range(0.0, 0.2, 0.001) var distort_intensity: float = 0.008:
	set(value):
		distort_intensity = value
		_refresh_feed()

@onready var _screen: ColorRect = %Screen
@onready var _waiting: Label = %WaitingSignal
@onready var _status: Label = %SignalStatus


## 初始化独立材质并连接画面尺寸变化，供 Inspector 即时预览。## 输入: 无。输出: 无。
func _ready() -> void:
	_screen.resized.connect(_refresh_feed)
	_refresh_feed()


## 将导出属性写入本实例材质，并按图片状态更新提示。## 输入: 无。输出: 无。
func _refresh_feed() -> void:
	if not is_node_ready():
		return
	var feed_material: ShaderMaterial = _screen.material as ShaderMaterial
	var parameters: Dictionary = {
		"portrait_texture": portrait_texture,
		"has_portrait": portrait_texture != null,
		"portrait_aspect": portrait_texture.get_size().aspect() if portrait_texture != null else 1.0,
		"feed_aspect": _screen.size.aspect() if _screen.size.y > 0.0 else 1.0,
		"portrait_zoom": maxf(portrait_zoom, 0.01),
		"portrait_offset": portrait_offset,
		"portrait_flip_h": portrait_flip_h,
		"background_color": background_color,
		"crt_enabled": crt_enabled,
		"resolution": resolution.max(Vector2.ONE),
		"pixelate": pixelate,
		"scanlines_opacity": scanlines_opacity,
		"grille_opacity": grille_opacity,
		"warp_amount": warp_amount,
		"aberration": aberration,
		"brightness": brightness,
		"vignette_opacity": vignette_opacity,
		"static_noise_intensity": static_noise_intensity,
		"roll": roll,
		"roll_speed": roll_speed,
		"distort_intensity": distort_intensity,
	}
	for parameter: String in parameters:
		feed_material.set_shader_parameter(parameter, parameters[parameter])
	_waiting.visible = portrait_texture == null
	_status.text = "等待图像信号" if portrait_texture == null else "图像已连接"
