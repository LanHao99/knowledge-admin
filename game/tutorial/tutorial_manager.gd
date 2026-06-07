extends Node
## 教程管理器（Autoload）。
## 负责检测场景首次进入 → 实例化 StoryDialogueOverlay → 播放教程对话 → 记录完成。
## 各场景在 _ready() 末尾调用 check_and_show("scene_id", self) 即可。

# ── 常量 ──

## 复用的故事对话覆盖层场景
const OVERLAY_SCENE: String = "res://game/dialogue/story_dialogue_overlay.tscn"

# ── 教程注册表：scene_id → .dialogue 文件路径 ──

var _tutorials: Dictionary = {
	"main_menu": "res://game/tutorial/dialogue/main_menu.dialogue",
	"deck_list": "res://game/tutorial/dialogue/deck_list.dialogue",
	"note_list": "res://game/tutorial/dialogue/note_list.dialogue",
	"study": "res://game/tutorial/dialogue/study.dialogue",
	"debug_panel": "res://game/tutorial/dialogue/debug_panel.dialogue",
	"ai_debug": "res://game/tutorial/dialogue/ai_debug.dialogue",
}

var _progress: TutorialProgress = null


## 加载教程进度存档。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_progress = TutorialProgress.load_from_user()


## 检查场景教程是否已完成。## 输入: scene_id (String)。
## 输出: bool — 已完成返回 true。
func is_completed(scene_id: String) -> bool:
	return _progress.is_completed(scene_id) if _progress else true


## 场景入口：检查并显示教程（仅首次）。## 输入:
##   scene_id (String) — 场景标识，需在 _tutorials 中注册。
##   parent (Node) — 场景根节点，用于将 overlay 添加到场景树。
## 输出: 无。
func check_and_show(scene_id: String, parent: Node) -> void:
	if is_completed(scene_id):
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

	var overlay_scene := load(OVERLAY_SCENE) as PackedScene
	if overlay_scene == null:
		push_warning("[TutorialManager] 覆盖层场景加载失败")
		return

	var overlay := overlay_scene.instantiate() as StoryDialogueOverlay
	if overlay == null:
		push_warning("[TutorialManager] 覆盖层实例化失败")
		return

	overlay.dialogue_key = scene_id
	# 等待 overlay._ready() 执行完成后启动对话
	overlay.ready.connect(func():
		overlay.start(resource, scene_id)
	, CONNECT_ONE_SHOT)
	overlay.dialogue_finished.connect(_on_tutorial_finished.bind(scene_id, overlay))

	parent.get_tree().root.add_child(overlay)


## 教程对话结束回调：标记完成、保存、销毁 overlay。## 输入:
##   scene_id (String) — 场景标识。
##   overlay (StoryDialogueOverlay) — 要销毁的覆盖层实例。
## 输出: 无。
func _on_tutorial_finished(scene_id: String, overlay: StoryDialogueOverlay) -> void:
	_progress.mark_completed(scene_id)
	_progress.save_to_user()
	if is_instance_valid(overlay):
		overlay.queue_free()


## 重置所有教程进度（供调试/设置使用）。## 输入: 无。
## 输出: 无。
func reset_all() -> void:
	_progress.reset()
	_progress.save_to_user()
