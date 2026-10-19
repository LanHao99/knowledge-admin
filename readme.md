# Knowledge Admin

> 一个用 Godot 4.7 制作的桌面叙事游戏：表面是模仿 Anki 的闪卡复习软件，实际是一台运行着记忆系统的老旧电脑。

## 这是什么

玩家看到的是一台可以真实操作的 Windows 98 风格桌面。桌面上的「Knowledge Admin」是闪卡软件，牌组、笔记、卡片、FSRS 复习调度、JSON 批量导入都完整可用。学习时每一次评分（Again / Hard / Good / Easy）都会给埋在记忆系统里的 AI 意识体 MIRA 充能，进度条满格触发 AVG 对话，对话推进剧情，剧情又反过来改变桌面和卡面。

游戏不告诉玩家这是一款剧情游戏。闪卡是入口，桌面是容器，故事藏在文件夹和未知程序里。

## 三套引擎

| 引擎 | 职责 | 实现位置 |
| --- | --- | --- |
| 闪卡引擎 | 牌组 / 笔记 / 卡片 CRUD、FSRS 调度、学习队列 | `scenes/ui`、`scenes/business_logic`、`scenes/data_access`、`src/scheduler` |
| AVG 引擎 | 评分驱动进度、对话触发、选项羁绊、世界标记 | `game/dialogue`、`game/tutorial` |
| 桌面引擎 | 窗口层、任务栏、开始菜单、壁纸、窗口特效 | `scenes/desktop`、`src/window_manager.gd` |

允许的调用方向：

- 闪卡引擎只调用 `App.notify_card_answered()` 和 `App.present_card_text()`，不直接引用 `StoryManager`。
- AVG 引擎由 `App` 持有。选项通过 `StoryManager.on_dialogue_choice()` 写羁绊和标记，不改卡片表。
- 设置界面和卡面只问 `App.get_setting_extras()` 与 `App.present_card_text()`。卡面替换只改显示，数据库里的笔记原文保持不变。
- 教程和剧情都调用 `App.request_dialogue()`。学习场景不创建对话窗，只在 `dialogue_opened` 时藏起卡片。
- 标记规则集中在 `src/meta_rules.gd`。

## 架构分层

闪卡部分采用五层解耦，调用方向自上而下。

```text
UI 层          scenes/ui/                 渲染、接收输入、订阅信号，不碰数据库
逻辑层         scenes/business_logic/     业务校验、事务编排、跨实体协调、发信号
调度层         src/scheduler/             纯算法：当前状态 + 评分 → 下一状态，不做 I/O
实体层         src/entities/              纯数据结构，替代裸 Dictionary 传参
数据层         scenes/data_access/        SQL 拼装、参数绑定、结果集映射到实体
```

各层职责边界：

| 层级 | 允许 | 禁止 |
| --- | --- | --- |
| UI 层 | 调用 Manager、连接信号、展示数据 | 直接操作 `_db`、拼 SQL、修改 Entity |
| Manager 层 | 调用多个 DB 方法、开事务、调用 Scheduler、发信号 | 直接执行 SQL、操作节点树 |
| Scheduler 层 | 纯数学与状态计算 | 任何 I/O、数据库访问、UI 操作 |
| Entity 层 | 存数据、序列化辅助 | 业务逻辑、数据库访问 |
| DB 层 | 执行 SQL、参数绑定、返回实体 | 业务规则、跨表事务编排 |

## 目录结构

```text
res://
├── project.godot                 # 主场景 boot_screen.tscn；Autoload 注册
├── readme.md                     # 本文档
├── agents.md                     # AI 协作规范
│
├── scenes/
│   ├── desktop/                  # 桌面引擎
│   │   ├── boot_screen.tscn      # 启动封面与转场
│   │   ├── desktop.tscn          # 桌面、图标、任务栏
│   │   ├── managed_window.tscn   # 可拖动八向缩放的窗口
│   │   ├── my_computer / recycle_bin / camera / window_lab
│   │   ├── unknown_program       # 剧情宿主的隐藏程序
│   │   └── story_test_bench.tscn # 调试用剧情测试台
│   ├── ui/                       # 闪卡 UI 层
│   │   ├── main_menu.tscn        # 桌面内的学习主页
│   │   ├── deck_list / note_list / settings
│   │   ├── study / study_session / card_ui
│   │   └── debug_crud_panel      # 调试 CRUD 控制台
│   ├── business_logic/           # 逻辑层 Manager
│   │   ├── manager.gd            # 基类：事务、统一返回结构、变更信号
│   │   ├── deck_manager / note_manager / card_manager
│   │   ├── study_manager / notetype_manager / import_manager
│   ├── data_access/              # 数据层
│   │   ├── db_manager.gd         # 基类：SQLite 共享连接、schema 初始化
│   │   └── deck_db / note_db / card_db / notetype_db
│   └── import_*.gd               # JSON 导入向导各步骤
│
├── src/
│   ├── app.gd / app.tscn         # App 门面（Autoload）
│   ├── window_manager.gd         # 应用注册表与窗口唯一管理器
│   ├── meta_rules.gd             # 标记规则表
│   ├── ui_settings / shortcut_settings / wallpaper_settings / debug_settings
│   ├── save_directory.gd         # 将 user:// 重定向到 res://saves
│   ├── entities/                 # 实体层
│   ├── scheduler/                # 调度层：Scheduler / SimpleScheduler / FsrsScheduler
│   └── utils/schema_parser.gd    # JSON schema 解析
│
├── game/
│   ├── AI/ai_debug.tscn          # AI 制卡助手
│   ├── dialogue/                 # AVG：剧本、管理器、覆盖层、动作
│   └── tutorial/                 # 教程系统
│
├── data/
│   ├── db_schema.json            # 表结构配置
│   └── desktop/my_computer_files.tres  # 我的电脑预设文档
│
├── tests/
│   ├── unit/                     # GUT 单元测试
│   ├── desktop/                  # 隔离工程验收脚本
│   ├── ui/                       # UI 渲染验收
│   └── fixtures/                 # 测试替身
│
├── assets/                       # 图标、壁纸、主题、立绘
├── docs/                         # 设计与实现文档，见下方索引
└── saves/                        # 运行时存档（已 gitignore）
```

## 运行时数据

存档目录被 `src/save_directory.gd` 重定向到 `res://saves`，所以 `user://` 的实际落点是工程内的 `saves` 目录。

| 文件 | 内容 |
| --- | --- |
| `user://knowledge_admin.db` | SQLite 数据库：decks / notes / cards / note_types |
| `user://story_progress.tres` | 剧情进度、羁绊、世界标记、章节 |
| `user://tutorial_progress.tres` | 教程完成记录 |
| `user://ui_settings.cfg` | 全局字体倍率 |
| `user://shortcut_settings.cfg` | 学习快捷键绑定 |
| `user://wallpaper_settings.cfg` | 壁纸路径、显示方式、解锁列表 |
| `user://my_computer_documents.cfg` | 我的电脑文档覆盖档 |
| `user://settings.tres` | 调试模式开关 |
| `user://ai_settings.cfg` | AI 制卡助手的 System prompt 设置 |
| `user://api.cfg` | DeepSeek API 密钥（不属于仓库） |

## 文档索引

| 主题 | 位置 |
| --- | --- |
| 桌面系统 | [docs/scenes/desktop.md](docs/scenes/desktop.md) |
| 启动封面 | [docs/scenes/boot_screen.md](docs/scenes/boot_screen.md) |
| 窗口实验室 | [docs/scenes/window_lab.md](docs/scenes/window_lab.md) |
| 摄像头 | [docs/scenes/camera.md](docs/scenes/camera.md) |
| 剧情测试台 | [docs/scenes/story_test_bench.md](docs/scenes/story_test_bench.md) |
| 闪卡 UI | [docs/scenes/ui/ui.md](docs/scenes/ui/ui.md) |
| 逻辑层 | [docs/scenes/business_logic/逻辑层.md](docs/scenes/business_logic/逻辑层.md) |
| 数据层 | [docs/scenes/data_access/数据层.md](docs/scenes/data_access/数据层.md) |
| 实体层 | [docs/src/entities/实体层.md](docs/src/entities/实体层.md) |
| App 门面 | [docs/src/app.md](docs/src/app.md) |
| 调度层 | [docs/src/scheduler/](docs/src/scheduler/) |
| 数据结构 | [docs/data/数据结构.md](docs/data/数据结构.md) |
| JSON 导入设计 | [docs/system_design.md](docs/system_design.md) |
| 叙事设计 | [docs/narrative/README.md](docs/narrative/README.md) |
| 剧情动作 | [docs/narrative/dialogue_actions.md](docs/narrative/dialogue_actions.md) |
| 字体与主题 | [docs/scenes/ui/typography.md](docs/scenes/ui/typography.md) |
| 学习快捷键 | [docs/scenes/ui/shortcuts.md](docs/scenes/ui/shortcuts.md) |
| FMOD 音频 | [docs/audio/fmod_integration.md](docs/audio/fmod_integration.md) |

## 开发约定

完整规范见 `agents.md`，要点：

- 新增或修改功能时，同步更新**最近目录**下的 md 文档。
- 代码遵循 Godot 4.7 写法，使用强类型标注。
- 每个函数在**上方**用 `##` 注释写明功能、`## 输入:`、`## 输出:`。
- 写 md 时标题不带编号，不使用「一、」「1.」这类前缀。
- 不在代码里写「第 n 版」「最终版」「更新 xxx」之类的修改记录。
- 完成任务后补充学习记录。

## 测试

单元测试位于 `tests/unit`，基于 GUT，运行方式：

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

工程内没有 `.gutconfig.json`，所以必须显式传 `-gdir`；单元测试都在 `tests/unit` 平铺，加不加 `-ginclude_subdirs` 都能找到。

桌面和 UI 的验收脚本位于 `tests/desktop` 与 `tests/ui`，需要在 `application/config/name` 改为验证专用名称的隔离工程里运行，避免写入正式存档。

## 外部依赖

| 插件 | 用途 |
| --- | --- |
| dialogue_manager | 解析 `.dialogue` 剧本并驱动对话 |
| godot-sqlite | SQLite 数据层底层 |
| fmod | 音频（已注册 FmodManager，音库尚未接入） |
| gut | 单元测试框架 |
| kanban_tasks | `kanban_tasks_data.kanban` 看板 |
