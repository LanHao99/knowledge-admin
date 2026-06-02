# 任务 01：UI 层重构 - 对接 Manager 层

## 背景
`debug_crud_panel.gd` 当前直接调用 `DeckDB`，违反分层架构原则。需要重构为通过 `DeckManager` 和 `NoteManager` 调用。

## 目标文件
- **主要修改**: `scenes/ui/debug_crud_panel.gd`
- **依赖**: `scenes/business_logic/deck_manager.gd`, `scenes/business_logic/note_manager.gd`

## 具体任务

### 1. 替换数据层依赖
```gdscript
# Before:
var _deck_db: DeckDB = null

# After:
var _deck_manager: DeckManager = null
var _note_manager: NoteManager = null
```

### 2. 修改初始化逻辑
在 `_ensure_database_ready()` 中：
- 创建 `DeckManager` 和 `NoteManager` 实例
- 注入 DB 依赖 (`set_deck_db()`, `set_note_db()`, `set_card_db()`)
- 替换所有 `_deck_db.xxx` 调用为 `_deck_manager.xxx`

### 3. 替换所有 CRUD 操作调用
**Deck 操作**：
- `_deck_db.create_deck()` → `_deck_manager.create_deck()`
- `_deck_db.get_deck_by_id()` → `_deck_manager.get_deck()`
- `_deck_db.update_deck()` → `_deck_manager.rename_deck()` 或直接更新
- `_deck_db.delete_deck()` → `_deck_manager.delete_deck()`
- `_deck_db.get_all_decks()` → `_deck_manager.get_all_decks()`

**Note 操作**：
- 所有 Note 相关操作需要通过 `_note_manager`

### 4. 封装复杂事务到 Manager
将 `_on_clear_data_confirmed()` 中的清空数据库逻辑封装到 `DeckManager` 的新方法：
```gdscript
# 在 DeckManager 中新增:
func clear_all_data() -> Dictionary:
    # 事务包装：DELETE cards, notes, decks
    # 返回删除统计
```

### 5. 保留的 UI 职责
✅ 表单输入收集  
✅ 列表显示  
✅ 日志输出  
✅ `_stringify_deck()` 等格式化辅助方法  

❌ 不再直接操作数据库  
❌ 不再管理事务  

## 验证标准
1. 运行调试控制台，所有 CRUD 操作正常
2. 清空数据库功能正常
3. 无直接调用 `_deck_db` 的代码残留
4. Console 无错误输出

## 注意事项
- Manager 层的方法返回格式与 DB 层一致（标准 Dictionary）
- 保持现有 UI 交互逻辑不变
- 可能需要处理 Manager 层的额外校验错误（如名称重复）
