class_name DeckManager
extends Node

## 卡组数据：所有卡片
var _all_cards: Array[CardData] = []
## 当前会话的卡片（顺序或随机）
var _session_cards: Array[CardData] = []
## "不会"的卡片（会被重新加入队列）
var _unknown_cards: Array[CardData] = []

## 统计
var _known_count: int = 0
var _unknown_count: int = 0

## 从 JSON 文件加载卡组
func load_from_json(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DeckManager: 无法打开文件 " + path)
		return FileAccess.get_open_error()

	var json := JSON.new()
	var parse_err := json.parse(file.get_as_text())
	if parse_err != OK:
		push_error("DeckManager: JSON 解析失败: " + json.get_error_message())
		return ERR_PARSE_ERROR

	var data := json.data as Dictionary
	var cards := data.get("cards", []) as Array
	_all_cards.clear()

	for entry in cards:
		var card := _parse_card(entry as Dictionary)
		if card != null:
			_all_cards.append(card)

	return OK

func _parse_card(entry: Dictionary) -> CardData:
	var type_str: String = entry.get("type", "")
	match type_str:
		"true_false":
			var c := TrueFalseCard.new()
			c.question = entry.get("question", "")
			c.is_true = entry.get("is_true", true)
			c.category = entry.get("category", "")
			c.explanation = entry.get("explanation", "")
			return c
		"choice":
			var c := ChoiceCard.new()
			c.question = entry.get("question", "")
			var opts := entry.get("options", []) as Array
			c.options.assign(opts)
			c.correct_index = entry.get("correct_index", 0)
			c.category = entry.get("category", "")
			c.explanation = entry.get("explanation", "")
			return c
		"short_answer":
			var c := ShortAnswerCard.new()
			c.question = entry.get("question", "")
			c.answer = entry.get("answer", "")
			c.category = entry.get("category", "")
			c.explanation = entry.get("explanation", "")
			return c
		_:
			push_warning("DeckManager: 未知卡片类型: " + type_str)
			return null

## 开始新会话：洗牌或不洗牌
func start_session(shuffle: bool = true) -> void:
	_session_cards = _all_cards.duplicate()
	if shuffle:
		_session_cards.shuffle()
	_known_count = 0
	_unknown_count = 0
	_unknown_cards.clear()

## 获取当前卡片
func get_card(index: int) -> CardData:
	if index < 0 or index >= _session_cards.size():
		return null
	return _session_cards[index]

## 标记为"会了"
func mark_known(index: int) -> void:
	if index >= 0 and index < _session_cards.size():
		_known_count += 1

## 标记为"不会"：将该卡加入重学队列
func mark_unknown(index: int) -> void:
	if index >= 0 and index < _session_cards.size():
		_unknown_count += 1
		_unknown_cards.append(_session_cards[index])

## 获取总卡片数
func total_cards() -> int:
	return _session_cards.size()

## 获取"不会"卡片数（待重学）
func get_unknown_count() -> int:
	return _unknown_count

## 获取"会了"卡片数
func get_known_count() -> int:
	return _known_count

## 获取"不会"的卡片列表（用于重学）
func get_unknown_cards() -> Array[CardData]:
	return _unknown_cards.duplicate()
