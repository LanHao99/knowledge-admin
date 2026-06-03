class_name NoteEntity
extends RefCounted

# 笔记实体类，纯数据结构，对应数据库 notes 表的一行记录。
# 笔记是"知识单元"的载体，包含字段数据（fields_data）和标签（tags）。
# 一个 Note 可通过模板生成多张 Card（见 CardEntity.note_id）。
# 不加入 Godot 节点树，由 Manager 持有引用，引用计数归零时自动释放。

## 唯一标识符（自增主键）。0 表示尚未写入数据库的临时对象。
var id: int = 0

## 笔记类型 ID，用于决定该笔记使用哪种模板生成卡片。对应 note_type_id 字段（INTEGER, NOT NULL）。
## 当前 schema 中 note_types 表尚未创建，此字段为预留，默认 0。
var note_type_id: int = 0

## 字段数据字典，键为字段名，值为字段内容。对应数据库中 JSON 序列化后的 fields_data（TEXT）。
## 示例: {"正面": "你好", "背面": "Hello"}
var fields_data: Dictionary = {}

## 标签数组，用于分类和检索。当前为预留字段，数据库 schema 中尚未独立建 tags 列，
## 未来可通过独立 tag 表或逗号分隔字符串扩展。
var tags: Array[String] = []

## 所属牌组 ID，用于按牌组分组和过滤。对应 deck_id 字段（INTEGER, NOT NULL）。
var deck_id: int = 0

## 创建时间的 Unix 时间戳（秒级）。对应 created_at 字段（INTEGER, NOT NULL）。
var created_at: int = 0


## 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。
## fields_data 字典会被 JSON 序列化后存入数据库。## 输出: Dictionary，键名与数据库 notes 表字段一一对应。
func to_dict() -> Dictionary:
	var d := {
		"note_type_id": note_type_id,
		"deck_id": deck_id,
		"fields_data": fields_to_json(),
		"created_at": created_at
	}
	if id > 0:
		d["id"] = id
	return d


## 从字典反序列化，用于数据层 SELECT 查询后将行记录转换为类型安全的实体对象。
## 会自动调用 fields_from_json() 将 JSON 字符串解析为 fields_data 字典。## 输入: d (Dictionary) - 数据库查询返回的行字典，键名应与 notes 表字段对应。
func from_dict(d: Dictionary) -> void:
	if d.has("id"): id = int(d.get("id", 0))
	if d.has("note_type_id"): note_type_id = int(d.get("note_type_id", 0))
	if d.has("deck_id"): deck_id = int(d.get("deck_id", 0))
	if d.has("fields_data"): fields_from_json(str(d.get("fields_data", "{}")))
	if d.has("created_at"): created_at = int(d.get("created_at", 0))


## 获取指定字段的内容。## 输入: field_name (String) - 字段名，如 "正面"、"背面"。
## 输出: String，字段值。字段不存在时返回空字符串。
func get_field(field_name: String) -> String:
	return str(fields_data.get(field_name, ""))


## 设置指定字段的内容。## 输入:
##   field_name (String) - 字段名。
##   value (String) - 要写入的内容。
func set_field(field_name: String, value: String) -> void:
	fields_data[field_name] = value


## 将 fields_data 字典序列化为 JSON 字符串，用于写入数据库。## 输出: String，JSON 格式的字符串。序列化失败时返回 "{}"。
func fields_to_json() -> String:
	var json := JSON.new()
	var result := json.stringify(fields_data)
	if result == "":
		push_warning("[NoteEntity] fields_data JSON 序列化失败，返回默认值 {}")
		return "{}"
	return result


## 将 JSON 字符串解析为 fields_data 字典，用于从数据库读取后恢复。## 输入: json_str (String) - JSON 格式的字符串。
func fields_from_json(json_str: String) -> void:
	if json_str.is_empty():
		fields_data = {}
		return
	var json := JSON.new()
	var parse_code: int = json.parse(json_str)
	if parse_code != OK:
		push_warning("[NoteEntity] fields_data JSON 解析失败: %s" % json_str)
		fields_data = {}
		return
	if typeof(json.data) == TYPE_DICTIONARY:
		fields_data = json.data
	else:
		push_warning("[NoteEntity] fields_data JSON 解析结果不是 Dictionary: %s" % json_str)
		fields_data = {}


## 获取该笔记对应的卡片应该归属的默认牌组 ID。
## 当前为占位实现：返回 0 表示由调用方（NoteManager）根据业务规则决定。
## 未来可在 note_types 表中扩展 default_deck_id 字段。## 输出: int，默认牌组 ID。
func get_default_deck_id() -> int:
	return 0


## 生成一个当前时间的 Unix 时间戳。## 输出: int，当前系统时间的 Unix 时间戳（秒级）。
static func now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())
