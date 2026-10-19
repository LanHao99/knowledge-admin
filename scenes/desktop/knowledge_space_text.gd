class_name KnowledgeSpaceText
extends RefCounted
## 将卡片格式转换为不会执行标签或加载图片的空间纯文本。


## 去除支持的排版标签，保留普通方括号文字及原有换行。## 输入: source (String) - 正文。
## 输出: 纯文本，不请求任何外部资源。
static func plain_text(source: String) -> String:
	var expression: RegEx = RegEx.new()
	expression.compile("(?is)\\[img(?:=[^\\]]*)?\\].*?\\[/img\\]")
	var result: String = expression.sub(source, "[图片]", true)
	expression.compile("\\[/?(?:b|i|u|s|code|center|left|right|fill|color|bgcolor|font|font_size|url|outline_size|outline_color|indent|table|cell|ul|ol|li|p)(?:[= ][^\\]]*)?\\]")
	result = expression.sub(result, "", true)
	expression.compile("(?i)<br\\s*/?>|</(?:p|div)>")
	result = expression.sub(result, "\n", true)
	expression.compile("(?i)</?(?:p|div|b|strong|i|em|u|span)(?:\\s[^>]*)?>")
	result = expression.sub(result, "", true)
	return result.replace("&nbsp;", " ").replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&").strip_edges()


## 限制空间摘要长度，完整正文由阅读层持有。## 输入: source (String)、limit (int)。
## 输出: 不超过 limit 个字符的摘录。
static func excerpt(source: String, limit: int = 360) -> String:
	var length_limit: int = maxi(1, limit)
	return source if source.length() <= length_limit else source.left(length_limit - 1) + "…"
