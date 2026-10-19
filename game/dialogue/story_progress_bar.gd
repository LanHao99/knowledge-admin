class_name StoryProgressBar
extends HBoxContainer
## 剧情进度条显示组件。只根据已有 StoryProgress 刷新进度条和数字。
## 评分换进度由 StoryManager 负责，本组件不累加进度。

# ── 信号 ──

## 保留的显示信号。评分累加已移到 StoryManager，本组件不再发出它。
signal progress_reached(threshold: int)


# ── 导出属性 ──

## 触发对话所需的最小进度值，仅用于本组件自己的显示上限。
@export var threshold: int = 10


# ── 内部引用 ──

## 剧情进度数据引用。显示层只读这份数据，不在这里累加评分。
var story_progress: StoryProgress = null

## 内部 ProgressBar 子节点。
var _progress_bar: ProgressBar = null

## 内部数值显示 Label。
var _value_label: Label = null


# ── 生命周期 ──


## 初始化时动态创建 ProgressBar 和 Label 子节点。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_create_ui()
	_refresh_display()


# ── UI 构建 ──


## 在 HBoxContainer 中动态创建 ProgressBar 和 Label。## 输入: 无。
## 输出: 无。
func _create_ui() -> void:
	# ProgressBar
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.min_value = 0
	_progress_bar.max_value = float(threshold)
	_progress_bar.value = 0
	add_child(_progress_bar)

	# Label
	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.custom_minimum_size = Vector2(50, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_value_label)


# ── 公共接口 ──


## 注入 StoryProgress 数据引用并刷新显示。## 输入: progress (StoryProgress) - 数据源。
## 输出: 无。
func set_story_progress(progress: StoryProgress) -> void:
	story_progress = progress
	_refresh_display()


# ── 显示刷新 ──


## 同步 ProgressBar 和 Label 的当前值到 UI。## 输入: 无。
## 输出: 无。
func _refresh_display() -> void:
	if _progress_bar == null or _value_label == null:
		return

	var current: int = 0
	if story_progress != null:
		current = story_progress.total_progress

	# 动态调整 max_value（支持运行时修改阈值）
	_progress_bar.max_value = float(threshold)
	_progress_bar.value = float(min(current, threshold))
	_value_label.text = "%d/%d" % [current, threshold]

	# 根据进度百分比切换颜色
	var ratio: float = float(current) / float(max(threshold, 1))
	_update_tint(ratio)


## 根据进度比例调整 ProgressBar 的着色（灰色 → 黄色 → 绿色）。## 输入: ratio (float) - 进度比例 [0, 1]。
## 输出: 无。
func _update_tint(ratio: float) -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 1.0)  # 暗底色

	var fill_color: Color
	if ratio >= 1.0:
		fill_color = Color(0.2, 0.8, 0.3, 1.0)       # 绿色 — 可触发
	elif ratio >= 0.7:
		fill_color = Color(0.9, 0.7, 0.2, 1.0)        # 橙色 — 接近
	elif ratio >= 0.3:
		fill_color = Color(0.8, 0.8, 0.2, 1.0)        # 黄色 — 积累中
	else:
		fill_color = Color(0.4, 0.4, 0.4, 1.0)        # 灰色 — 起步

	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	_progress_bar.add_theme_stylebox_override("fill", stylebox)
	_progress_bar.add_theme_color_override("font_color", fill_color)


# ── 工具方法 ──


## 动态修改触发阈值（会重置 max_value 并刷新）。## 输入: new_threshold (int) - 新阈值。
## 输出: 无。
func set_threshold(new_threshold: int) -> void:
	threshold = max(1, new_threshold)
	_refresh_display()


## 获取当前进度百分比（0.0 ~ 1.0+）。## 输入: 无。
## 输出: float - 进度比例；数据未注入或阈值 <= 0 时返回 0.0。
func get_progress_ratio() -> float:
	if story_progress == null or threshold <= 0:
		return 0.0
	return float(story_progress.total_progress) / float(threshold)
