class_name ShortAnswerCard
extends CardData

func _init() -> void:
	card_type = CardType.SHORT_ANSWER

## 参考答案
@export var answer: String = ""

func build_answer() -> String:
	return "[color=#534AB7]参考答案：[/color]\n" + answer
