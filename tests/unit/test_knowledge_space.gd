extends GutTest
## 验证知识空间的限量查询、只读行为、档案解锁与可复用文档。

const SPACE_SCENE: PackedScene = preload("res://scenes/desktop/knowledge_space.tscn")
var _db_path: String
var _notes: NoteManager
var _decks: DeckManager
var _cards: CardManager


class SnapshotReader:
	extends NoteManager
	var available: bool = false

	## 模拟已经初始化的读取服务。## 输入: 无。输出: bool。
	func is_ready() -> bool:
		return true

	## 模拟临时读取失败及后续重试成功，不访问磁盘。## 输入: _limit。输出: 标准结果。
	func get_spatial_documents(_limit: int = 24) -> Dictionary:
		if not available:
			return {"success": false, "error": "读取暂时不可用"}
		return {"success": true, "data": [{"card_id": 8, "deck_id": 1, "deck_name": "恢复", "front": "重试后的正文", "back": "完整答案"}]}


## 每项数据测试使用独立数据库，不复用玩家的数据文件。## 输入: 无。输出: 无。
func before_each() -> void:
	_db_path = "user://knowledge_space_test_%d.db" % Time.get_ticks_usec()
	_notes = null
	_decks = null
	_cards = null


## 等待已移出场景树的旧文档完成延迟释放，再执行孤儿节点检查。## 输入: 无。输出: 无。
func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## 建立实际业务管理器与默认笔记类型，所有对象由 GUT 释放。## 输入: 无。输出: 无。
func _prepare_database() -> void:
	var note_types: NoteTypeManager = add_child_autofree(NoteTypeManager.new()) as NoteTypeManager
	assert_true(note_types.setup(_db_path))
	_decks = add_child_autofree(DeckManager.new()) as DeckManager
	assert_true(_decks.setup(_db_path))
	_notes = add_child_autofree(NoteManager.new()) as NoteManager
	assert_true(_notes.setup(_db_path))
	_cards = add_child_autofree(CardManager.new()) as CardManager
	assert_true(_cards.setup(_db_path))


## 通过正式接口创建一张测试卡，返回其实体。## 输入: deck_id、fields。输出: CardEntity。
func _create_card(deck_id: int, fields: Dictionary) -> CardEntity:
	var result: Dictionary = _notes.create_note("__default__", fields, deck_id)
	assert_true(result.get("success", false), str(result))
	return result.data.cards[0] as CardEntity


## 打开不读取数据库的独立视图，默认移除档案以隔离用例。## 输入: with_archives (bool)。输出: KnowledgeSpace。
func _open_space(with_archives: bool = false) -> KnowledgeSpace:
	var view: KnowledgeSpace = SPACE_SCENE.instantiate() as KnowledgeSpace
	view.auto_load_cards = false
	view.database_path = _db_path
	view.configuration = view.configuration.duplicate(true) as KnowledgeSpaceConfig
	if not with_archives:
		view.configuration.archives.clear()
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1100, 740)
	return add_child_autofree(view) as KnowledgeSpace


## 生成简短的可重复界面样本，不伪造任何学习操作。## 输入: count_value (int)。输出: 文档数组。
func _rows(count_value: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(count_value):
		result.append({"card_id": index + 1, "deck_id": 1, "deck_name": "测试牌组", "front": "问题 %d" % index, "back": "答案 %d" % index})
	return result


## 空数据库应返回成功的空数组，而不是伪造示例闪卡。## 输入: 无。输出: 无。
func test_empty_database_returns_empty_documents() -> void:
	_prepare_database()
	var result: Dictionary = _notes.get_spatial_documents()
	assert_true(result.success)
	assert_eq(result.data.size(), 0)
	var view: KnowledgeSpace = _open_space()
	view.refresh_content()
	assert_true(view.get_node("%EmptyMessage").visible)
	assert_eq(view._documents.size(), 0)


## 查询选择最新卡片，默认及显式数量上限均在数据库层生效。## 输入: 无。输出: 无。
func test_recent_selection_and_bounded_query() -> void:
	_prepare_database()
	var deck_id: int = int(_decks.create_deck("空间测试").data.id)
	var last_card: CardEntity
	for index: int in range(70):
		last_card = _create_card(deck_id, {"front": "问题 %d" % index, "back": "答案"})
	var recent: Dictionary = _notes.get_spatial_documents()
	assert_eq(recent.data.size(), 24)
	assert_eq(int(recent.data[0].card_id), last_card.id)
	assert_eq(str(recent.data[0].deck_name), "空间测试")
	assert_eq(_notes.get_spatial_documents(10000).data.size(), 64)
	assert_eq(_notes.get_spatial_documents(0).data.size(), 1)


## 空间和学习应使用同一套正反面字段回退规则。## 输入: 无。输出: 无。
func test_fields_match_existing_card_content() -> void:
	_prepare_database()
	var deck_id: int = int(_decks.create_deck("字段测试").data.id)
	var samples: Array[Dictionary] = [
		{"正面": "中文问题", "背面": "中文答案"},
		{"Question": "English?", "Answer": "Yes."},
		{"自定义": "第一字段", "另一字段": "第二字段"},
		{"front": "", "back": "只有答案"},
	]
	for fields: Dictionary in samples:
		var card: CardEntity = _create_card(deck_id, fields)
		var standard: Dictionary = _notes.get_content_for_card(card.id).data
		var spatial: Dictionary = _notes.get_spatial_documents(1).data[0]
		assert_eq(spatial.front, standard.front)
		assert_eq(spatial.back, standard.back)


## 空间查询和阅读不得产生复习写入、卡片展示或剧情进度变化。## 输入: 无。输出: 无。
func test_browsing_is_read_only() -> void:
	_prepare_database()
	var deck_id: int = int(_decks.create_deck("只读测试").data.id)
	var card: CardEntity = _create_card(deck_id, {"front": "[b]水[/b]的分子式？", "back": "H₂O"})
	var before_card: Dictionary = (_cards.get_card(card.id).data as CardEntity).to_dict()
	var before_story: Dictionary = App.get_story_progress().capture_state()
	watch_signals(App)
	var view: KnowledgeSpace = _open_space()
	view.refresh_content()
	view._select_document(view._documents["card:%d" % card.id])
	view.read_selected()
	assert_true(view.get_node("%Reader").visible)
	assert_true("水的分子式？" in view.get_node("%ReaderText").text)
	assert_eq((_cards.get_card(card.id).data as CardEntity).to_dict(), before_card)
	assert_eq(App.get_story_progress().capture_state(), before_story)
	assert_signal_not_emitted(App, "card_presented")
	assert_signal_not_emitted(App, "card_answered")
	assert_signal_not_emitted(App, "story_state_changed")


## 已删除笔记的卡片不应留下空间文档。## 输入: 无。输出: 无。
func test_deleted_note_disappears_on_refresh() -> void:
	_prepare_database()
	var deck_id: int = int(_decks.create_deck("删除测试").data.id)
	var card: CardEntity = _create_card(deck_id, {"front": "临时问题", "back": "临时答案"})
	assert_true(_notes.delete_note(card.note_id).success)
	assert_eq(_notes.get_spatial_documents().data.size(), 0)


## 短暂读取失败保留已有文档，刷新按钮仍可重试并恢复。## 输入: 无。输出: 无。
func test_failed_refresh_preserves_documents_and_can_retry() -> void:
	var view: KnowledgeSpace = _open_space()
	view.set_card_documents(_rows(3))
	var reader: SnapshotReader = SnapshotReader.new()
	view.add_child(reader)
	view._note_manager = reader
	view.refresh_content()
	assert_eq(view._card_count, 3)
	assert_true("读取失败" in str(view.get_node("%Status").text))
	assert_false(view.get_node("%RefreshButton").disabled)
	reader.available = true
	view.refresh_content()
	assert_eq(view._card_count, 1)
	assert_true(view._documents.has("card:8"))
	assert_eq(view._load_error, "")


## BBCode 仅移除排版，普通方括号及 HTML 换行仍保留可读含义。## 输入: 无。输出: 无。
func test_plain_text_does_not_execute_or_eat_literal_brackets() -> void:
	var text: String = KnowledgeSpaceText.plain_text("[b]标题[/b]<br>[color=red]中文[/color] [Na+] [img]https://example.invalid/image.png[/img]")
	assert_eq(text, "标题\n中文 [Na+] [图片]")
	assert_eq(KnowledgeSpaceText.excerpt("长".repeat(400)), "长".repeat(359) + "…")


## 空间只显示短摘录，阅读层保留超长中文与多段全文。## 输入: 无。输出: 无。
func test_long_document_keeps_full_text_in_reader() -> void:
	var view: KnowledgeSpace = _open_space()
	var rows: Array[Dictionary] = _rows(1)
	rows[0].front = "标题".repeat(500)
	rows[0].back = "长答案\n".repeat(1000)
	view.set_card_documents(rows)
	var document: KnowledgeSpaceDocument = view._documents["card:1"]
	assert_lte((document.get_node("Body") as Label3D).text.length(), 360)
	var preview: Label3D = document.get_node("Body") as Label3D
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.width = preview.width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(preview.text, preview.font, preview.font_size)
	assert_lte(paragraph.get_size().y * preview.pixel_size, view.configuration.page_size.y - 3.3)
	view._select_document(document)
	view.read_selected()
	assert_eq(str(view.get_node("%ReaderText").text), document.body)
	assert_lte(str(view.get_node("%ReaderTitle").text).length(), 60)


## 同牌组和档案页面均保持平行，刷新保留视角及稳定位置。## 输入: 无。输出: 无。
func test_layout_is_parallel_and_refresh_keeps_camera() -> void:
	var view: KnowledgeSpace = _open_space()
	view.set_card_documents(_rows(8))
	var before_position: Vector3 = view._documents["card:3"].position
	view.get_node("%SpaceCamera").position = Vector3(4, 5, 6)
	view.set_card_documents(_rows(8))
	assert_eq(view._documents["card:3"].position, before_position)
	assert_eq(view.get_node("%SpaceCamera").position, Vector3(4, 5, 6))
	for document: KnowledgeSpaceDocument in view._documents.values():
		assert_eq(document.rotation, Vector3.ZERO)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 1)
	assert_not_null((view.get_node("%SpaceViewport") as SubViewport).world_3d)


## 完整章节记录防止第二章同名剧情被第一章完成记录提前解锁。## 输入: 无。输出: 无。
func test_archive_unlock_uses_full_record() -> void:
	var archive: KnowledgeSpaceArchive = KnowledgeSpaceArchive.new()
	archive.required_story_record = "chapter_2/revelation"
	var progress: StoryProgress = StoryProgress.new()
	progress.mark_chapter_dialogue("chapter_1", "revelation")
	assert_false(archive.is_unlocked(progress))
	assert_false(archive.is_unlocked(null))
	progress.mark_chapter_dialogue("chapter_2", "revelation")
	assert_true(archive.is_unlocked(progress))


## 档案解锁不重排普通文档，重置后关闭正在阅读的隐藏档案。## 输入: 无。输出: 无。
func test_unlock_and_reset_preserve_other_documents() -> void:
	var view: KnowledgeSpace = _open_space(true)
	view.set_card_documents(_rows(3))
	var card_position: Vector3 = view._documents["card:1"].position
	var progress: StoryProgress = StoryProgress.new()
	view.sync_archives(progress)
	assert_eq(view._archive_count, 0)
	progress.mark_chapter_dialogue("chapter_1", "intro")
	view.sync_archives(progress)
	assert_eq(view._archive_count, 1)
	assert_eq(view._documents["card:1"].position, card_position)
	var document: KnowledgeSpaceDocument = view._documents["archive:first_contact"]
	assert_true(document.is_archive)
	view._select_document(document)
	view.read_selected()
	progress.completed_dialogues.clear()
	view.sync_archives(progress)
	assert_eq(view._archive_count, 0)
	assert_false(view.get_node("%Reader").visible)
	assert_false(view._documents.has("archive:first_contact"))
	assert_eq(view._documents["card:1"].position, card_position)


## 正式进度信号应在窗口内立即显示或隐藏档案，不等待重新打开。## 输入: 无。输出: 无。
func test_story_state_signal_refreshes_archive_visibility() -> void:
	var view: KnowledgeSpace = _open_space(true)
	var progress: StoryProgress = App.get_story_progress()
	var completed: Array[String] = progress.completed_dialogues.duplicate()
	progress.completed_dialogues.clear()
	App.story_state_changed.emit()
	assert_eq(view._archive_count, 0)
	progress.mark_chapter_dialogue("chapter_1", "intro")
	App.story_state_changed.emit()
	assert_true(view._documents.has("archive:first_contact"))
	progress.completed_dialogues = completed
	App.story_state_changed.emit()


## 从背面也可以选中文档，矩形外或远离页面的射线不命中。## 输入: 无。输出: 无。
func test_page_ray_intersection_matches_actual_rect() -> void:
	var view: KnowledgeSpace = _open_space()
	view.set_card_documents(_rows(1))
	var document: KnowledgeSpaceDocument = view._documents["card:1"]
	var center: Vector3 = document.global_position
	assert_gt(document.ray_distance(center + Vector3(0, 0, 10), Vector3.FORWARD), 0.0)
	assert_gt(document.ray_distance(center - Vector3(0, 0, 10), Vector3.BACK), 0.0)
	assert_eq(document.ray_distance(center + Vector3(20, 0, 10), Vector3.FORWARD), -1.0)
	assert_eq(document.ray_distance(center + Vector3(0, 0, 10), Vector3.BACK), -1.0)


## 不同页面的选择与材质不能互相污染。## 输入: 无。输出: 无。
func test_document_materials_are_independent() -> void:
	var view: KnowledgeSpace = _open_space()
	view.set_card_documents(_rows(2))
	var first: KnowledgeSpaceDocument = view._documents["card:1"]
	var second: KnowledgeSpaceDocument = view._documents["card:2"]
	var before_tint: Color = (second.get_node("Frame").material_override as StandardMaterial3D).albedo_color
	first.set_selected(true)
	assert_eq((second.get_node("Frame").material_override as StandardMaterial3D).albedo_color, before_tint)
	assert_ne(first.get_node("Frame").material_override, second.get_node("Frame").material_override)


## 场景默认资源含六篇档案且桌面入口可见，限额与窗口尺寸符合约定。## 输入: 无。输出: 无。
func test_default_configuration_and_registry() -> void:
	var view: KnowledgeSpace = _open_space(true)
	assert_eq(view.configuration.card_limit, 24)
	assert_eq(view.configuration.archives.size(), 6)
	assert_eq(view.configuration.resource_path, "")
	assert_eq(WindowManager.REGISTRY.knowledge_space.default_size, Vector2(1100, 740))
	assert_eq(WindowManager.REGISTRY.knowledge_space.min_size, Vector2(720, 480))
	assert_true(WindowManager.REGISTRY.knowledge_space.entry_visible)
