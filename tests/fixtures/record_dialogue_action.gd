extends RefCounted
## 为确认流程提供可观察的副作用，不访问玩家数据。


## 每次执行累加传入字典的计数。## 输入: arguments (Array) - 第一项为状态字典。输出: bool。
func execute(arguments: Array) -> bool:
	var state: Dictionary = arguments[0]
	state["count"] = int(state.get("count", 0)) + 1
	return true
