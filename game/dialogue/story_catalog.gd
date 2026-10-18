class_name StoryCatalog
extends RefCounted
## 剧情目录的纯查询。负责完成记录迁移、下一段预览和跳转重排，不写存档。


const DERIVED_FLAGS: Array[String] = [
	"bond_tier",
	"bond_tier_1_reached",
	"bond_tier_2_reached",
	"bond_tier_3_reached",
	"bond_value",
]


## 把章节和剧情标识拼成完成记录。## 输入: chapter、dialogue_key。
## 输出: String，格式为「章节/剧情」。
static func record_key(chapter: String, dialogue_key: String) -> String:
	return StoryProgress.record_key(chapter, dialogue_key)


## 返回章节的界面名称。## 输入: chapter (String)。
## 输出: String。未知章节时返回原标识。
static func chapter_title(chapter: String) -> String:
	match chapter:
		"chapter_1":
			return "第一章"
		"chapter_2":
			return "第二章"
		_:
			return chapter if not chapter.is_empty() else "未设置"


## 按主线顺序插入羁绊剧情，羁绊紧跟其前置主线。## 输入: chapter_order、definitions、bonds。
## 输出: Array[Dictionary]，每项含 chapter、key、kind、path、record。
static func ordered_entries(chapter_order: Array, definitions: Dictionary, bonds: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for chapter_variant in chapter_order:
		var chapter := str(chapter_variant)
		var mains: Dictionary = definitions.get(chapter, {})
		for key_variant in mains.keys():
			var key := str(key_variant)
			result.append(_main_entry(chapter, key, str(mains[key_variant])))
			for bond_variant in bonds:
				if typeof(bond_variant) != TYPE_DICTIONARY:
					continue
				var bond: Dictionary = bond_variant
				if str(bond.get("chapter", "")) == chapter and str(bond.get("prerequisite", "")) == key:
					result.append(bond)
	return result


## 预览下一段剧情，不修改进度、章节或完成记录。## 输入: progress、chapter_order、definitions、memory_bonds、epilogue_bonds。
## 输出: Dictionary。没有下一段时为空。
static func preview_next(
	progress: StoryProgress,
	chapter_order: Array,
	definitions: Dictionary,
	memory_bonds: Array,
	epilogue_bonds: Array
) -> Dictionary:
	if progress == null:
		return {}
	for bond_variant in memory_bonds:
		if typeof(bond_variant) != TYPE_DICTIONARY:
			continue
		var bond: Dictionary = bond_variant
		if _bond_ready(progress, bond, definitions, false):
			return bond
	for bond_variant in epilogue_bonds:
		if typeof(bond_variant) != TYPE_DICTIONARY:
			continue
		var bond: Dictionary = bond_variant
		if _bond_ready(progress, bond, definitions, true):
			return bond
	var current := _first_incomplete_main(progress, progress.current_chapter, definitions)
	if not current.is_empty():
		return current
	var next_chapter := _next_chapter(progress.current_chapter, chapter_order)
	if next_chapter.is_empty():
		return {}
	return _first_main(next_chapter, definitions)


## 计算跳转后的完成记录、阈值和章节，不修改原存档。## 输入: progress、entries、chapter、key。
## 输出: Dictionary。失败时 success 为 false。
static func plan_jump(progress: StoryProgress, entries: Array[Dictionary], chapter: String, key: String) -> Dictionary:
	var index := -1
	for i in entries.size():
		var entry: Dictionary = entries[i]
		if str(entry.get("chapter", "")) == chapter and str(entry.get("key", "")) == key:
			index = i
			break
	if index < 0:
		return {"success": false, "message": "找不到要跳转的剧情"}
	var remove_main: Dictionary = {}
	var remove_bond: Dictionary = {}
	var before_main: Array[String] = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		if i < index:
			if str(entry.get("kind", "")) == "main":
				before_main.append(str(entry.get("record", "")))
		elif str(entry.get("kind", "")) == "main":
			remove_main[str(entry.get("record", ""))] = true
		else:
			remove_bond[str(entry.get("key", ""))] = true
	var completed: Array[String] = []
	var seen: Dictionary = {}
	if progress != null:
		for record_variant in progress.completed_dialogues:
			var record := str(record_variant)
			if remove_main.has(record) or seen.has(record):
				continue
			seen[record] = true
			completed.append(record)
	for record in before_main:
		if seen.has(record):
			continue
		seen[record] = true
		completed.append(record)
	var kept_bonds: Array[String] = []
	var seen_bond: Dictionary = {}
	if progress != null:
		for bond_variant in progress.bond_dialogues_triggered:
			var bond_key := str(bond_variant)
			if remove_bond.has(bond_key) or seen_bond.has(bond_key):
				continue
			seen_bond[bond_key] = true
			kept_bonds.append(bond_key)
	return {
		"success": true,
		"chapter": chapter,
		"key": key,
		"kind": str(entries[index].get("kind", "")),
		"path": str(entries[index].get("path", "")),
		"completed": completed,
		"bonds": kept_bonds,
		"main_before": before_main.size(),
		"threshold": 10 + 5 * before_main.size(),
	}


## 把旧的短完成记录归到最早章节，未知记录原样保留。## 输入: records、definitions、chapter_order。
## 输出: Dictionary，含 changed 和 records。
static func migrate_completed(records: Array, definitions: Dictionary, chapter_order: Array) -> Dictionary:
	var changed := false
	var output: Array[String] = []
	var seen: Dictionary = {}
	for item in records:
		var record := str(item)
		var migrated := record
		if not StoryProgress.is_composite_record(record):
			var owner := earliest_chapter(record, definitions, chapter_order)
			if not owner.is_empty():
				migrated = record_key(owner, record)
		if migrated != record or seen.has(migrated):
			changed = true
		if seen.has(migrated):
			continue
		seen[migrated] = true
		output.append(migrated)
	if output.size() != records.size():
		changed = true
	return {"changed": changed, "records": output}


## 查找短标识最早出现的章节。## 输入: key、definitions、chapter_order。
## 输出: String。没有对应主线时返回空字符串。
static func earliest_chapter(key: String, definitions: Dictionary, chapter_order: Array) -> String:
	for chapter_variant in chapter_order:
		var chapter := str(chapter_variant)
		var mains: Variant = definitions.get(chapter, {})
		if mains is Dictionary and (mains as Dictionary).has(key):
			return chapter
	return ""


## 比较两份完整剧情快照。## 输入: left、right。
## 输出: bool。字段和标记都相同时返回 true。
static func same_snapshot(left: Dictionary, right: Dictionary) -> bool:
	if str(left.get("current_chapter", "")) != str(right.get("current_chapter", "")):
		return false
	if not _same_editable(left, right):
		return false
	return _same_flags(left.get("flags", {}), right.get("flags", {}))


## 比较草稿可编辑字段，不含章节。## 输入: left、right。
## 输出: bool。
static func same_editable(left: Dictionary, right: Dictionary) -> bool:
	return _same_editable(left, right)


## 合并普通标记，保留复杂值，忽略羁绊派生标记。## 输入: base_flags、draft_flags。
## 输出: Dictionary。失败时 success 为 false。
static func merge_flags(base_flags: Dictionary, draft_flags: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant in draft_flags.keys():
		var name := str(key_variant)
		if name in DERIVED_FLAGS:
			continue
		var value: Variant = draft_flags[key_variant]
		if base_flags.has(name) and is_complex_value(base_flags[name]):
			if not values_equal(value, base_flags[name]):
				return {"success": false, "message": "复杂标记“%s”不能修改" % name}
			result[name] = _duplicate_value(base_flags[name])
			continue
		if not is_simple_value(value):
			return {"success": false, "message": "标记“%s”只支持布尔、数字、字符串和空值" % name}
		result[name] = value
	for key_variant in base_flags.keys():
		var name := str(key_variant)
		if name in DERIVED_FLAGS or result.has(name):
			continue
		if is_complex_value(base_flags[key_variant]):
			result[name] = _duplicate_value(base_flags[key_variant])
	return {"success": true, "flags": result}


## 判断标记值是否可由测试台编辑。## 输入: value。
## 输出: bool。布尔、整数、小数、字符串和空值返回 true。
static func is_simple_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		_:
			return false


## 判断标记值是否应只读保留。## 输入: value。
## 输出: bool。
static func is_complex_value(value: Variant) -> bool:
	return not is_simple_value(value)


## 判断标记名是否由好感度自动生成。## 输入: flag_name。
## 输出: bool。
static func is_derived_flag(flag_name: String) -> bool:
	return flag_name in DERIVED_FLAGS


## 比较两个变体，数组和字典按内容递归比较。## 输入: left、right。
## 输出: bool。
static func values_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		if (left is float or left is int) and (right is float or right is int):
			return is_equal_approx(float(left), float(right))
		return false
	if left is float:
		return is_equal_approx(float(left), float(right))
	if left is Array and right is Array:
		return _same_array(left, right)
	if left is Dictionary and right is Dictionary:
		return _same_flags(left, right)
	return left == right


## 组装一条主线条目。## 输入: chapter、key、path。
## 输出: Dictionary。
static func _main_entry(chapter: String, key: String, path: String) -> Dictionary:
	return {
		"chapter": chapter,
		"key": key,
		"kind": "main",
		"path": path,
		"record": record_key(chapter, key),
		"tier": 0,
		"prerequisite": "",
	}


## 返回当前章节第一段未完成主线。## 输入: progress、chapter、definitions。
## 输出: Dictionary。没有时为空。
static func _first_incomplete_main(progress: StoryProgress, chapter: String, definitions: Dictionary) -> Dictionary:
	if not definitions.has(chapter):
		return {}
	var mains: Dictionary = definitions[chapter]
	for key_variant in mains.keys():
		var key := str(key_variant)
		if not progress.is_chapter_dialogue_completed(chapter, key):
			return _main_entry(chapter, key, str(mains[key_variant]))
	return {}


## 返回章节登记表中的第一段主线。## 输入: chapter、definitions。
## 输出: Dictionary。章节不存在时为空。
static func _first_main(chapter: String, definitions: Dictionary) -> Dictionary:
	if not definitions.has(chapter):
		return {}
	var mains: Dictionary = definitions[chapter]
	for key_variant in mains.keys():
		return _main_entry(chapter, str(key_variant), str(mains[key_variant]))
	return {}


## 按章节顺序取下一章。## 输入: chapter、chapter_order。
## 输出: String。已经是最后一章时返回空字符串。
static func _next_chapter(chapter: String, chapter_order: Array) -> String:
	var index := -1
	for i in chapter_order.size():
		if str(chapter_order[i]) == chapter:
			index = i
			break
	if index < 0 or index >= chapter_order.size() - 1:
		return ""
	return str(chapter_order[index + 1])


## 判断羁绊剧情当前是否满足自然触发条件。## 输入: progress、bond、definitions、epilogue。
## 输出: bool。
static func _bond_ready(progress: StoryProgress, bond: Dictionary, definitions: Dictionary, epilogue: bool) -> bool:
	if progress.get_bond_tier() < int(bond.get("tier", 1)):
		return false
	var chapter := str(bond.get("chapter", ""))
	if not progress.is_chapter_dialogue_completed(chapter, str(bond.get("prerequisite", ""))):
		return false
	if progress.is_bond_dialogue_triggered(str(bond.get("key", ""))):
		return false
	if epilogue and not _chapter_complete(progress, progress.current_chapter, definitions):
		return false
	return true


## 判断章节里的主线是否都已完成。## 输入: progress、chapter、definitions。
## 输出: bool。
static func _chapter_complete(progress: StoryProgress, chapter: String, definitions: Dictionary) -> bool:
	if not definitions.has(chapter):
		return false
	var mains: Dictionary = definitions[chapter]
	if mains.is_empty():
		return false
	for key_variant in mains.keys():
		if not progress.is_chapter_dialogue_completed(chapter, str(key_variant)):
			return false
	return true


## 比较进度、阈值、好感、冷却和完成记录。## 输入: left、right。
## 输出: bool。
static func _same_editable(left: Dictionary, right: Dictionary) -> bool:
	if int(left.get("total_progress", -1)) != int(right.get("total_progress", -2)):
		return false
	if int(left.get("trigger_threshold", -1)) != int(right.get("trigger_threshold", -2)):
		return false
	if int(left.get("bond", -1)) != int(right.get("bond", -2)):
		return false
	if not is_equal_approx(float(left.get("last_triggered_at", -1.0)), float(right.get("last_triggered_at", -2.0))):
		return false
	if not _same_array(left.get("completed_dialogues", []), right.get("completed_dialogues", [])):
		return false
	if not _same_array(left.get("bond_dialogues_triggered", []), right.get("bond_dialogues_triggered", [])):
		return false
	return _same_flags(left.get("flags", {}), right.get("flags", {}))


## 按顺序比较两个数组。## 输入: left、right。
## 输出: bool。
static func _same_array(left: Variant, right: Variant) -> bool:
	if not (left is Array) or not (right is Array):
		return false
	var left_array: Array = left
	var right_array: Array = right
	if left_array.size() != right_array.size():
		return false
	for i in left_array.size():
		if not values_equal(left_array[i], right_array[i]):
			return false
	return true


## 比较两个标记字典。## 输入: left、right。
## 输出: bool。
static func _same_flags(left: Variant, right: Variant) -> bool:
	if not (left is Dictionary) or not (right is Dictionary):
		return false
	var left_flags: Dictionary = left
	var right_flags: Dictionary = right
	if left_flags.size() != right_flags.size():
		return false
	for key_variant in left_flags.keys():
		if not right_flags.has(key_variant) or not values_equal(left_flags[key_variant], right_flags[key_variant]):
			return false
	return true


## 复制数组或字典，其他值原样返回。## 输入: value。
## 输出: Variant。
static func _duplicate_value(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value
