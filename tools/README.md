# 维护工具

此目录由 AI 维护。

`verify_project_layout.py` 检查维护分工、场景与脚本分离、外部资源路径和本地 Markdown 链接。它只读取工程文件，可从项目根目录运行。

`archive/` 保存根目录已有的工程备份和 SQLite 动态库副本。实际使用的 SQLite 扩展在 `addons/godot-sqlite/`，归档目录通过 `.gdignore` 排除在 Godot 扫描之外。

迁移前快照和验证副本保存在本地忽略目录 `.temp/layout_migration/`。历史 AI 工作文件继续保存在隐藏目录 `.ai-tools/`，不作为运行时资源。
