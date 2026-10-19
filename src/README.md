# 实现维护入口

这个目录由 AI 维护，集中存放项目自己的 GDScript、着色器和数据库结构。可编辑场景在 `../content/scenes/`。

| 目录或文件 | 职责 |
| --- | --- |
| `desktop/` | 桌面、窗口、任务栏、启动和摄像头行为 |
| `ui/` | 学习界面、导入向导和通用界面行为 |
| `ai/` | AI 制卡助手实现 |
| `dialogue/` | 剧情推进、存档、文字动画和剧情动作 |
| `tutorial/` | 教程触发和完成记录 |
| `business_logic/` | 业务校验、事务编排与 Manager |
| `data_access/` | SQLite 访问与 DB |
| `entities/` | 实体数据结构 |
| `scheduler/` | 复习调度算法 |
| `resources/` | 内容资源的类型定义；实例在 `content/data/` |
| `shaders/desktop/` | 桌面和窗口着色器 |
| `data/db_schema.json` | 数据库结构配置 |
| `utils/` | JSON 解析和持久化资源加载工具 |
| 根目录 `.gd` | App、窗口注册表、全局设置与存档目录单例 |

新增实现遵守根目录 `agents.md`，每个函数上方写明功能、输入和输出，按 Godot 4.7 编写。修改界面脚本时一并检查对应 `.tscn`，保持节点名和信号契约一致。

`utils/progress_resource_loader.gd` 通过临时副本兼容剧情及教程存档中的脚本路径，原存档保持原样。壁纸设置读取时兼容 `res://assets/wallpapers/` 路径，保存时使用当前内容目录。

业务说明在 [实现文档](../docs/src/)，界面说明在 [场景文档](../docs/scenes/)，验证方式见 [测试入口](../tests/README.md)。
