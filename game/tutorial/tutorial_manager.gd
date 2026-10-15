class_name TutorialManager
extends RefCounted
## 教程管理器。
## 检测场景首次进入后，通过 App.request_dialogue 播放教程。
## 不自己创建对话窗。各场景在 _ready() 末尾调用 check_and_show 即可。

# ── 教程注册表：scene_id → .dialogue 文件路径 ──

static var _tutorials: Dictionary = {
	"main_menu": "res://game/tutorial/dialogue/main_menu.dialogue",
	"deck_list": "res://game/tutorial/dialogue/deck_list.dialogue",
	"note_list": "res://game/tutorial/dialogue/note_list.dialogue",
	"study": "res://game/tutorial/dialogue/study.dialogue",
	"debug_panel": "res://game/tutorial/dialogue/debug_panel.dialogue",
	"ai_debug": "res://game/tutorial/dialogue/ai_debug.dialogue",
}

static var _progress: TutorialProgress = null
static var _pending_scene_ids: Dictionary = {}


## 懒加载教程进度（首次调用时从文件读取）。## 输入: 无。
## 输出: TutorialProgress。
static func _get_progress() -> TutorialProgress:
	if _progress == null:
		_progress = TutorialProgress.load_from_user()
	return _progress


## 检查场景教程是否已完成。## 输入: scene_id (String)。
## 输出: bool — 已完成返回 true。
static func is_completed(scene_id: String) -> bool:
	var p := _get_progress()
	return p.is_completed(scene_id) if p else true


## 场景入口：检查并显示教程（仅首次）。## 输入:
##   scene_id (String) — 场景标识，需在 _tutorials 中注册。
##   parent (Node) — 当前场景根节点。场景不在树上时不播放。
## 输出: 无。
static func check_and_show(scene_id: String, parent: Node) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if is_completed(scene_id) or _pending_scene_ids.has(scene_id):
		return
	if not _tutorials.has(scene_id):
		return

	var path: String = _tutorials[scene_id]
	if not ResourceLoader.exists(path):
		push_warning("[TutorialManager] 教程文件不存在: %s" % path)
		return

	var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if resource == null:
		push_warning("[TutorialManager] 教程资源加载失败: %s" % path)
		return

	_pending_scene_ids[scene_id] = true
	if not App.dialogue_closed.is_connected(_on_dialogue_closed):
		App.dialogue_closed.connect(_on_dialogue_closed)
	if not App.request_dialogue(resource, scene_id, false, parent):
		_pending_scene_ids.erase(scene_id)


## 教程对话结束：只记录对应场景，不销毁主逻辑的对话窗。## 输入: closed_key (String) — 刚关闭的对话标识。
## 输出: 无。
static func _on_dialogue_closed(closed_key: String) -> void:
	if not _pending_scene_ids.has(closed_key):
		return
	var scene_id: String = closed_key
	_pending_scene_ids.erase(scene_id)
	var p := _get_progress()
	p.mark_completed(scene_id)
	p.save_to_user()


## 重置所有教程进度（供调试/设置使用）。## 输入: 无。
## 输出: 无。
static func reset_all() -> void:
	var p := _get_progress()
	p.reset()
	p.save_to_user()
