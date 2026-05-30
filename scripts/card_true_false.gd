class_name TrueFalseCard
extends CardData

func _init() -> void:
	card_type = CardType.TRUE_FALSE

## 该陈述是否正确
@export var is_true: bool = true

func build_answer() -> String:
	var result := "[color=#2FA139]✓ 正确[/color]" if is_true else "[color=#CD3838]✗ 错误[/color]"
	return "答案：" + result
