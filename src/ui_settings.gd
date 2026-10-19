extends Node
## 管理全局字体倍率、共享运行时主题及显示层 BBCode，不修改内容原文。

signal font_scale_changed(scale: float)
signal settings_save_failed(error: int)
signal settings_saved()

const DEFAULT_SCALE: float = 1.0
const MIN_SCALE: float = 0.8
const MAX_SCALE: float = 1.5
const SCALE_STEP: float = 0.05
const SAVE_PATH: String = "user://ui_settings.cfg"
const BASE_THEME: Theme = preload("res://content/assets/UI/app_theme.tres")

var font_scale: float = DEFAULT_SCALE
var runtime_theme: Theme
var settings_path: String = SAVE_PATH
var _save_timer: Timer
var _dirty: bool = false
var _font_tag_regex: RegEx = RegEx.new()
var _rich_text_labels: Dictionary[int, WeakRef] = {}


## 准备主题、字体标签匹配器。## 输入: 无。
## 输出: 无。
func _init() -> void:
	runtime_theme = BASE_THEME.duplicate(true) as Theme
	var window_border: StyleBox = BASE_THEME.get_stylebox("embedded_border", "Window")
	runtime_theme.set_stylebox("embedded_border", "Window", window_border.duplicate(true) as StyleBox)
	_font_tag_regex.compile("\\[font_size=(\\d+)\\]")


## 读取设置并为已有及后续窗口接入共享主题。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	load_settings()
	apply_theme(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	for existing: Node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(existing)


## 离开场景树前保存尚未落盘的字号设置。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if _dirty:
		save_settings()


## 规范化倍率，拒绝非有限值并限制范围及步进。## 输入: value (float) - 目标倍率。
## 输出: float - 有效倍率。
static func normalize_scale(value: float) -> float:
	if not is_finite(value):
		return DEFAULT_SCALE
	return clampf(snappedf(value, SCALE_STEP), MIN_SCALE, MAX_SCALE)


## 调整字号并延迟保存，重复设置同一倍率不产生通知。## 输入: value (float) - 目标倍率。
## 输出: 无。
func set_font_scale(value: float) -> void:
	var normalized: float = normalize_scale(value)
	if is_equal_approx(font_scale, normalized):
		return
	font_scale = normalized
	_apply_font_sizes()
	_dirty = true
	if is_instance_valid(_save_timer):
		_save_timer.start()
	font_scale_changed.emit(font_scale)


## 恢复标准字号。## 输入: 无。
## 输出: 无。
func reset_font_scale() -> void:
	set_font_scale(DEFAULT_SCALE)


## 读取外观设置；不存在、格式错误或类型错误时使用默认值。## 输入: path (String) - 配置路径。
## 输出: 无。
func load_settings(path: String = SAVE_PATH) -> void:
	settings_path = path
	var config: ConfigFile = ConfigFile.new()
	var value: Variant = DEFAULT_SCALE
	if FileAccess.file_exists(path) and config.load(path) == OK:
		value = config.get_value("appearance", "font_scale", DEFAULT_SCALE)
	font_scale = normalize_scale(float(value)) if value is float or value is int else DEFAULT_SCALE
	_dirty = false
	_apply_font_sizes()
	font_scale_changed.emit(font_scale)


## 保存配置并报告失败，失败时保留待保存状态。## 输入: 无。
## 输出: Error - 保存结果。
func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("appearance", "font_scale", font_scale)
	var error: Error = config.save(settings_path)
	_dirty = error != OK
	if error != OK:
		settings_save_failed.emit(error)
	else:
		settings_saved.emit()
	return error


## 给 Control 或 Window 设置同一份运行时主题。## 输入: target (Node) - 主题边界节点。
## 输出: 无。
func apply_theme(target: Node) -> void:
	if target is Control:
		(target as Control).theme = runtime_theme
	elif target is Window:
		(target as Window).theme = runtime_theme


## 为新窗口及引用应用主题的控件替换运行时主题。## 输入: node (Node) - 新加入的节点。
## 输出: 无。
func _on_node_added(node: Node) -> void:
	if node is Window:
		apply_theme(node)
	elif node is Control and (node as Control).theme == BASE_THEME:
		apply_theme(node)


## 从只读基准主题换算所有字号，保留运行时资源身份。## 输入: 无。
## 输出: 无。
func _apply_font_sizes() -> void:
	runtime_theme.default_font_size = roundi(BASE_THEME.default_font_size * font_scale)
	for theme_type: String in BASE_THEME.get_font_size_type_list():
		for font_name: String in BASE_THEME.get_font_size_list(theme_type):
			var base_size: int = BASE_THEME.get_font_size(font_name, theme_type)
			runtime_theme.set_font_size(font_name, theme_type, maxi(1, roundi(base_size * font_scale)))
	_update_window_frame()
	for instance_id: int in _rich_text_labels.keys():
		var label: RichTextLabel = _rich_text_labels[instance_id].get_ref() as RichTextLabel
		if is_instance_valid(label):
			_refresh_rich_text(label)
		else:
			_rich_text_labels.erase(instance_id)


## 按字体高度伸展原始窗体纹理的标题区域，保持像素采样及原始资源不变。## 输入: 无。
## 输出: 无。
func _update_window_frame() -> void:
	var source: StyleBoxTexture = BASE_THEME.get_stylebox("embedded_border", "Window") as StyleBoxTexture
	var border: StyleBoxTexture = runtime_theme.get_stylebox("embedded_border", "Window") as StyleBoxTexture
	var title_height: int = runtime_theme.get_font_size("title_font_size", "Window") + 8
	var vertical_scale: float = float(title_height) / source.expand_margin_top
	var texture_image: Image = source.texture.get_image().duplicate() as Image
	texture_image.resize(texture_image.get_width(), roundi(texture_image.get_height() * vertical_scale), Image.INTERPOLATE_NEAREST)
	border.texture = ImageTexture.create_from_image(texture_image)
	border.region_rect = Rect2(Vector2.ZERO, texture_image.get_size())
	border.texture_margin_top = source.texture_margin_top * vertical_scale
	border.texture_margin_bottom = source.texture_margin_bottom * vertical_scale
	border.expand_margin_top = title_height
	border.expand_margin_bottom = source.expand_margin_bottom * vertical_scale
	runtime_theme.set_constant("title_height", "Window", title_height)
	var close_icon: Texture2D = runtime_theme.get_icon("close", "Window")
	runtime_theme.set_constant("close_v_offset", "Window", ceili((title_height + close_icon.get_height()) / 2.0))


## 按当前倍率换算原始 BBCode 的显式字号。## 输入: source (String) - 未缩放文本。
## 输出: String - 仅字号标签被换算的文本。
func scale_bbcode_font_sizes(source: String) -> String:
	var matches: Array[RegExMatch] = _font_tag_regex.search_all(source)
	var result: String = source
	for index: int in range(matches.size() - 1, -1, -1):
		var tag: RegExMatch = matches[index]
		var scaled: int = maxi(1, roundi(int(tag.get_string(1)) * font_scale))
		result = result.substr(0, tag.get_start(1)) + str(scaled) + result.substr(tag.get_end(1))
	return result


## 设置富文本并保留未缩放来源，以供运行时字号变化重新渲染。## 输入:
##   label (RichTextLabel) - 目标控件。
##   source (String) - 未缩放文本。
## 输出: 无。
func set_rich_text(label: RichTextLabel, source: String) -> void:
	label.set_meta("ui_source_bbcode", source)
	_rich_text_labels[label.get_instance_id()] = weakref(label)
	_refresh_rich_text(label)


## 刷新显式字号并保留可见字符及滚动位置，不重启动画。## 输入: label (RichTextLabel) - 目标控件。
## 输出: 无。
func _refresh_rich_text(label: RichTextLabel) -> void:
	var source: String = str(label.get_meta("ui_source_bbcode", ""))
	var rendered: String = scale_bbcode_font_sizes(source)
	if label.text == rendered:
		return
	var visible_count: int = label.visible_characters
	var scroll_bar: VScrollBar = label.get_v_scroll_bar()
	var scroll_value: float = scroll_bar.value if scroll_bar != null else 0.0
	label.text = rendered
	label.visible_characters = visible_count
	if scroll_bar != null:
		scroll_bar.value = scroll_value
