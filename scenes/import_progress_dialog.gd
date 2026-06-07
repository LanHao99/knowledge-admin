extends Control
class_name ImportProgressDialog

## 导入流程第3步——显示导入进度与结果。
## 连接 ImportManager 的三个信号：import_progress、import_completed、import_failed。
## 完成后显示成功/失败统计及失败详情。
## 作为嵌入式组件嵌入 ImportMain 的步骤容器中（非弹出窗口）。


# 数据层
var _import_manager: ImportManager = null

# UI 节点
var _progress_bar: ProgressBar = null
var _status_label: Label = null
var _result_label: Label = null
var _failures_edit: TextEdit = null
var _failures_label: Label = null
var _done_btn: Button = null

# 信号
signal import_finished()


## 注入 ImportManager 依赖，构建 UI 并连接信号。## 输入: import_manager (ImportManager) - 导入管理器。
## 输出: 无。
func setup(import_manager: ImportManager) -> void:
	_import_manager = import_manager
	_build_ui()
	_connect_signals()


## 构建 UI 布局（纯代码动态创建）。## 输入: 无。
## 输出: 无。
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# 标题
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "导入进度"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	# 进度条
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.size_flags_horizontal = Control.SIZE_FILL
	root.add_child(_progress_bar)

	# 状态标签
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "正在导入... (0 / 0)"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_status_label)

	# 结果摘要标签
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 14)
	_result_label.visible = false
	root.add_child(_result_label)

	# 失败详情标签
	_failures_label = Label.new()
	_failures_label.name = "FailuresLabel"
	_failures_label.text = "失败详情："
	_failures_label.add_theme_font_size_override("font_size", 13)
	_failures_label.visible = false
	root.add_child(_failures_label)

	# 失败列表（只读 TextEdit）
	_failures_edit = TextEdit.new()
	_failures_edit.name = "FailuresEdit"
	_failures_edit.editable = false
	_failures_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_failures_edit.visible = false
	_failures_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(_failures_edit)

	# "完成"按钮
	_done_btn = Button.new()
	_done_btn.name = "DoneBtn"
	_done_btn.text = "完成"
	_done_btn.custom_minimum_size = Vector2(120, 36)
	_done_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done_btn.visible = false
	_done_btn.pressed.connect(_on_done_pressed)
	root.add_child(_done_btn)


## 连接导入管理器信号。## 输入: 无。
## 输出: 无。
func _connect_signals() -> void:
	if _import_manager == null:
		return

	if _import_manager.import_progress.is_connected(_on_import_progress):
		return
	_import_manager.import_progress.connect(_on_import_progress)
	_import_manager.import_completed.connect(_on_import_completed)
	_import_manager.import_failed.connect(_on_import_failed)


## 断开导入管理器信号。## 输入: 无。
## 输出: 无。
func _disconnect_signals() -> void:
	if _import_manager == null:
		return

	if _import_manager.import_progress.is_connected(_on_import_progress):
		_import_manager.import_progress.disconnect(_on_import_progress)
	if _import_manager.import_completed.is_connected(_on_import_completed):
		_import_manager.import_completed.disconnect(_on_import_completed)
	if _import_manager.import_failed.is_connected(_on_import_failed):
		_import_manager.import_failed.disconnect(_on_import_failed)


## 退出场景时断开信号。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	_disconnect_signals()


# ── 信号回调 ──


## 导入进度信号回调——更新进度条和状态文字。## 输入:
##   current (int) - 已完成数。
##   total (int) - 总数。
## 输出: 无。
func _on_import_progress(current: int, total: int) -> void:
	_progress_bar.max_value = max(total, 1)
	_progress_bar.value = current
	_status_label.text = "正在导入... (%d / %d)" % [current, total]


## 导入完成信号回调——显示结果摘要和失败详情。## 输入: result (Dictionary) - 导入结果数据。
## 输出: 无。
func _on_import_completed(result: Dictionary) -> void:
	var data: Dictionary = result.get("data", {})
	var imported: int = data.get("imported", 0)
	var failed: int = data.get("failed", 0)
	var total: int = data.get("total_rows", 0)

	_progress_bar.max_value = max(total, 1)
	_progress_bar.value = imported + failed

	var summary: String
	if failed == 0:
		summary = "✅ 导入完成！成功 %d 条" % imported
	else:
		summary = "⚠ 导入部分成功！成功 %d 条，失败 %d 条" % [imported, failed]

	_status_label.text = ""
	_result_label.text = summary
	_result_label.visible = true

	# 显示失败详情
	var failures: Array = data.get("failures", [])
	if not failures.is_empty():
		_failures_label.visible = true
		_failures_edit.visible = true
		var lines: PackedStringArray = []
		for f in failures:
			if f is Dictionary:
				var row_num: int = f.get("row", 0)
				var err: String = str(f.get("error", ""))
				lines.append("第 %d 行: %s" % [row_num, err])
		_failures_edit.text = "\n".join(lines)

	_done_btn.visible = true


## 导入失败信号回调——显示错误信息。## 输入: error (Dictionary) - 错误数据。
## 输出: 无。
func _on_import_failed(error: Dictionary) -> void:
	_status_label.text = ""
	_result_label.text = "❌ 导入失败: %s" % error.get("error", "未知错误")
	_result_label.visible = true
	_done_btn.visible = true


## "完成"按钮点击——断开信号并发射 import_finished。## 输入: 无。
## 输出: 无。
func _on_done_pressed() -> void:
	_disconnect_signals()
	import_finished.emit()
