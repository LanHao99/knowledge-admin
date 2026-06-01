extends Control

var db: SQLite = null

@onready var insert_button: Button = $Insert
@onready var delete_button: Button = $Delete
@onready var update_button: Button = $Update
@onready var select_button: Button = $Select
@onready var look_up_button: Button = $LookUp
@onready var name_input: TextEdit = $NameInput
@onready var score_input: TextEdit = $ScoreInput

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#创建数据库
	db = SQLite.new()
	db.path = "res://my_database.db"
	db.open_db()

	#在数据库中创建一个表
	var table = {
		"id": {"data_type": "int", "primary_key": true, "not_null": true, "auto_increment": true},
		"name": {"data_type": "text"},
		"score": {"data_type": "int"}
	}
	db.create_table("players", table)

	insert_button.pressed.connect(_on_insert_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	update_button.pressed.connect(_on_update_pressed)
	select_button.pressed.connect(_on_select_pressed)
	look_up_button.pressed.connect(_on_look_up_pressed)
	pass # Replace with function body.

func _on_insert_pressed() -> void: ## 插入数据
	var local_name = name_input.text
	var local_score = int(score_input.text)
	
	var data = {
		"name": local_name,
		"score": local_score
	}
	db.insert_row("players", data)
	print("Inserted: ", data)

	pass

func _on_delete_pressed() -> void:
	var local_name := name_input.text.strip_edges()
	if local_name == "":
		print("Delete failed: name is empty")
		return

	var success := db.query_with_bindings("DELETE FROM players WHERE name = ?;", [local_name])
	if success:
		print("Deleted rows by name: ", local_name)
	else:
		print("Delete failed: ", db.error_message)

func _on_update_pressed() -> void:
	var local_name := name_input.text.strip_edges()
	if local_name == "":
		print("Update failed: name is empty")
		return

	if score_input.text.strip_edges() == "":
		print("Update failed: score is empty")
		return

	var local_score := int(score_input.text)
	var success := db.query_with_bindings("UPDATE players SET score = ? WHERE name = ?;", [local_score, local_name])
	if success:
		print("Updated score: ", local_name, " -> ", local_score)
	else:
		print("Update failed: ", db.error_message)

func _on_select_pressed() -> void:
	var local_name := name_input.text.strip_edges()

	if local_name != "":
		var success := db.query_with_bindings("SELECT name, score FROM players WHERE name = ?;", [local_name])
		if success:
			print(db.query_result)
		else:
			print("Select failed: ", db.error_message)
	else:
		print("Select failed: name is empty")

	pass

func _on_look_up_pressed() -> void:
	var success := db.query("SELECT id, name, score FROM players ORDER BY id ASC;")
	if success:
		print(db.query_result)
	else:
		print("Look up failed: ", db.error_message)
