extends SceneTree

var GutRunner = load("res://addons/gut/gui/GutRunner.tscn")
var GutConfig = load("res://addons/gut/gut_config.gd")


func _initialize() -> void:
	var runner = GutRunner.instantiate()
	root.add_child(runner)

	var config = GutConfig.new()
	config.options.dirs = ["res://test"]
	config.options.should_exit = true
	config.options.compact_mode = true
	config.options.disable_colors = false
	runner.set_gut_config(config)

	await process_frame
	runner.run_tests(false)
