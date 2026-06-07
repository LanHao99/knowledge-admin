class_name TextAnimationController
extends Node
## 文字动画控制器，驱动 RichTextLabel 的打字机效果、情绪特效和节奏控制。
## 用于 StoryDialogueOverlay 中，解析对话标记并控制文字显示动画。
## 支持 {fast}/{slow}/{pause}/{shake}/{glitch}/{fade}/{whisper}/{system}/{auto} 标记。

# ── 信号 ──

## 打字机动画完成。
signal typewriter_completed()

## 自动推进触发（{auto} 标记的行完成后）。
signal auto_advance_requested()

## 特效触发（用于外部监听，如音效）。
signal effect_triggered(effect: String)


# ── 常量 ──

## 默认打字机速度（秒/字符）。
const DEFAULT_SPEED: float = 0.03

## 快速打字机速度。
const FAST_SPEED: float = 0.012

## 慢速打字机速度。
const SLOW_SPEED: float = 0.07

## 标点符号自动暂停时间（秒）。
const PUNCTUATION_PAUSES: Dictionary = {
	"。": 0.30, "，": 0.15, "！": 0.25, "？": 0.25, "…": 0.40,
	".": 0.30, ",": 0.15, "!": 0.25, "?": 0.25,
	"——": 0.20, "；": 0.18, "：": 0.15,
}

## 故障效果中随机替换用字符池。
const GLITCH_CHARS: String = "!@#$%^&*()_+-=[]{}|;:',.<>?/~`▯■□▪▫▮▬▲▼◆◇○●△▽☆★"


# ── 公开属性 ──

## 速度倍率（用于设置调节，1.0 = 默认速度）。
var speed_multiplier: float = 1.0

## 是否启用打字机效果。
var enable_typewriter: bool = true

## 是否启用情绪特效。
var enable_effects: bool = true

## 是否完全禁用所有动画（无障碍模式）。
var disable_all_animations: bool = false

## 是否禁用抖动效果（晕动症友好）。
var disable_shake: bool = false


# ── 内部状态 ──

## 目标 RichTextLabel 引用。
var _label: RichTextLabel = null

## 当前播放的 Tween。
var _tween: Tween = null

## 当前播放的 glitch Timer。
var _glitch_timer: Timer = null

## 是否正在播放动画。
var _is_playing: bool = false

## 播放完成回调。
var _on_complete: Callable = Callable()

## 是否已请求跳过。
var _skip_requested: bool = false

## 原始文本（含标记）。
var _raw_text: String = ""


# ── 初始化 ──


## 绑定目标 RichTextLabel，初始化内部定时器。## 输入: label (RichTextLabel) — 要控制的目标标签。
## 输出: 无。
func setup(label: RichTextLabel) -> void:
	_label = label

	# 创建 glitch 定时器
	_glitch_timer = Timer.new()
	_glitch_timer.name = "GlitchTimer"
	_glitch_timer.one_shot = false
	_glitch_timer.timeout.connect(_on_glitch_tick)
	add_child(_glitch_timer)


# ── 公共接口 ──


## 开始播放一行对话（带打字机效果 + 标记解析）。## 输入:
##   raw_text (String) — 包含 {fast}/{slow}/{pause} 等标记的原始文本。
##   on_complete (Callable) — 打字机完成后的回调。
## 输出: 无。
func play_line(raw_text: String, on_complete: Callable = Callable()) -> void:
	_stop_current_animation()
	_raw_text = raw_text
	_on_complete = on_complete
	_skip_requested = false

	if disable_all_animations or not enable_typewriter or _label == null:
		_show_instant(raw_text)
		return

	_is_playing = true

	# 解析标记，获取纯文本 + 标记段列表
	var parsed := _parse_markup(raw_text)
	var pure_text: String = parsed["pure_text"]
	var segments: Array = parsed["segments"]

	# 设置 RichTextLabel 的完整 BBCode 文本（但隐藏）
	_label.visible_characters = 0
	_label.text = pure_text

	# 启动分段打字机
	_start_segmented_typewriter(segments, pure_text)


## 立即完成当前动画（跳过打字机，显示全部文字）。## 输入: 无。
## 输出: 无。
func skip_to_end() -> void:
	if not _is_playing:
		return

	_skip_requested = true
	_stop_current_animation()

	if _label != null:
		_label.visible_characters = -1  # -1 表示显示全部

	_is_playing = false
	typewriter_completed.emit()

	if _on_complete.is_valid():
		_on_complete.call()


## 检查是否正在播放动画。## 输入: 无。
## 输出: bool，正在播放返回 true。
func is_playing() -> bool:
	return _is_playing


## 清除当前文字显示。## 输入: 无。
## 输出: 无。
func clear() -> void:
	_stop_current_animation()
	if _label != null:
		_label.text = ""
		_label.visible_characters = -1


# ── 标记解析 ──


## 解析文本中的自定义标记，返回纯文本和标记段数组。## 输入: raw_text (String) — 包含标记的原始文本。
## 输出: Dictionary — { pure_text: String, segments: Array[Dictionary] }。
func _parse_markup(raw_text: String) -> Dictionary:
	var segments: Array = []  # 每段: { start: int, end: int, type: String, data: Variant }
	var pure_text: String = raw_text
	var offset: int = 0  # 标记移除后的字符偏移

	# 解析 {pause=N} 标记
	var pause_regex := RegEx.new()
	pause_regex.compile("\\{pause=([\\d.]+)\\}")
	var pause_matches := pause_regex.search_all(raw_text)
	for m in pause_matches:
		var start_pos: int = m.get_start() - offset
		var duration: float = float(m.get_string(1))
		segments.append({
			"type": "pause",
			"position": start_pos,
			"duration": duration
		})
		offset += m.get_end() - m.get_start()
	pure_text = pause_regex.sub(pure_text, "", true)

	# 解析成对标记
	var paired_tags: Array = [
		{"tag": "fast", "type": "speed", "data": FAST_SPEED},
		{"tag": "slow", "type": "speed", "data": SLOW_SPEED},
		{"tag": "shake", "type": "shake"},
		{"tag": "glitch", "type": "glitch"},
		{"tag": "fade", "type": "fade"},
		{"tag": "whisper", "type": "whisper"},
		{"tag": "system", "type": "system"},
	]

	for pt in paired_tags:
		var tag: String = pt["tag"]
		var open_regex := RegEx.new()
		open_regex.compile("\\{%s\\}" % tag)
		var close_regex := RegEx.new()
		close_regex.compile("\\{/%s\\}" % tag)

		# 找到所有开启和关闭位置
		var opens := open_regex.search_all(raw_text)
		var closes := close_regex.search_all(raw_text)

		for i in range(min(opens.size(), closes.size())):
			var open_pos: int = opens[i].get_start()
			var close_pos: int = closes[i].get_start()

			# 计算移除标记后的位置
			var offset_before_open: int = _count_removed_chars_before(raw_text, open_pos)
			var offset_before_close: int = _count_removed_chars_before(raw_text, close_pos) + _tag_length(tag, true)

			segments.append({
				"type": pt["type"],
				"start": open_pos - offset_before_open,
				"end": close_pos - offset_before_close,
				"data": pt.get("data", null)
			})

	# 移除所有成对标记
	for pt in paired_tags:
		var tag: String = pt["tag"]
		var open_regex := RegEx.new()
		open_regex.compile("\\{%s\\}" % tag)
		var close_regex := RegEx.new()
		close_regex.compile("\\{/%s\\}" % tag)
		pure_text = open_regex.sub(pure_text, "", true)
		pure_text = close_regex.sub(pure_text, "", true)

	# 解析 {auto} 标记
	if raw_text.contains("{auto}"):
		var auto_pos: int = raw_text.find("{auto}")
		var offset_before: int = _count_removed_chars_before(raw_text, auto_pos)
		segments.append({
			"type": "auto",
			"position": auto_pos - offset_before
		})
	var auto_regex := RegEx.new()
	auto_regex.compile("\\{auto\\}")
	pure_text = auto_regex.sub(pure_text, "", true)

	# 按位置排序
	segments.sort_custom(func(a, b): return a.get("position", a.get("start", 0)) < b.get("position", b.get("start", 0)))

	return {"pure_text": pure_text, "segments": segments}


## 计算在 raw_text 中某个位置之前已被移除的标记总长度。## 输入:
##   raw_text (String) — 原始文本。
##   pos (int) — 参考位置。
## 输出: int — 被移除的字符数。
func _count_removed_chars_before(raw_text: String, pos: int) -> int:
	var count: int = 0
	var all_tags: Array = ["pause=[\\d.]+", "fast", "/fast", "slow", "/slow",
		"shake", "/shake", "glitch", "/glitch", "fade", "/fade",
		"whisper", "/whisper", "system", "/system", "auto"]

	for tag_pattern in all_tags:
		var regex := RegEx.new()
		regex.compile("\\{%s\\}" % tag_pattern)
		var matches := regex.search_all(raw_text)
		for m in matches:
			if m.get_start() < pos:
				count += m.get_end() - m.get_start()

	return count


## 获取标记的字符串长度（用于偏移计算）。## 输入:
##   tag (String) — 标记名。
##   is_open (bool) — 是否为开启标记。
## 输出: int — 标记长度。
func _tag_length(tag: String, is_open: bool) -> int:
	if is_open:
		return tag.length() + 2  # {tag}
	else:
		return tag.length() + 3  # {/tag}


# ── 分段打字机 ──


## 启动分段打字机动画。根据 segments 在不同位置切换速度和触发效果。## 输入:
##   segments (Array) — 标记段数组。
##   pure_text (String) — 纯文本（已移除标记）。
## 输出: 无。
func _start_segmented_typewriter(segments: Array, pure_text: String) -> void:
	var total_chars: int = pure_text.length()
	if total_chars == 0:
		_on_typewriter_finished()
		return

	var current_speed: float = DEFAULT_SPEED * speed_multiplier
	var current_char: int = 0
	var segment_index: int = 0

	# 找出所有"事件点"：每段标记的开始/结束、标点、以及纯逐字间隙
	var events: Array = []

	# 添加标记事件
	for seg in segments:
		var seg_type: String = seg.get("type", "")
		match seg_type:
			"speed":
				events.append({"char": seg["start"], "event": "speed_change", "speed": seg["data"]})
				events.append({"char": seg["end"], "event": "speed_change", "speed": DEFAULT_SPEED})
			"pause":
				events.append({"char": seg["position"], "event": "pause", "duration": seg["duration"]})
			"shake":
				events.append({"char": seg["start"], "event": "shake_start"})
				events.append({"char": seg["end"], "event": "shake_end"})
			"glitch":
				events.append({"char": seg["start"], "event": "glitch_start"})
				events.append({"char": seg["end"], "event": "glitch_end"})
			"auto":
				events.append({"char": seg["position"], "event": "auto"})

	# 添加标点暂停事件
	for i in range(total_chars):
		var ch: String = pure_text[i]
		# 检查单字符标点
		if ch in PUNCTUATION_PAUSES:
			events.append({"char": i + 1, "event": "pause", "duration": PUNCTUATION_PAUSES[ch]})
		# 检查双字符标点（如中文省略号 … 已被单字符处理，这里处理 ——）
		if i < total_chars - 1:
			var pair: String = pure_text.substr(i, 2)
			if pair in PUNCTUATION_PAUSES:
				events.append({"char": i + 2, "event": "pause", "duration": PUNCTUATION_PAUSES[pair]})

	# 按字符位置排序
	events.sort_custom(func(a, b): return a["char"] < b["char"])

	# 构建动画序列
	_tween = create_tween()

	var prev_char: int = 0
	for event in events:
		var target_char: int = event["char"]

		if target_char > prev_char:
			var segment_chars: int = target_char - prev_char
			var segment_duration: float = segment_chars * current_speed
			_tween.tween_method(_set_visible_chars, prev_char, target_char, segment_duration)
			prev_char = target_char

		# 处理事件
		match event.get("event", ""):
			"speed_change":
				current_speed = event["speed"] * speed_multiplier
			"pause":
				_tween.tween_interval(event["duration"])
			"shake_start":
				if enable_effects and not disable_shake:
					_tween.tween_callback(_start_shake)
			"shake_end":
				if enable_effects and not disable_shake:
					_tween.tween_callback(_stop_shake)
			"glitch_start":
				if enable_effects:
					_tween.tween_callback(_start_glitch)
			"glitch_end":
				if enable_effects:
					_tween.tween_callback(_stop_glitch)

	# 剩余字符
	if prev_char < total_chars:
		var remaining: int = total_chars - prev_char
		_tween.tween_method(_set_visible_chars, prev_char, total_chars, remaining * current_speed)

	# 检查是否有 auto 标记
	var has_auto: bool = false
	for event in events:
		if event.get("event", "") == "auto":
			has_auto = true
			break

	_tween.tween_callback(_on_typewriter_finished)

	if has_auto:
		_tween.tween_callback(func(): auto_advance_requested.emit())


## Tween 回调：设置可见字符数。## 输入: count (int) — 当前可见字符数。
## 输出: 无。
func _set_visible_chars(count: int) -> void:
	if _label != null:
		_label.visible_characters = count


## 打字机完成回调。## 输入: 无。
## 输出: 无。
func _on_typewriter_finished() -> void:
	_is_playing = false
	_stop_shake()
	_stop_glitch()

	if _label != null:
		_label.visible_characters = -1

	typewriter_completed.emit()

	if _on_complete.is_valid():
		_on_complete.call()


# ── 立即显示（无动画模式） ──


## 立即显示全部文字（跳过动画）。## 输入: raw_text (String) — 原始文本。
## 输出: 无。
func _show_instant(raw_text: String) -> void:
	if _label == null:
		return
	var parsed := _parse_markup(raw_text)
	_label.text = parsed["pure_text"]
	_label.visible_characters = -1

	if _on_complete.is_valid():
		_on_complete.call()


# ── 抖动效果 ──


## 开始抖动效果（给 RichTextLabel 添加随机位移）。## 输入: 无。
## 输出: 无。
func _start_shake() -> void:
	if _label == null or disable_shake:
		return

	var shake_tween := create_tween()
	shake_tween.set_loops()  # 无限循环
	var amplitude: float = 3.0
	for i in range(4):
		shake_tween.tween_property(_label, "position:x", randf_range(-amplitude, amplitude), 0.04)
		shake_tween.tween_property(_label, "position:y", randf_range(-amplitude, amplitude), 0.04)

	effect_triggered.emit("shake")


## 停止抖动效果，恢复原位。## 输入: 无。
## 输出: 无。
func _stop_shake() -> void:
	if _label == null:
		return

	# 停止所有抖动 Tween（通过创建一个覆盖 Tween）
	var reset_tween := create_tween()
	reset_tween.tween_property(_label, "position", Vector2.ZERO, 0.1)


# ── 故障效果 ──


## 开始故障效果：周期性随机替换字符。## 输入: 无。
## 输出: 无。
func _start_glitch() -> void:
	if _label == null or not enable_effects:
		return

	_glitch_timer.start(0.06)
	effect_triggered.emit("glitch")


## 停止故障效果，恢复原始文本。## 输入: 无。
## 输出: 无。
func _stop_glitch() -> void:
	if _glitch_timer != null:
		_glitch_timer.stop()


## 故障定时器回调：随机替换 1~2 个字符。## 输入: 无。
## 输出: 无。
func _on_glitch_tick() -> void:
	if _label == null:
		return

	var text: String = _label.text
	if text.is_empty():
		return

	var total: int = text.length()
	# 随机替换 1~2 个位置
	var glitch_count: int = randi() % 2 + 1
	for _i in range(glitch_count):
		var pos: int = randi() % total
		var glitch_char: String = GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
		text[pos] = glitch_char

	_label.text = text


# ── 工具 ──


## 停止当前所有动画。## 输入: 无。
## 输出: 无。
func _stop_current_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_stop_shake()
	_stop_glitch()
	_is_playing = false
