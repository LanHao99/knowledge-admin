extends Manager
class_name DeckManager


var _deck_db: DeckDB = null


## 注入 DeckDB 数据仓库实例。
##
## 输入: deck_db (DeckDB) - 牌组仓库对象。
## 输出: 无。
func set_deck_db(deck_db: DeckDB) -> void:
	_deck_db = deck_db


## 获取当前注入的 DeckDB 引用。
##
## 输入: 无。
## 输出: DeckDB - 牌组仓库对象；未注入时为 null。
func get_deck_db() -> DeckDB:
	return _deck_db


## 创建牌组。
##
## 输入:
##   name (String) - 牌组名称。
##   parent_id (int) - 父牌组 ID，0 表示根级。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity。
func create_deck(name: String, parent_id: int = 0) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")

	var deck_name: String = name.strip_edges()
	if deck_name == "":
		return fail("DECK_NAME_EMPTY", "牌组名称不能为空")

	if parent_id > 0:
		var parent_result := _deck_db.get_deck_by_id(parent_id)
		if not parent_result.get("success", false):
			return parent_result
		if parent_result.get("data", null) == null:
			return fail("DECK_PARENT_NOT_FOUND", "父牌组不存在")

	if _is_name_conflict(deck_name, parent_id):
		return fail("DECK_NAME_DUPLICATE", "同级牌组名称重复")

	var tx_result := run_in_databases_transaction([_deck_db], func() -> Dictionary:
		var created_result := _deck_db.create_deck(deck_name, parent_id)
		if not created_result.get("success", false):
			return created_result
		var deck: DeckEntity = created_result.get("data", null)
		if deck == null:
			return fail("DECK_CREATE_FAILED", "创建牌组后未返回实体")
		_notify_created("deck", deck.id)
		return ok(deck)
	)
	return tx_result


## 重命名牌组。
##
## 输入:
##   deck_id (int) - 牌组 ID。
##   new_name (String) - 新名称。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity。
func rename_deck(deck_id: int, new_name: String) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")

	var trimmed_name: String = new_name.strip_edges()
	if trimmed_name == "":
		return fail("DECK_NAME_EMPTY", "牌组名称不能为空")

	var current_result := _deck_db.get_deck_by_id(deck_id)
	if not current_result.get("success", false):
		return current_result
	var deck: DeckEntity = current_result.get("data", null)
	if deck == null:
		return fail("DECK_NOT_FOUND", "牌组不存在")

	if _is_name_conflict(trimmed_name, deck.parent_id, deck.id):
		return fail("DECK_NAME_DUPLICATE", "同级牌组名称重复")

	deck.name = trimmed_name
	var update_result := _deck_db.update_deck(deck)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("deck", deck_id)
	return ok(deck)


## 移动牌组到新的父节点。
##
## 输入:
##   deck_id (int) - 牌组 ID。
##   new_parent_id (int) - 新父牌组 ID，0 表示移动到根级。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity。
func move_deck(deck_id: int, new_parent_id: int) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")

	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")
	if new_parent_id == deck_id:
		return fail("DECK_PARENT_INVALID", "不能把牌组移动到自己下面")

	var deck_result := _deck_db.get_deck_by_id(deck_id)
	if not deck_result.get("success", false):
		return deck_result
	var deck: DeckEntity = deck_result.get("data", null)
	if deck == null:
		return fail("DECK_NOT_FOUND", "牌组不存在")

	if new_parent_id > 0:
		var parent_result := _deck_db.get_deck_by_id(new_parent_id)
		if not parent_result.get("success", false):
			return parent_result
		if parent_result.get("data", null) == null:
			return fail("DECK_PARENT_NOT_FOUND", "新父牌组不存在")
		if _is_descendant(new_parent_id, deck_id):
			return fail("DECK_MOVE_LOOP", "不能把牌组移动到自己的子树中")

	if _is_name_conflict(deck.name, new_parent_id, deck.id):
		return fail("DECK_NAME_DUPLICATE", "目标父级下已存在同名牌组")

	deck.parent_id = max(new_parent_id, 0)
	var update_result := _deck_db.update_deck(deck)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("deck", deck_id)
	return ok(deck)


## 归档或恢复牌组。
##
## 输入:
##   deck_id (int) - 牌组 ID。
##   archived (bool) - true 表示归档，false 表示恢复。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity。
func archive_deck(deck_id: int, archived: bool = true) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")

	var deck_result := _deck_db.get_deck_by_id(deck_id)
	if not deck_result.get("success", false):
		return deck_result
	var deck: DeckEntity = deck_result.get("data", null)
	if deck == null:
		return fail("DECK_NOT_FOUND", "牌组不存在")

	deck.is_archived = archived
	var update_result := _deck_db.update_deck(deck)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("deck", deck_id)
	return ok(deck)


## 删除牌组（硬删除）。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 null。
func delete_deck(deck_id: int) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")

	var deck_result := _deck_db.get_deck_by_id(deck_id)
	if not deck_result.get("success", false):
		return deck_result
	if deck_result.get("data", null) == null:
		return fail("DECK_NOT_FOUND", "牌组不存在")

	var cards_count_result := _deck_db.count("cards", "deck_id = ?", [deck_id])
	if not cards_count_result.get("success", false):
		return cards_count_result
	if int(cards_count_result.get("data", 0)) > 0:
		return fail("DECK_HAS_CARDS", "该牌组下仍有卡片，请先转移或删除")

	var delete_result := _deck_db.delete_deck(deck_id)
	if not delete_result.get("success", false):
		return delete_result

	_notify_deleted("deck", deck_id)
	return ok()


## 获取单个牌组。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity 或 null。
func get_deck(deck_id: int) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")
	return _deck_db.get_deck_by_id(deck_id)


## 按名称获取牌组。
##
## 输入: name (String) - 牌组名称。
## 输出: 返回标准字典。成功时 `data` 为 DeckEntity 或 null。
func get_deck_by_name(name: String) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")
	return _deck_db.get_deck_by_name(name)


## 获取全部牌组列表（默认不含归档）。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 Array[DeckEntity]。
func get_all_decks() -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")
	return _deck_db.get_all_decks(false)


## 获取牌组树结构。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为树节点数组。
func get_deck_tree() -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")
	return _deck_db.get_deck_tree()


## 获取牌组卡片统计。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{new, learning, review, total}`。
func get_deck_counts(deck_id: int) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")
	return _deck_db.get_deck_card_counts(deck_id)


## 检查同级中是否存在同名牌组。
##
## 输入:
##   name (String) - 牌组名称。
##   parent_id (int) - 父牌组 ID。
##   exclude_id (int) - 可选排除的牌组 ID（用于重命名场景）。
## 输出: bool。存在冲突返回 true。
func _is_name_conflict(name: String, parent_id: int, exclude_id: int = 0) -> bool:
	if _deck_db == null:
		return false

	var sql: String
	var params: Array = []
	if parent_id <= 0:
		sql = "SELECT id FROM decks WHERE parent_id IS NULL AND name = ?"
		params.append(name)
	else:
		sql = "SELECT id FROM decks WHERE parent_id = ? AND name = ?"
		params.append(parent_id)
		params.append(name)

	if exclude_id > 0:
		sql += " AND id != ?"
		params.append(exclude_id)

	sql += " LIMIT 1;"
	var result := _deck_db.fetch_one(sql, params)
	if not result.get("success", false):
		return false
	var row: Dictionary = result.get("data", {})
	return not row.is_empty()


## 判断 candidate_parent_id 是否位于 deck_id 的子树中。
##
## 输入:
##   candidate_parent_id (int) - 待检查的新父节点 ID。
##   deck_id (int) - 当前牌组 ID。
## 输出: bool。会形成循环时返回 true。
func _is_descendant(candidate_parent_id: int, deck_id: int) -> bool:
	if _deck_db == null:
		return false
	if candidate_parent_id <= 0:
		return false

	var visited: Dictionary = {}
	var cursor: int = candidate_parent_id
	while cursor > 0:
		if cursor == deck_id:
			return true
		if visited.has(cursor):
			return true
		visited[cursor] = true

		var node_result := _deck_db.get_deck_by_id(cursor)
		if not node_result.get("success", false):
			return false
		var node: DeckEntity = node_result.get("data", null)
		if node == null:
			return false
		cursor = node.parent_id

	return false
