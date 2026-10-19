# 内容维护入口

这个目录集中放你在 Godot 编辑器里调整的内容；实现脚本在项目根目录的 `src/`。

| 你要改什么 | 打开哪里 |
| --- | --- |
| 启动画面、桌面和窗口布局 | `scenes/desktop/*.tscn` |
| 学习主页、卡片、牌组和设置界面 | `scenes/ui/*.tscn` |
| AI 制卡助手布局 | `scenes/ai/ai_debug.tscn` |
| 对话框外观 | `scenes/dialogue/*.tscn` |
| 正式剧情与大纲 | `dialogue/story/*.dialogue` |
| 首次使用教程 | `dialogue/tutorial/*.dialogue` |
| 我的电脑预设文档 | `data/desktop/my_computer_files.tres` |
| 知识空间内容 | `data/desktop/knowledge_space.tres` |
| 壁纸、立绘、图标、字体与主题 | `assets/` |
| FMOD Banks | `assets/Banks/` |
| JSON 导入示例 | `data/import_examples/test_import.json` |

场景节点和 Inspector 中的导出参数可以直接调整。`scenes/system/` 是 App、业务管理器和数据库节点的装配场景，由 AI 负责维护；只有需要修改系统装配时才打开。

场景和脚本按模块对应，例如 `scenes/desktop/camera.tscn` 对应 `../src/desktop/camera.gd`。编辑场景时保留脚本挂载、唯一节点名和信号连接；需要调整这些接口时连同对应脚本一起处理。

`.uid`、`.import` 由 Godot 管理。用编辑器移动素材并保留这些文件，避免打断资源标识和导入设置。

完整维护分工见 [维护指南](../docs/file_maintenance.md)，叙事设计见 [叙事文档](../docs/narrative/README.md)，项目计划仍在根目录的 `kanban_tasks_data.kanban`。
