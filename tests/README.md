# 测试维护入口

这个目录由 AI 维护。测试场景与脚本分别存放：

| 路径 | 内容 |
| --- | --- |
| `unit/` | GUT 单元测试，只放脚本 |
| `scenes/desktop/`、`scenes/ui/` | 桌面和 UI 验收场景，只放 `.tscn` |
| `scripts/desktop/`、`scripts/ui/` | 对应验收场景的 GDScript |
| `scenes/data/`、`scripts/data/` | SQLite 调试场景和脚本 |
| `fixtures/` | 测试用动作脚本和对白 |
| `scripts/verify_resources.gd` | 扫描并加载全部自有脚本和场景 |

先用 `python tools/verify_project_layout.py` 检查目录分工与场景、资源的文件引用。

GUT 入口保持为 `addons/gut/gut_cmdln.gd`，测试目录为 `res://tests/unit`，并传入 `-ginclude_subdirs -gexit`。资源加载检查使用 `--headless --script res://tests/scripts/verify_resources.gd`。

运行验收和完整测试时复制独立工程，排除 `api.cfg`、`.env`、`.git` 与正式 `saves/`。桌面验收的工程名称为 `KnowledgeAdminDesktopVerification`；UI 验收使用 `KnowledgeAdminUiVerification`。`src/save_directory.gd` 会把进程的存档写到测试副本自己的 `saves/`。
