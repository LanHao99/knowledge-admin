class_name NoteTypeEntity
extends RefCounted

# 笔记类型实体类，纯数据结构，对应数据库 note_types 表的一行记录。
# 笔记类型定义了笔记的字段结构（fields_schema）和卡片模板（card_templates），
# 决定该类型笔记有多少字段、字段名及顺序，以及如何从字段数据生成卡片。
# 不加入 Godot 节点树，由 NoteTypeDB 创建并返回，引用计数归零时自动释放。

## 唯一标识符，TEXT 主键。内置默认类型使用 "__default__"，用户自定义类型使用 UUID。
var id: String = ""

## 笔记类型名称，需全局唯一。如 "基础"、"完形填空"。
var name: String = ""

## 字段结构数组，每个元素为 {"name": String, "order": int}。
## 定义该类型笔记包含哪些字段及其顺序。DB 存取时序列化为 JSON 字符串。
var fields_schema: Array = []

## 卡片模板数组，每个元素为 {"name": String, "qfmt": String, "afmt": String}。
## qfmt 为正面模板（问题面），afmt 为背面模板（答案面），可用 {{字段名}} 引用字段。
## DB 存取时序列化为 JSON 字符串。
var card_templates: Array = []

## 创建时间的 ISO 8601 格式字符串。对应 created_at 字段（TEXT, NOT NULL）。
var created_at: String = ""


## 获取所有字段名列表（按 order 排序）。## 输出: Array[String] - 字段名数组。
func get_field_names() -> Array[String]:
	var names: Array[String] = []
	# 先按 order 排序再提取 name
	var sorted: Array = fields_schema.duplicate()
	sorted.sort_custom(_sort_by_order)
	for item in sorted:
		if typeof(item) == TYPE_DICTIONARY:
			var field_name: String = str(item.get("name", ""))
			if field_name != "":
				names.append(field_name)
	return names


## 获取卡片模板数量。## 输出: int - card_templates 数组长度。
func get_template_count() -> int:
	return card_templates.size()


## 判断是否为默认笔记类型（id == "__default__"）。## 输出: bool。
func is_default() -> bool:
	return id == "__default__"


## 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。
## fields_schema 和 card_templates 会被 JSON 序列化后存入数据库。
## 输出: Dictionary，键名与数据库 note_types 表字段一一对应。
func to_dict() -> Dictionary:
	var d := {
		"id": id,
		"name": name,
		"fields_schema": _array_to_json(fields_schema),
		"card_templates": _array_to_json(card_templates),
		"created_at": created_at
	}
	return d


## 从字典反序列化，用于数据层 SELECT 查询后将行记录转换为类型安全的实体对象。
## fields_schema 和 card_templates 字段为 JSON 字符串，会自动解析为 Array。
## 输入: d (Dictionary) - 数据库查询返回的行字典，键名应与 note_types 表字段对应。
func from_dict(d: Dictionary) -> void:
	if d.has("id"): id = str(d.get("id", ""))
	if d.has("name"): name = str(d.get("name", ""))
	if d.has("fields_schema"): fields_schema = _json_to_array(str(d.get("fields_schema", "[]")))
	if d.has("card_templates"): card_templates = _json_to_array(str(d.get("card_templates", "[]")))
	if d.has("created_at"): created_at = str(d.get("created_at", ""))


## 创建内置默认笔记类型（id="__default__", name="基础"）。
## 字段结构：正面（order=0）、背面（order=1）。
## 卡片模板：正面→背面（qfmt="{{正面}}", afmt="{{背面}}"）。
## 输出: NoteTypeEntity - 初始化好的默认笔记类型实体。
static func make_default_notetype() -> NoteTypeEntity:
	var entity := NoteTypeEntity.new()
	entity.id = "__default__"
	entity.name = "基础"
	entity.fields_schema = [
		{"name": "正面", "order": 0},
		{"name": "背面", "order": 1}
	]
	entity.card_templates = [
		{"name": "正面→背面", "qfmt": "{{正面}}", "afmt": "{{背面}}"}
	]
	entity.created_at = _now_iso8601()
	return entity


# ---- 内部辅助方法 ----

## 将 Array 序列化为 JSON 字符串。## 输入: arr (Array) - 待序列化的数组。
## 输出: String - JSON 字符串。序列化失败时返回 "[]"。
func _array_to_json(arr: Array) -> String:
	var json := JSON.new()
	var result: String = json.stringify(arr)
	if result == "":
		push_warning("[NoteTypeEntity] Array JSON 序列化失败，返回默认值 []")
		return "[]"
	return result


## 将 JSON 字符串解析为 Array。## 输入: json_str (String) - JSON 格式字符串。
## 输出: Array - 解析后的数组。解析失败返回空数组。
func _json_to_array(json_str: String) -> Array:
	if json_str.is_empty():
		return []
	var json := JSON.new()
	var parse_code: int = json.parse(json_str)
	if parse_code != OK:
		push_warning("[NoteTypeEntity] JSON 解析失败: %s" % json_str)
		return []
	if typeof(json.data) == TYPE_ARRAY:
		return json.data
	push_warning("[NoteTypeEntity] JSON 解析结果不是 Array: %s" % json_str)
	return []


## 按 order 字段排序的比较函数（供 sort_custom 使用）。## 输入: a (Dictionary), b (Dictionary)。
## 输出: bool - a.order < b.order 返回 true。
func _sort_by_order(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	return order_a < order_b


## 获取当前时间的 ISO 8601 格式字符串（UTC）。## 输出: String - ISO 8601 格式时间字符串。
static func _now_iso8601() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	# 格式: "YYYY-MM-DDTHH:MM:SSZ"
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"]
	]
