extends Manager

# DeckManager：处理“牌组（decks）”相关业务。
# 这里将来会放：
# - 创建牌组
# - 重命名牌组
# - 删除/归档牌组
# - 查询牌组列表
#
# 注意：
# - 不直接操作 UI
# - 不直接拼复杂 SQL 给界面层
# - 对外返回统一的 ok/fail 字典


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 预留：注入 db_manager 或做启动检查
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 预留：业务管理器通常不需要每帧轮询
	pass
