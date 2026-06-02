class_name DeckEntity
extends RefCounted

# 牌组实体类，纯数据结构，对应数据库 decks 表的一行记录。
# 用于在 Manager（逻辑层）和 DB（数据层）之间传递牌组数据，替代裸 Dictionary。
# 不加入 Godot 节点树，由调用方持有引用，引用计数归零时自动释放。

## 唯一标识符（自增主键）。0 表示尚未写入数据库的临时对象。
var id: int = 0

## 牌组名称，对应数据库 name 字段（TEXT, NOT NULL）。
var name: String = ""

## 父牌组 ID，0 表示根级牌组（无父节点）。对应 parent_id 字段（INTEGER）。
var parent_id: int = 0

## 同级牌组中的排序权重，数值越小越靠前。对应 sort_order 字段（INTEGER, default 0）。
var sort_order: int = 0

## 是否已归档。归档牌组在常规列表中隐藏，但数据保留。对应 is_archived 字段（INTEGER 0/1, default 0）。
var is_archived: bool = false

## 创建时间的 Unix 时间戳（秒级）。对应 created_at 字段（INTEGER, NOT NULL）。
var created_at: int = 0

## 最后更新时间的 Unix 时间戳（秒级）。对应 updated_at 字段（INTEGER, NOT NULL）。
var updated_at: int = 0


## 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。
##
## 输出: Dictionary，键名与数据库 decks 表字段一一对应。id 为 0 时不写入（让数据库自增）。
func to_dict() -> Dictionary:
	var d := {
		"name": name,
		"parent_id": parent_id if parent_id > 0 else null,
		"sort_order": sort_order,
		"is_archived": 1 if is_archived else 0,
		"created_at": created_at,
		"updated_at": updated_at
	}
	if id > 0:
		d["id"] = id
	return d


## 从字典反序列化，用于数据层 SELECT 查询后将行记录转换为类型安全的实体对象。
##
## 输入: d (Dictionary) - 数据库查询返回的行字典，键名应与 decks 表字段对应。
func from_dict(d: Dictionary) -> void:
	if d.has("id"):       id = int(d.get("id", 0))
	if d.has("name"):      name = str(d.get("name", ""))
	if d.has("parent_id"): parent_id = int(d.get("parent_id", 0))
	if d.has("sort_order"): sort_order = int(d.get("sort_order", 0))
	if d.has("is_archived"): is_archived = bool(int(d.get("is_archived", 0)))
	if d.has("created_at"): created_at = int(d.get("created_at", 0))
	if d.has("updated_at"): updated_at = int(d.get("updated_at", 0))


## 判断当前牌组是否为根级（无父节点）。
##
## 输出: bool，parent_id == 0 时返回 true。
func is_root() -> bool:
	return parent_id == 0


## 返回牌组路径层级分隔符（用于未来实现牌组全路径显示）。
##
## 输出: String，固定返回 "::"（对齐 Anki 的牌组层级表示习惯）。
func get_path_separator() -> String:
	return "::"


## 返回牌组在 UI 中显示的完整路径字符串（如 "语言::日语::N1词汇"）。
## 当前为占位实现，未来可配合 DeckManager 的 get_deck_tree 递归拼接父节点名称。
##
## 输入: parent_name (String) - 父牌组名称，空字符串表示根级。
## 输出: String，拼接后的完整路径。
func get_full_path(parent_name: String = "") -> String:
	if parent_name.is_empty():
		return name
	return parent_name + get_path_separator() + name


## 生成一个当前时间的 Unix 时间戳，用于新建或更新时填充 created_at / updated_at。
##
## 输出: int，当前系统时间的 Unix 时间戳（秒级）。
static func now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())
