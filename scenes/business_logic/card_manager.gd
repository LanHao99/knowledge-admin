extends Manager

# CardManager：处理“卡片（cards）”本体相关业务。
# 这里将来会放：
# - 查询到期卡片
# - 更新卡片队列状态（new/learn/review）
# - 记录评分后的字段变化（due/reps/lapses 等）
#
# 它偏向“卡片数据维护”，不负责整场学习流程编排。


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 预留：注入 db_manager 或做启动检查
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 预留：业务管理器通常不需要每帧轮询
	pass
