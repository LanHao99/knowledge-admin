extends Node2D

# 这是当前项目的 UI 入口脚本。
# 现在它还是一个空壳，后续会在这里挂按钮：
# - 进入牌组列表
# - 进入笔记列表
# - 开始学习
#
# 建议把 project.godot 的 run/main_scene 指向 main_menu.tscn，
# 这样程序启动就会先进到这个入口页。


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 预留：初始化主菜单按钮和跳转逻辑
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 预留：主菜单通常不需要每帧逻辑
	pass
