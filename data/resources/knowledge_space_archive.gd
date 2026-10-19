class_name KnowledgeSpaceArchive
extends Resource
## 知识空间的剧情档案；正文及解锁条件由 Inspector 编辑。

@export var archive_id: String = ""
@export var title: String = ""
@export_multiline var content: String = ""
## 空字符串始终显示；非空时使用章节/剧情形式的完整完成记录。
@export var required_story_record: String = ""
@export var spatial_position: Vector3 = Vector3.ZERO


## 按完整剧情记录判断档案是否可见，不改变剧情存档。## 输入: progress (StoryProgress) - 当前进度，可为 null。
## 输出: bool - 是否已解锁。
func is_unlocked(progress: StoryProgress) -> bool:
	return required_story_record.is_empty() or (progress != null and progress.is_dialogue_completed(required_story_record))
