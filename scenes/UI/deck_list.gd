extends Control
## 牌组管理界面，用 Tree 控件展示牌组树形结构（支持 parent_id 嵌套）。
## 双击牌组展开编辑面板，支持重命名/移动/归档/删除。
## 新建牌组通过 ConfirmationDialog 弹出。
## 监听 DeckManager 信号自动刷新。


# ── 数据层 ──
var _deck_manager: DeckManager = null
var _notetype_manager: NoteTypeManager = null
var _import_manager: ImportManager = null
var _note_manager: NoteManager = null
var _deck_db: DeckDB = null

# ── 顶部栏 ──
@onready var _back_btn: Button = $RootMargin/MainVBox/TopBar/BackBtn
@onready var _title_label: Label = $RootMargin/MainVBox/TopBar/TitleLabel
@onready var _new_deck_btn: Button = $RootMargin/MainVBox/TopBar/NewDeckBtn

# ── 牌组树 ──
@onready var _deck_tree: Tree = $RootMargin/MainVBox/DeckTree

# ── 编辑面板 ──
@onready var _edit_panel: PanelContainer = $RootMargin/MainVBox/EditPanel
@onready var _edit_title: Label = $RootMargin/MainVBox/EditPanel/EditVBox/EditHeader/EditTitle
@onready var _close_edit_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/EditHeader/CloseEditBtn
@onready var _name_input: LineEdit = $RootMargin/MainVBox/EditPanel/EditVBox/NameInput
@onready var _parent_select: OptionButton = $RootMargin/MainVBox/EditPanel/EditVBox/ParentSelect
@onready var _card_stats: Label = $RootMargin/MainVBox/EditPanel/EditVBox/MetaInfo/CardStats
@onready var _created_label: Label = $RootMargin/MainVBox/EditPanel/EditVBox/MetaInfo/CreatedLabel
@onready var _archive_check: CheckButton = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/ArchiveCheck
@onready var _save_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/SaveBtn
@onready var _delete_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/DeleteBtn
@onready var _import_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/ImportBtn
@onready var _ai_card_btn: Button = $RootMargin/MainVBox/EditPanel/EditVBox/ActionBar/AICardBtn

# ── 新建对话框 ──
@onready var _new_dialog: ConfirmationDialog = $NewDeckDialog
@onready var _new_name_input: LineEdit = $NewDeckDialog/DialogVBox/NameInput
@onready var _new_parent_select: OptionButton = $NewDeckDialog/DialogVBox/ParentSelect

# ── 底部状态栏 ──
@onready var _status_label: Label = $RootMargin/MainVBox/StatusBar/StatusLabel

# 面板编辑中的牌组 ID
var _editing_deck_id: int = 0


## 初始化 Manager、绑定信号、刷新列表。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_edit_panel.visible = false
	_bind_actions()
	var init_ok := _ensure_manager_ready()
	if init_ok:
		_refresh_all()
	else:
		_set_status("数据库初始化失败")

	TutorialManager.check_and_show("deck_list", self)


## 退出时断开信号、释放 Manager。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if _deck_manager != null:
		_deck_manager.entity_created.disconnect(_on_deck_created)
		_deck_manager.entity_updated.disconnect(_on_deck_updated)
		_deck_manager.entity_deleted.disconnect(_on_deck_deleted)
		_deck_manager.queue_free()
		_deck_manager = null


## 绑定按钮事件与 Tree 双击信号。## 输入: 无。
## 输出: 无。
func _bind_actions() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_new_deck_btn.pressed.connect(_on_new_deck_pressed)
	_deck_tree.item_activated.connect(_on_item_activated)
	_close_edit_btn.pressed.connect(_on_close_edit_pressed)
	_save_btn.pressed.connect(_on_save_pressed)
	_delete_btn.pressed.connect(_on_delete_pressed)
	_import_btn.pressed.connect(_on_import_pressed)
	_ai_card_btn.pressed.connect(_on_ai_card_pressed)
	_new_dialog.confirmed.connect(_on_new_dialog_confirmed)


# ──────────────────────────────────────────────────────────────
# Manager 初始化
# ──────────────────────────────────────────────────────────────


## 创建并初始化 DeckManager。## 输入: 无。
## 输出: bool - 初始化成功返回 true。
func _ensure_manager_ready() -> bool:
	if _deck_manager != null and _deck_manager.is_ready():
		return true

	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null

	const db_path: String = "user://knowledge_admin.db"
	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	if not _deck_manager.setup(db_path):
		push_error("[DeckList] DeckManager 初始化失败")
		return false
	_deck_manager.entity_created.connect(_on_deck_created)
	_deck_manager.entity_updated.connect(_on_deck_updated)
	_deck_manager.entity_deleted.connect(_on_deck_deleted)

	_notetype_manager = NoteTypeManager.new()
	add_child(_notetype_manager)
	if not _notetype_manager.setup(db_path):
		push_error("[DeckList] NoteTypeManager 初始化失败")
		return false

	_note_manager = NoteManager.new()
	add_child(_note_manager)
	if not _note_manager.setup(db_path):
		push_error("[DeckList] NoteManager 初始化失败")
		return false

	_deck_db = _deck_manager.get_deck_db()
	_import_manager = ImportManager.new()
	add_child(_import_manager)
	_import_manager.setup(_note_manager, _notetype_manager, _deck_db)

	return true


# ──────────────────────────────────────────────────────────────
# 列表刷新
# ──────────────────────────────────────────────────────────────


## entity_created 回调，触发全量刷新。## 输入: 信号参数，未使用。
## 输出: 无。
func _on_deck_created(_entity_type: String, _entity_id: int) -> void:
	_refresh_all()


## entity_updated 回调，触发全量刷新。## 输入: 信号参数，未使用。
## 输出: 无。
func _on_deck_updated(_entity_type: String, _entity_id: int) -> void:
	_refresh_all()


## entity_deleted 回调，触发全量刷新。## 输入: 信号参数，未使用。
## 输出: 无。
func _on_deck_deleted(_entity_type: String, _entity_id: int) -> void:
	_refresh_all()


## 全量刷新树和状态栏计数。## 输入: 无。
## 输出: 无。
func _refresh_all() -> void:
	_rebuild_tree()
	_update_status_count()


## 从 DeckDB.get_deck_tree() 获取树形结构并填充 Tree 控件。## 输入: 无。
## 输出: 无。
func _rebuild_tree() -> void:
	_deck_tree.clear()
	_deck_tree.columns = 4
	_deck_tree.set_column_title(0, "📚 牌组")
	_deck_tree.set_column_title(1, "📝 新")
	_deck_tree.set_column_title(2, "🔄 复习")
	_deck_tree.set_column_title(3, "总计")
	_deck_tree.set_column_expand(0, true)
	_deck_tree.set_column_expand(1, false)
	_deck_tree.set_column_expand(2, false)
	_deck_tree.set_column_expand(3, false)
	_deck_tree.set_column_custom_minimum_width(1, 60)
	_deck_tree.set_column_custom_minimum_width(2, 60)
	_deck_tree.set_column_custom_minimum_width(3, 60)
	_deck_tree.hide_root = true

	if _deck_manager == null:
		return

	var deck_db: DeckDB = _deck_manager.get_deck_db()
	if deck_db == null:
		return

	var tree_result := deck_db.get_deck_tree()
	if not tree_result.get("success", false):
		return

	var roots: Array = tree_result.get("data", [])
	var root_item: TreeItem = _deck_tree.create_item()

	for node in roots:
		_add_deck_tree_node(root_item, node)


## 递归向 Tree 中添加牌组节点及其子节点，附带卡片统计。## 输入:
##   parent_item (TreeItem) - 父 Tree 节点。
##   node (Dictionary) - {deck: DeckEntity, children: Array}。
## 输出: 无。
func _add_deck_tree_node(parent_item: TreeItem, node: Dictionary) -> void:
	var deck: DeckEntity = node.get("deck", null)
	if deck == null:
		return

	var is_archived: bool = deck.is_archived
	var prefix: String = "📁 " if is_archived else "📂 "
	var deck_name: String = prefix + deck.name
	if is_archived:
		deck_name = "[color=#777]" + deck_name + " (归档)[/color]"

	var item: TreeItem = _deck_tree.create_item(parent_item)
	item.set_text(0, deck_name)
	item.set_metadata(0, deck.id)

	# 获取卡片统计
	var deck_db: DeckDB = _deck_manager.get_deck_db()
	if deck_db != null:
		var stats_result := deck_db.get_deck_card_counts(deck.id)
		if stats_result.get("success", false):
			var stats: Dictionary = stats_result.get("data", {})
			item.set_text(1, str(stats.get("new", 0)))
			item.set_text(2, str(stats.get("review", 0)))
			item.set_text(3, str(stats.get("total", 0)))

	item.set_meta("_is_archived", is_archived)

	# 递归子节点
	var children: Array = node.get("children", [])
	for child in children:
		_add_deck_tree_node(item, child)


## 更新底部状态栏的牌组计数。## 输入: 无。
## 输出: 无。
func _update_status_count() -> void:
	if _deck_manager == null:
		return
	var deck_db := _deck_manager.get_deck_db()
	if deck_db == null:
		return
	var result := deck_db.get_all_decks(true)
	if result.get("success", false):
		var decks: Array = result.get("data", [])
		var active_count := 0
		for deck in decks:
			if deck is DeckEntity and not deck.is_archived:
				active_count += 1
		_set_status("共 %d 个牌组（%d 活跃）" % [decks.size(), active_count])


# ──────────────────────────────────────────────────────────────
# 编辑面板
# ──────────────────────────────────────────────────────────────


## Tree 双击事件：加载对应牌组并展开编辑面板。## 输入: 无。
## 输出: 无。
func _on_item_activated() -> void:
	var selected: TreeItem = _deck_tree.get_selected()
	if selected == null:
		return
	var meta: Variant = selected.get_metadata(0)
	if typeof(meta) != TYPE_INT:
		return
	var deck_id: int = int(meta)
	if deck_id <= 0 or _deck_manager == null:
		return

	var result := _deck_manager.get_deck(deck_id)
	if not result.get("success", false):
		return
	var deck: DeckEntity = result.get("data", null)
	if deck == null:
		return

	_show_editor(deck)


## 展开编辑面板并填充牌组数据。## 输入: deck (DeckEntity)。
## 输出: 无。
func _show_editor(deck: DeckEntity) -> void:
	_editing_deck_id = deck.id
	_edit_title.text = "编辑牌组 #%d" % deck.id
	_name_input.text = deck.name
	_archive_check.button_pressed = deck.is_archived
	_created_label.text = "创建: %s" % _format_timestamp(deck.created_at)

	# 填充父牌组下拉
	_refill_parent_select(_parent_select, deck.parent_id, deck.id)

	# 填充卡片统计
	_refresh_card_stats(deck.id)

	_edit_panel.visible = true


## 关闭编辑面板。## 输入: 无。
## 输出: 无。
func _on_close_edit_pressed() -> void:
	_edit_panel.visible = false
	_editing_deck_id = 0


## 保存编辑面板中的牌组变更（重命名 + 移动 + 归档）。## 输入: 无。
## 输出: 无。
func _on_save_pressed() -> void:
	if _editing_deck_id <= 0 or _deck_manager == null:
		return

	var new_name: String = _name_input.text.strip_edges()
	var new_parent_id: int = _parent_select.get_selected_id()
	var do_archive: bool = _archive_check.button_pressed

	# 获取当前牌组信息以判断变更
	var current_result := _deck_manager.get_deck(_editing_deck_id)
	if not current_result.get("success", false):
		_set_status("获取牌组信息失败")
		return
	var current: DeckEntity = current_result.get("data", null)
	if current == null:
		return

	# 重命名
	if new_name != "" and new_name != current.name:
		var rename_result := _deck_manager.rename_deck(_editing_deck_id, new_name)
		if not rename_result.get("success", false):
			_set_status("重命名失败: %s" % rename_result.get("code", "unknown"))
			return

	# 移动
	if new_parent_id >= 0 and new_parent_id != current.parent_id:
		var move_result := _deck_manager.move_deck(_editing_deck_id, new_parent_id)
		if not move_result.get("success", false):
			_set_status("移动失败: %s" % move_result.get("code", "unknown"))
			return

	# 归档/恢复
	if do_archive != current.is_archived:
		var archive_result := _deck_manager.archive_deck(_editing_deck_id, do_archive)
		if not archive_result.get("success", false):
			_set_status("归档操作失败: %s" % archive_result.get("code", "unknown"))
			return

	_set_status("牌组已保存 ✓")
	_edit_panel.visible = false
	_editing_deck_id = 0


## 删除当前编辑中的牌组。## 输入: 无。
## 输出: 无。
func _on_delete_pressed() -> void:
	if _editing_deck_id <= 0 or _deck_manager == null:
		return

	var result := _deck_manager.delete_deck(_editing_deck_id)
	if result.get("success", false):
		_set_status("牌组已删除 ✓")
		_edit_panel.visible = false
		_editing_deck_id = 0
	else:
		_set_status("删除失败: %s" % result.get("code", "unknown"))


## 刷新编辑面板中的卡片统计标签。## 输入: deck_id (int)。
## 输出: 无。
func _refresh_card_stats(deck_id: int) -> void:
	if _deck_manager == null:
		return
	var deck_db := _deck_manager.get_deck_db()
	if deck_db == null:
		return
	var stats_result := deck_db.get_deck_card_counts(deck_id)
	if stats_result.get("success", false):
		var stats: Dictionary = stats_result.get("data", {})
		_card_stats.text = "卡片: 新 %d | 学习中 %d | 复习 %d | 总计 %d" % [
			stats.get("new", 0),
			stats.get("learning", 0),
			stats.get("review", 0),
			stats.get("total", 0)
		]


# ──────────────────────────────────────────────────────────────
# 新建牌组
# ──────────────────────────────────────────────────────────────


## 打开新建牌组对话框，填充父牌组下拉。## 输入: 无。
## 输出: 无。
func _on_new_deck_pressed() -> void:
	_new_name_input.text = ""
	_refill_parent_select(_new_parent_select, 0, -1)
	_new_dialog.popup_centered()


## 确认新建牌组。## 输入: 无。
## 输出: 无。
func _on_new_dialog_confirmed() -> void:
	if _deck_manager == null:
		return
	var name: String = _new_name_input.text.strip_edges()
	if name == "":
		_set_status("牌组名称不能为空")
		return

	var parent_id: int = _new_parent_select.get_selected_id()
	var result := _deck_manager.create_deck(name, parent_id)
	if result.get("success", false):
		_set_status("牌组 '%s' 已创建 ✓" % name)
	else:
		_set_status("创建失败: %s" % result.get("code", "unknown"))


# ──────────────────────────────────────────────────────────────
# 辅助方法
# ──────────────────────────────────────────────────────────────


## 填充牌组父级下拉列表（排除自身以避免循环引用）。## 输入:
##   option (OptionButton) - 目标下拉控件。
##   current_parent_id (int) - 当前选中的父 ID。
##   exclude_id (int) - 需要排除的牌组 ID（-1 表示不排除）。
## 输出: 无。
func _refill_parent_select(option: OptionButton, current_parent_id: int, exclude_id: int) -> void:
	option.clear()
	option.add_item("(根级 - 无父牌组)", 0)

	if _deck_manager == null:
		return
	var deck_db := _deck_manager.get_deck_db()
	if deck_db == null:
		return

	var all_result := deck_db.get_all_decks(true)
	if not all_result.get("success", false):
		return

	var selected_idx := 0
	var idx := 1
	for deck in all_result.get("data", []):
		if not (deck is DeckEntity):
			continue
		if exclude_id > 0 and deck.id == exclude_id:
			continue
		option.add_item(deck.name, deck.id)
		if deck.id == current_parent_id:
			selected_idx = idx
		idx += 1

	option.select(selected_idx)


## 格式化 Unix 时间戳为可读日期字符串。## 输入: ts (int)。
## 输出: String - "yyyy-mm-dd"。
func _format_timestamp(ts: int) -> String:
	if ts <= 0:
		return "—"
	var dt := Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


# ──────────────────────────────────────────────────────────────
# 导航
# ──────────────────────────────────────────────────────────────


## 返回主菜单。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	_switch_scene("res://scenes/ui/main_menu.tscn", "主菜单")


## 安全切换场景。## 输入: path (String) - 场景路径；label (String) - 场景名称。
## 输出: 无。
func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status("[color=#FF6666]场景不存在: %s[/color]" % label)
		return
	get_tree().change_scene_to_file(path)


# ──────────────────────────────────────────────────────────────
# 导入 JSON
# ──────────────────────────────────────────────────────────────


## "导入 JSON"按钮——打开导入向导并预填当前编辑中的牌组。## 输入: 无。
## 输出: 无。
func _on_import_pressed() -> void:
	if _editing_deck_id <= 0:
		_set_status("[color=#FF6666]请先双击牌组打开编辑面板[/color]")
		return
	if _import_manager == null or _notetype_manager == null or _note_manager == null or _deck_db == null:
		_set_status("[color=#FF6666]管理器未初始化[/color]")
		return

	var scene := load("res://scenes/import_main.tscn") as PackedScene
	if scene == null:
		_set_status("[color=#FF6666]导入模块加载失败[/color]")
		return
	var wizard: ImportMain = scene.instantiate()
	if wizard == null:
		_set_status("[color=#FF6666]导入模块实例化失败[/color]")
		return
	add_child(wizard)
	wizard.setup(_notetype_manager, _import_manager, _note_manager, _deck_db)
	wizard.select_deck_by_id(_editing_deck_id)


func _on_ai_card_pressed() -> void:
	if not ResourceLoader.exists("res://game/AI/ai_debug.tscn"):
		_set_status("[color=#FF6666]AI 模块不存在[/color]")
		return
	get_tree().change_scene_to_file("res://game/AI/ai_debug.tscn")


## 设置底部状态栏文本（支持 BBCode）。## 输入: text (String)。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
