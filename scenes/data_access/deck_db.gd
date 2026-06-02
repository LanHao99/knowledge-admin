extends DBManager
class_name DeckDB


## 创建一个新牌组并返回创建后的实体对象。
##
## 输入:
##   name (String) - 牌组名称，不能为空。
##   parent_id (int) - 父牌组 ID，0 表示根级牌组。
##   sort_order (int) - 同级排序值，越小越靠前。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity。
func create_deck(name: String, parent_id: int = 0, sort_order: int = 0) -> Dictionary:
	var deck_name: String = name.strip_edges()
	if deck_name == "":
		return fail("DECK_NAME_EMPTY", "牌组名称不能为空")

	var now_ts: int = int(Time.get_unix_time_from_system())
	var sql := "INSERT INTO decks(name, parent_id, sort_order, is_archived, created_at, updated_at) VALUES(?, ?, ?, 0, ?, ?);"
	var parent_value: Variant = null
	if parent_id > 0:
		parent_value = parent_id

	var insert_result := execute_bind(sql, [deck_name, parent_value, sort_order, now_ts, now_ts])
	if not insert_result.get("success", false):
		return insert_result

	var id_result := last_insert_rowid()
	if not id_result.get("success", false):
		return id_result

	return get_deck_by_id(int(id_result.get("data", 0)))


## 根据 ID 查询单个牌组。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity；未找到时为 null。
func get_deck_by_id(deck_id: int) -> Dictionary:
	var result := fetch_one("SELECT * FROM decks WHERE id = ? LIMIT 1;", [deck_id])
	if not result.get("success", false):
		return result

	var row: Dictionary = result.get("data", {})
	if row.is_empty():
		return ok(null)

	return ok(_row_to_deck_entity(row))


## 根据名称查询单个牌组。
##
## 输入: name (String) - 牌组名称。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity；未找到时为 null。
func get_deck_by_name(name: String) -> Dictionary:
	var result := fetch_one("SELECT * FROM decks WHERE name = ? LIMIT 1;", [name])
	if not result.get("success", false):
		return result

	var row: Dictionary = result.get("data", {})
	if row.is_empty():
		return ok(null)

	return ok(_row_to_deck_entity(row))


## 更新已有牌组数据。
##
## 输入: deck (DeckEntity) - 待更新的牌组实体，要求 id > 0。
## 输出: 返回标准字典。成功时 `data` 为 null。
func update_deck(deck: DeckEntity) -> Dictionary:
	if deck == null or deck.id <= 0:
		return fail("DECK_ID_INVALID", "更新牌组时 deck.id 必须大于 0")

	var deck_name: String = deck.name.strip_edges()
	if deck_name == "":
		return fail("DECK_NAME_EMPTY", "牌组名称不能为空")

	var now_ts: int = int(Time.get_unix_time_from_system())
	var parent_value: Variant = null
	if deck.parent_id > 0:
		parent_value = deck.parent_id

	var sql := "UPDATE decks SET name = ?, parent_id = ?, sort_order = ?, is_archived = ?, updated_at = ? WHERE id = ?;"
	return execute_bind(sql, [
		deck_name,
		parent_value,
		deck.sort_order,
		1 if deck.is_archived else 0,
		now_ts,
		deck.id
	])


## 删除指定牌组。
##
## 输入: deck_id (int) - 要删除的牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 null。
func delete_deck(deck_id: int) -> Dictionary:
	return execute_bind("DELETE FROM decks WHERE id = ?;", [deck_id])


## 获取全部牌组列表。
##
## 输入: include_archived (bool) - 是否包含归档牌组。
## 输出: 返回标准字典。成功时 `data` 为 Array[DeckEntity]。
func get_all_decks(include_archived: bool = false) -> Dictionary:
	var sql := "SELECT * FROM decks"
	var params: Array = []
	if not include_archived:
		sql += " WHERE is_archived = 0"
	sql += " ORDER BY sort_order ASC, id ASC;"

	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	return ok(_rows_to_deck_entities(result.get("data", [])))


## 获取某个父牌组下的直接子牌组。
##
## 输入: parent_id (int) - 父牌组 ID；传 0 获取根级牌组。
## 输出: 返回标准字典。成功时 `data` 为 Array[DeckEntity]。
func get_child_decks(parent_id: int) -> Dictionary:
	var sql: String
	var params: Array = []
	if parent_id <= 0:
		sql = "SELECT * FROM decks WHERE parent_id IS NULL ORDER BY sort_order ASC, id ASC;"
	else:
		sql = "SELECT * FROM decks WHERE parent_id = ? ORDER BY sort_order ASC, id ASC;"
		params = [parent_id]

	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	return ok(_rows_to_deck_entities(result.get("data", [])))


## 组装牌组树结构。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为树节点数组，节点结构为 `{deck: DeckEntity, children: Array}`。
func get_deck_tree() -> Dictionary:
	var all_result := get_all_decks(true)
	if not all_result.get("success", false):
		return all_result

	var decks: Array[DeckEntity] = all_result.get("data", [])
	var node_map: Dictionary = {}
	for deck in decks:
		node_map[deck.id] = {
			"deck": deck,
			"children": []
		}

	var roots: Array = []
	for deck in decks:
		var node: Dictionary = node_map.get(deck.id, {})
		if deck.parent_id <= 0 or not node_map.has(deck.parent_id):
			roots.append(node)
		else:
			var parent_node: Dictionary = node_map.get(deck.parent_id, {})
			var children: Array = parent_node.get("children", [])
			children.append(node)
			parent_node["children"] = children
			node_map[deck.parent_id] = parent_node

	return ok(roots)


## 获取某个牌组下的卡片统计。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{new, learning, review, total}`。
func get_deck_card_counts(deck_id: int) -> Dictionary:
	var stats := {
		"new": 0,
		"learning": 0,
		"review": 0,
		"total": 0
	}

	var group_result := fetch_all("SELECT queue, COUNT(*) AS cnt FROM cards WHERE deck_id = ? GROUP BY queue;", [deck_id])
	if not group_result.get("success", false):
		return group_result

	var rows: Array = group_result.get("data", [])
	for row in rows:
		if not (row is Dictionary):
			continue
		var queue: int = int(row.get("queue", 0))
		var cnt: int = int(row.get("cnt", 0))
		match queue:
			CardEntity.QUEUE_NEW:
				stats["new"] = cnt
			CardEntity.QUEUE_LEARNING:
				stats["learning"] = cnt
			CardEntity.QUEUE_REVIEW:
				stats["review"] = cnt

	var total_result := count("cards", "deck_id = ?", [deck_id])
	if not total_result.get("success", false):
		return total_result
	stats["total"] = int(total_result.get("data", 0))

	return ok(stats)


## 将单行查询结果转换为 DeckEntity。
##
## 输入: row (Dictionary) - decks 表的一行数据。
## 输出: DeckEntity - 反序列化后的实体对象。
func _row_to_deck_entity(row: Dictionary) -> DeckEntity:
	var entity := DeckEntity.new()
	entity.from_dict(row)
	return entity


## 将多行查询结果转换为实体数组。
##
## 输入: rows (Array) - decks 表的多行数据。
## 输出: Array[DeckEntity] - 牌组实体数组。
func _rows_to_deck_entities(rows: Array) -> Array[DeckEntity]:
	var entities: Array[DeckEntity] = []
	for row in rows:
		if row is Dictionary:
			entities.append(_row_to_deck_entity(row))
	return entities
