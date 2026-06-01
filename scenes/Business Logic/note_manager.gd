extends Manager

# NoteManager：处理“笔记（notes）”相关业务。
# 这里将来会放：
# - 创建笔记
# - 编辑笔记字段
# - 删除笔记
# - 根据 note_type 生成对应 cards
#
# 设计目标：
# - 让 UI 只传数据，不关心数据库细节
# - 用 run_in_transaction 保证多步操作安全


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 预留：注入 db_manager 或做启动检查
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 预留：业务管理器通常不需要每帧轮询
	pass
