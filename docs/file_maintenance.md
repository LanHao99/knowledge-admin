# 文件维护分工

## 日常维护

| 维护者 | 位置 | 维护内容 |
| --- | --- | --- |
| 你 | `content/scenes/` | 场景布局、节点外观与 Inspector 导出参数 |
| 你 | `content/assets/` | 图标、壁纸、立绘、字体、主题和 FMOD Banks |
| 你 | `content/dialogue/` | 正式剧情、大纲和教程对白 |
| 你 | `content/data/` | 桌面预设文档、知识空间和导入示例 |
| 你 | `docs/narrative/`、`kanban_tasks_data.kanban` | 叙事设计与项目计划 |
| AI | `src/` | GDScript、着色器、资源类型、数据库结构与全局单例 |
| AI | `tests/`、`tools/` | 自动化测试、验收场景和维护工具 |
| AI | `docs/src/`、`docs/scenes/`、`docs/audio/` | 实现文档、功能说明与验证证据 |
| AI | `.learnings/`、`.learnings.md` | 经验记录 |
| 共同确认 | `project.godot`、`export_presets.cfg`、`addons/` | 工程设置、导出配置和插件依赖 |

`content/scenes/system/` 是系统装配场景，由 AI 维护。其余内容入口见 [content/README.md](../content/README.md)，实现入口见 [src/README.md](../src/README.md)。

## 场景与脚本对应

| 场景 | 脚本 |
| --- | --- |
| `content/scenes/desktop/camera.tscn` | `src/desktop/camera.gd` |
| `content/scenes/ui/main_menu.tscn` | `src/ui/main_menu.gd` |
| `content/scenes/ai/ai_debug.tscn` | `src/ai/ai_debug.gd` |
| `content/scenes/dialogue/story_dialogue_overlay.tscn` | `src/dialogue/story_dialogue_overlay.gd` |
| `content/scenes/system/app.tscn` | `src/app.gd` |
| `tests/scenes/desktop/verify_desktop.tscn` | `tests/scripts/desktop/verify_desktop.gd` |

自有 `.tscn` 只进入 `content/scenes/` 或 `tests/scenes/`，自有 `.gd` 只进入 `src/` 或 `tests/`。插件目录维持各插件自己的布局，升级时整体处理。`.gdshader` 集中在 `src/shaders/`，其参数仍可从场景中的 ShaderMaterial 调整。

## 根目录与本地文件

根目录保留工程入口、说明、协作规范、看板和本地配置。`api.cfg` 及 `.env` 属于私密本地配置；`saves/` 是运行时存档；`.godot/` 是 Godot 缓存；`.temp/` 和 `.ai-tools/` 是 AI 本地工作区。上述缓存和工作区不作为内容入口。

原根目录的图标、启动图片和备用主题分别在 `content/assets/branding/` 与 `content/assets/themes/`。`test_import.json` 位于 `content/data/import_examples/`。已有的工程备份与 SQLite 动态库副本保存在 `tools/archive/`。

## 引用与存档

移动资源时同时保留 `.uid`、`.import`，并同步场景外部资源、`load` / `preload`、Autoload、项目设置、对白动作和工作流路径。`content/scenes/ui` 统一使用小写路径，避免 Windows 本地大小写不敏感掩盖导出问题。

剧情、教程和剧情备份中无 UID 的脚本引用由 `src/utils/progress_resource_loader.gd` 在临时副本里转换，原文件不会被覆盖。壁纸设置读取时保留原来的选择、显示方式和解锁记录。正式 `saves/` 与测试副本的存档分别留在各自工程内。

新增内容写入对应入口；实现变动更新最近的功能文档，完成后填写 `.learnings`，验证后仅提交本次任务的变动。目录检查和验证方法见 [tests/README.md](../tests/README.md)。

## 验证记录

整理前已创建独立基线工程。原有完整 GUT 的 123 项测试中，116 项通过，7 项因“我的电脑”界面的控件引用失败。迁移后的 127 项中，120 项通过；失败仍是同一组 7 项，新增 4 项存档兼容测试全部通过。

Godot 4.7.2 成功加载并实例化全部 39 个自有场景，解析全部 78 个实现脚本。目录检查覆盖 106 个自有及测试脚本和 241 条外部资源引用，通过维护分工、场景脚本分离与维护入口文档链接检查。另修复了 21 条 Classic95 样式资源中已有的跨项目图片路径。

D3D12 / Forward+ 实际渲染通过摄像头的 17 项验收。原始日志、基线对照和迁移对应表保存在本地 `.temp/layout_migration/`。导入时还有现有 FMOD 和 DialogueManager 的编辑器诊断，日志予以保留；上述资源加载与渲染验收均已结束。
