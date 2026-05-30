class_name ChoiceCard
extends CardData

func _init() -> void:
	card_type = CardType.CHOICE

## 选项列表（A/B/C/D...）
@export var options: Array[String] = []
## 正确答案索引（从0开始，0=A, 1=B...）
@export var correct_index: int = 0

func build_front() -> String:
	var lines := PackedStringArray()
	lines.append(question)
	lines.append("")
	for i in range(options.size()):
		var letter := char(65 + i)
		lines.append(letter + ". " + options[i])
	return "\n".join(lines)

func build_answer() -> String:
	var letter := char(65 + correct_index)
	var lines := PackedStringArray()
	lines.append("[color=#534AB7]答案：" + letter + "[/color]")
	lines.append("")
	for i in range(options.size()):
		var marker := "→ " if i == correct_index else "  "
		lines.append(marker + char(65 + i) + ". " + options[i])
	return "\n".join(lines)
