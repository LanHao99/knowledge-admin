extends Manager

# StudyManager：处理“学习会话（study session）”流程。
# 这里将来会放：
# - 开启学习会话
# - 按按钮提交评分（Again/Hard/Good/Easy）
# - 推进到下一张卡
# - 汇总本轮学习统计
#
# 它偏向“流程编排”，会调用 CardManager/NoteManager 的能力。


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 预留：注入 db_manager 或做启动检查
	pass
