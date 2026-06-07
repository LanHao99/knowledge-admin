class_name TutorialProgress
extends Resource
## 教程进度存档资源，持久化保存于 user://tutorial_progress.tres。
## 记录每个场景的教程是否已观看完成。
## 由 TutorialManager 负责读写。


## 存档文件路径
const SAVE_PATH: String = "user://tutorial_progress.tres"

## 已完成教程的场景 ID 列表。[scene_id, ...]
@export var completed_ids: Array[String] = []


## 保存到 user:// 路径。## 输入: 无。
## 输出: 返回标准字典。
func save_to_user() -> Dictionary:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK:
		return {"success": false, "error": "SAVE_FAILED", "message": "保存 TutorialProgress 失败，错误码: %d" % err}
	return {"success": true, "data": true}


## 从 user:// 加载或新建。文件不存在时返回全新默认实例。## 输入: 无。
## 输出: TutorialProgress 实例。
static func load_from_user() -> TutorialProgress:
	if not FileAccess.file_exists(SAVE_PATH):
		return TutorialProgress.new()
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as TutorialProgress
	if loaded == null:
		return TutorialProgress.new()
	return loaded


## 检查某个场景的教程是否已完成。## 输入: scene_id (String)。
## 输出: bool。
func is_completed(scene_id: String) -> bool:
	return scene_id in completed_ids


## 标记场景教程为已完成（去重）。## 输入: scene_id (String)。
## 输出: 无。
func mark_completed(scene_id: String) -> void:
	if not is_completed(scene_id):
		completed_ids.append(scene_id)


## 重置所有教程进度（保留同一实例）。## 输入: 无。
## 输出: 无。
func reset() -> void:
	completed_ids.clear()
