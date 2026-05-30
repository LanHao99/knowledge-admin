## 闪卡数据基类
## 继承自 Resource，可在 Godot 编辑器中直接创建和编辑

class_name CardData
extends Resource

## 卡片类型枚举
enum CardType { TRUE_FALSE, CHOICE, SHORT_ANSWER }

## 题型标识
@export var card_type: CardType = CardType.SHORT_ANSWER
## 问题/题干
@export var question: String = ""
## 可选解析说明
@export var explanation: String = ""
## 科目/章节标签
@export var category: String = ""

## 获取题型中文名
func get_type_label() -> String:
	match card_type:
		CardType.TRUE_FALSE:
			return "判断题"
		CardType.CHOICE:
			return "选择题"
		CardType.SHORT_ANSWER:
			return "问答题"
		_:
			return "未知"

## 构建正面显示文本（子类可重写）
func build_front() -> String:
	return question

## 构建背面答案文本（子类必须重写）
func build_answer() -> String:
	return ""
