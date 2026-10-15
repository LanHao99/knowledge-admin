class_name MetaRules
extends RefCounted
## 主逻辑使用的标记规则表。
## 一条规则在标记为真时，可以解锁设置行，或替换卡面显示文本。
## 不读取数据库，也不播放对话。卡面替换只影响显示。


## 调试通路使用的标记名。为真时设置出现提示行，且所有卡正面显示成密码。
const DEBUG_META_FLAG: String = "debug_meta_unlock"

## 调试规则写到卡面上的密码文本。card_id 为 0 表示不限制具体卡片。
const DEBUG_CARD_PASSWORD: String = "7F-META"


## 返回全部标记规则。## 输入: 无。
## 输出: Array - 规则字典数组。每条含 when_flag，以及可选的 unlock_setting / replace_card_text。
static func all() -> Array:
	return [
		{
			"id": "debug_meta_password",
			"when_flag": DEBUG_META_FLAG,
			"unlock_setting": {
				"id": "debug_meta_hint",
				"label": "调试 meta：卡面正面已替换为密码",
				"control": "label",
			},
			"replace_card_text": {
				"card_id": 0,
				"side": "front",
				"text": DEBUG_CARD_PASSWORD,
			},
		},
	]
