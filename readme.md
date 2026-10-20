# Knowledge Admin

> 一个用 Godot 4.7 制作的桌面叙事游戏：表面是模仿 Anki 的闪卡复习软件，实际是一台运行着记忆系统的老旧电脑。

## 这是什么

玩家看到的是一台可以真实操作的 Windows 98 风格桌面。桌面上的「Knowledge Admin」是闪卡软件，牌组、笔记、卡片、FSRS 复习调度、JSON 批量导入都完整可用。学习时每一次评分（Again / Hard / Good / Easy）都会给埋在记忆系统里的 AI 意识体 MIRA 充能，进度条满格触发 AVG 对话，对话推进剧情，剧情又反过来改变桌面和卡面。

游戏不告诉玩家这是一款剧情游戏。闪卡是入口，桌面是容器，故事藏在文件夹和未知程序里。

## 快速开始

使用 Godot 4.7 打开根目录的 `project.godot`。目前功能验证使用 Godot 4.7.2、Windows 和 Forward+ / D3D12。

首次导入后，确认 Dialogue Manager 和 Godot SQLite 插件可用，再按 F5 启动完整桌面。主场景是 `content/scenes/desktop/boot_screen.tscn`；日常调整布局可在 `content/scenes/` 打开对应场景。

| 想做什么 | 从哪里开始 |
| --- | --- |
| 调整场景、素材、剧情和内容配置 | [内容维护入口](content/README.md) |
| 修改行为脚本、业务逻辑和复习算法 | [实现维护入口](src/README.md) |
| 确认场景与脚本的对应关系 | [文件维护分工](docs/file_maintenance.md) |
| 查看当前项目计划 | 根目录的 `kanban_tasks_data.kanban` |
| 运行检查与验收 | [测试维护入口](tests/README.md) |

## 桌面中的常用入口

| 入口 | 功能 |
| --- | --- |
| Knowledge Admin | 牌组、笔记、卡片管理，学习与复习，JSON 导入 |
| AI 制卡助手 | 通过 DeepSeek 对话生成卡片并导入；使用前配置自己的 API Key |
| 我的电脑 | 查看预设文档，编辑虚拟文档内容并保存本地覆盖档 |
| 知识空间 | 浏览知识文档与学习内容，支持聚焦、关闭、最小化和正视展开 |
| 控制面板 | 字号、快捷键、壁纸，以及日期和时间设置 |
| 摄像头 | MIRA 摄像头画面与可调整的 CRT 效果 |
| 窗口实验室、剧情测试台 | 窗口特效和剧情调试；剧情测试台只在调试模式显示 |
| 右下角时钟 | 单击或聚焦后按 Enter，打开日期和时间窗口 |

日期和时间可以在本次运行中调整，影响到期卡片、复习队列和评分时间。关闭、重开软件内窗口保留时间偏移，重启整个程序恢复真实时间；已经保存的评分和到期时间会保留。完整规则见 [日期和时间](docs/scenes/date_time.md)。

## 三套引擎

| 引擎 | 职责 | 实现位置 |
| --- | --- | --- |
| 闪卡引擎 | 牌组 / 笔记 / 卡片 CRUD、FSRS 调度、学习队列 | `content/scenes/ui`、`src/ui`、`src/business_logic`、`src/data_access`、`src/scheduler` |
| AVG 引擎 | 评分驱动进度、对话触发、选项羁绊、世界标记 | `content/dialogue/`、`src/dialogue/`、`src/tutorial/` |
| 桌面引擎 | 窗口层、任务栏、开始菜单、壁纸、窗口特效 | `content/scenes/desktop`、`src/window_manager.gd` |

允许的调用方向：

- 闪卡引擎只调用 `App.notify_card_answered()` 和 `App.present_card_text()`，不直接引用 `StoryManager`。
- AVG 引擎由 `App` 持有。选项通过 `StoryManager.on_dialogue_choice()` 写羁绊和标记，不改卡片表。
- 设置界面和卡面只问 `App.get_setting_extras()` 与 `App.present_card_text()`。卡面替换只改显示，数据库里的笔记原文保持不变。
- 教程和剧情都调用 `App.request_dialogue()`。学习场景不创建对话窗，只在 `dialogue_opened` 时藏起卡片。
- 标记规则集中在 `src/meta_rules.gd`。

## 架构分层

闪卡部分采用五层解耦，调用方向自上而下。

```text
UI 层      src/ui/ + content/scenes/ui/   渲染、接收输入、订阅信号
逻辑层     src/business_logic/            业务校验、事务编排、发信号
调度层     src/scheduler/                 纯算法，不做 I/O
实体层     src/entities/                  实体数据与序列化
数据层     src/data_access/               SQL、参数绑定、实体映射
```

各层职责边界：

| 层级 | 允许 | 禁止 |
| --- | --- | --- |
| UI 层 | 调用 Manager、连接信号、展示数据 | 直接操作 `_db`、拼 SQL、修改 Entity |
| Manager 层 | 调用多个 DB 方法、开事务、调用 Scheduler、发信号 | 直接执行 SQL、操作节点树 |
| Scheduler 层 | 纯数学与状态计算 | 任何 I/O、数据库访问、UI 操作 |
| Entity 层 | 存数据、序列化辅助 | 业务逻辑、数据库访问 |
| DB 层 | 执行 SQL、参数绑定、返回实体 | 业务规则、跨表事务编排 |

## 目录结构与维护分工

你日常编辑的内容集中在 `content/`，AI 维护的实现集中在 `src/`，测试和维护工具分别在 `tests/`、`tools/`。`.tscn` 只放在场景目录，`.gd` 放在实现或测试脚本目录；插件保留各自的布局。`content/scenes/system/` 是由 AI 维护的系统装配场景。详细对应关系见 [文件维护分工](docs/file_maintenance.md)。

```text
res://
├── content/                      # 你维护：场景、内容与素材
│   ├── README.md                 # 内容编辑入口
│   ├── scenes/                   # .tscn 场景，与脚本分开
│   │   ├── desktop/              # 桌面、窗口、启动、摄像头与知识空间
│   │   ├── ui/                   # 闪卡、牌组、设置与导入向导
│   │   ├── ai/                   # AI 制卡助手场景
│   │   ├── dialogue/             # 对话框与动作确认场景
│   │   └── system/               # AI 维护的系统装配场景
│   ├── dialogue/story/           # 剧情与大纲 .dialogue
│   ├── dialogue/tutorial/        # 教程 .dialogue
│   ├── data/desktop/             # 我的电脑、知识空间 .tres 内容
│   ├── data/import_examples/     # JSON 导入示例
│   └── assets/                   # 图标、壁纸、主题、字体、立绘与 Banks
├── src/                          # AI 维护：.gd 实现
│   ├── desktop/、ui/、ai/        # 场景行为
│   ├── dialogue/、tutorial/      # 剧情与教程实现
│   ├── business_logic/           # Manager 业务层
│   ├── data_access/              # DB 数据层
│   ├── entities/、scheduler/     # 实体与复习算法
│   ├── resources/                # 自定义 Resource 类型
│   ├── shaders/                  # .gdshader 着色器
│   ├── data/db_schema.json       # 数据库结构
│   ├── app_clock.gd              # 本次运行的软件时间服务
│   └── utils/                    # 解析、存档读取工具
├── tests/                        # AI 维护：自动化验证
│   ├── scenes/                   # 验收 .tscn
│   ├── scripts/                  # 验收 .gd
│   ├── unit/                     # GUT 单元测试 .gd
│   └── fixtures/                 # 动作替身与对白样本
├── tools/                        # AI 维护：目录检查与归档
├── docs/                         # 设计、功能说明与验证证据
├── addons/                       # 插件及依赖，保持插件自己的目录布局
├── saves/                        # 本地运行存档
├── project.godot                 # 主场景与 Autoload
├── kanban_tasks_data.kanban       # 你的项目计划
├── agents.md                     # AI 协作规范
└── readme.md                     # 项目入口
```

原根目录的图片与主题归入 `content/assets/`，示例 JSON 归入 `content/data/`，已有工程备份和动态库副本保存在 `tools/archive/`。本地配置 `api.cfg` 仍留在根目录；Godot 缓存和 AI 临时工作区保持隐藏。

## 运行时数据

Windows 下，`src/save_directory.gd` 将 `user://` 重定向到工程内的 `saves/`。其他平台沿用 Godot 的用户数据目录。场景、素材和内容配置属于工程资源，运行产生的数据保存在 `user://`。

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

AI 制卡助手优先读取 `user://api.cfg`，未配置时才回退到根目录的 `api.cfg`；在界面保存的密钥写入用户配置。`api.cfg`、`.env` 和运行存档不提交到 Git。

目录调整前保存的剧情、教程和剧情备份仍可读取，加载时通过临时副本转换脚本路径。壁纸设置兼容素材路径的变化，保留已有选择与解锁记录。

## 文档索引

| 主题 | 位置 |
| --- | --- |
| 维护分工 | [docs/file_maintenance.md](docs/file_maintenance.md) |
| 桌面系统 | [docs/scenes/desktop.md](docs/scenes/desktop.md) |
| 日期和时间 | [docs/scenes/date_time.md](docs/scenes/date_time.md) |
| 知识空间 | [docs/scenes/knowledge_space.md](docs/scenes/knowledge_space.md) |
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

目录与静态资源引用检查可直接在项目根目录执行：

```powershell
python tools/verify_project_layout.py
```

GUT 单元测试位于 `tests/unit`。以下 Godot 命令在独立验证副本的根目录执行；将 `godot` 替换为本机 Godot 4.7 可执行程序：

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd "-gdir=res://tests/unit" -ginclude_subdirs -gexit
godot --headless --path . --script res://tests/scripts/verify_resources.gd
```

工程内没有 `.gutconfig.json`，需要显式传入 `-gdir`。桌面和 UI 验收场景在 `tests/scenes/`，脚本在 `tests/scripts/desktop/` 与 `tests/scripts/ui/`。

验证副本排除正式 `saves/`、私密配置和缓存；桌面验收使用工程名 `KnowledgeAdminDesktopVerification`，UI 验收使用 `KnowledgeAdminUiVerification`。详细操作见 [测试维护入口](tests/README.md)。

日期和时间功能的最近一次回归记录为 147 项中 140 项通过，另有 7 项既有的“我的电脑”控件引用失败。测试结果、真实渲染与重启验证证据见 [日期和时间验证记录](docs/scenes/date_time.md#验证记录)。

## 外部依赖

| 插件 | 用途 |
| --- | --- |
| dialogue_manager | 解析 `.dialogue` 剧本并驱动对话 |
| godot-sqlite | SQLite 数据层底层 |
| gut | 单元测试框架 |
| godot_dotnet_mcp | 编辑器与 AI 工具连接 |

FMOD 和 Kanban 是本地可选工作流。FMOD 的 Banks 目录为 `content/assets/Banks/`，业务播放接入仍待完成，见 [音频接入说明](docs/audio/fmod_integration.md)。Kanban 插件用于编辑根目录的 `kanban_tasks_data.kanban`。这两个插件当前未纳入 Git 跟踪，首次获取仓库时需要按需另行安装。
