所有AI遵循原则：

1. 参考编辑程序的目录下的md文档的要求完成功能，如有新功能应写入最近的md文档
2. 代码必须符合Godot 4.6的规范
3. 每个函数要求明确注释功能，类似格式：
4. 及时提交git，并在提交信息中注明修改内容、AI平台


```gdscript
## 解析 JSON 文件并返回 schema_config 字典。## 输入: file_path (String) - JSON 文件的绝对或相对路径（如 "res://data/db_schema.json"）。
## 输出: 返回标准字典。成功时 `data` 为解析出来的 Dictionary。
static func parse_json_file(file_path: String) -> Dictionary:
```

