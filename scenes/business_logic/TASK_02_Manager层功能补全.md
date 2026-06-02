# 任务 02：Manager 层功能补全

## 背景
当前 Manager 层已实现基础 CRUD，但缺少调试控制台需要的高级功能。需要补全以支持 UI 层完整对接。

## 目标文件
- `scenes/business_logic/deck_manager.gd`
- `scenes/business_logic/note_manager.gd`
- `scenes/business_logic/card_manager.gd`

## 具体任务

### 1. DeckManager 补全

#### 1.1 新增 `clear_all_data()` 方法
```gdscript
## 清空全部数据（cards, notes, decks）。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为删除统计 Dictionary。
func clear_all_data() -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")
	
	return run_in_databases_transaction([_deck_db], func() -> Dictionary:
		var stats := {
			"cards": 0,
			"notes": 0,
			"decks": 0
		}
		
		var tables := ["cards", "notes", "decks"]
		for table in tables:
			var del_result := _deck_db.execute_bind("DELETE FROM %s;" % table, [])
			if not del_result.get("success", false):
				return del_result
			
			var changes_result := _deck_db.changes()
			if changes_result.get("success", false):
				stats[table] = int(changes_result.get("data", 0))
		
		batch_operation_completed.emit("all_data", stats["cards"] + stats["notes"] + stats["decks"])
		return ok(stats)
	)
```

#### 1.2 确认现有方法完整性
检查以下方法是否已实现并符合 `逻辑层.md` 规范：
- ✅ `create_deck()`
- ✅ `rename_deck()`
- ✅ `move_deck()`
- ✅ `archive_deck()`
- ✅ `delete_deck()`
- ✅ `get_deck()`
- ✅ `get_all_decks()`
- ✅ `get_deck_tree()`
- ✅ `get_deck_counts()`

### 2. NoteManager 补全

#### 2.1 确认现有方法完整性
检查以下方法是否已实现：
- ✅ `create_note()`
- ✅ `update_note()`
- ✅ `delete_note()`
- ✅ `get_note()`
- ✅ `get_notes_by_deck()`
- ✅ `search_notes()` (如未实现，标记为 TODO)

#### 2.2 新增 `get_all_notes()` 方法（调试控制台需要）
```gdscript
## 获取全部笔记列表。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func get_all_notes() -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	return _note_db.get_all_notes()
```

### 3. CardManager 确认
检查 CardManager 是否已实现以下核心方法：
- ✅ `get_card()`
- ✅ `get_cards_by_note()`
- ✅ `get_cards_by_deck()`
- ✅ `answer_card()`
- ✅ `get_study_queue()`

### 4. 跨 Manager 依赖注入确认
确认各 Manager 的依赖注入方法完整：
- `DeckManager.set_deck_db(DeckDB)`
- `NoteManager.set_note_db(NoteDB)`
- `NoteManager.set_card_db(CardDB)`
- `NoteManager.set_deck_db(DeckDB)` (可选)
- `CardManager.set_card_db(CardDB)`
- `CardManager.set_note_db(NoteDB)`
- `CardManager.set_scheduler(Scheduler)`

## 验证标准
1. 所有 Manager 方法返回标准 `{success, data, error, code}` 字典
2. 事务包装正确（使用 `run_in_databases_transaction`）
3. 信号正确发出（`entity_created`, `entity_updated`, `entity_deleted`, `batch_operation_completed`）
4. 所有方法有完整的 GDScript 注释（`##` 格式）

## 注意事项
- 保持与 `逻辑层.md` 规范一致
- Manager 层不直接操作 SQLite，只调用 DB 层方法
- 校验逻辑放在 Manager 层，DB 层只负责数据持久化
