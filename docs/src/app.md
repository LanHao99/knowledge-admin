# app.gd (App)

> **路径**: `res://src/app.gd`
> **继承**: `Node`
> **类型**: 全局单例 (Autoload)

## 概述

主逻辑门面。跨场景保存世界标记，把闪卡评分转给 AVG，并按 `MetaRules` 改设置行和卡面显示。

不包含 FSRS，也不解析 `.dialogue`。闪卡 Manager 仍由各个界面自己创建。

Autoload 顺序放在 `DialogueManager` 之后，保证启动时对话单例已经存在。

## 全局存档目录

`SaveDirectory` 必须排在全部 Autoload 的首位，在其他单例读取存档前切换 Windows 游戏进程的 `user://`。配置文件为 `res://src/save_directory.gd`：

- `ENABLED = true`：启用指定目录；改为 `false` 后，下次运行恢复引擎默认用户目录。
- `DIRECTORY = "res://saves"`：当前工作区对应 `D:/game design/godot/4.6projects/knowledge-admin/saves/`。也可以填写其他绝对路径。

照常使用 F5/F6。剧情、好感度、世界标记、教程、闪卡数据库、字号、快捷键、调试设置及 AI 配置都沿用 `user://`，实际读写统一进入该目录。启动输出中的 `[SaveDirectory] user:// = ...` 显示当前路径。

目录通过 `.gdignore` 排除资源导入，通过 `.gitignore` 排除实际存档与个人密钥。仅当前游戏进程的 `APPDATA` 和运行时项目设置被调整，不写入系统环境变量；重新运行前已打开的编辑器配置和引擎启动日志不随之搬迁。其他平台保留引擎默认路径。发布前应将 `ENABLED` 改为 `false`。

切换目录不会自动读取旧目录。已有存档可在游戏停止后复制过来；SQLite 数据库应通过一致性备份复制，避免遗漏尚在 WAL 中的数据。

验收见 `tests/unit/test_save_directory.gd`，覆盖启动顺序，以及文件、配置、剧情资源、SQLite 的写入和重新读取。隔离工程的 47 项单元测试、238 条断言通过。

## 公共方法

- `get_flag` / `set_flag`：读写 `user://story_progress.tres` 里的 `flags`。
- `notify_card_answered(rating)`：闪卡评分入口。内部调用 `StoryManager.on_review_answered()`。
- `present_card_text(card_id, side, raw_text)`：卡面写到屏幕前的过滤器。不写数据库。
- `get_setting_extras()`：当前标记下要动态加到设置界面的行。
- `request_dialogue(resource, key, track_story)`：剧情与教程共用的串行入口，正文分别由未知程序与使用帮助承载。`track_story` 为 false 时不把教程记成剧情完成。
- `goto_scene(path)`：桌面常驻时路由至对应应用，闪卡页面在其宿主窗口中导航。
- `debug_fill_and_trigger()`：调试按钮用，填满进度并按 Easy 触发一次对话。
- `reset_global_save()`：重置当前剧情存档和教程进度，不删除闪卡数据库。章节回到 `chapter_1`。
- `add_bond(amount)` / `get_bond()`：好感度读写。对话选项用 `do App.add_bond(1)` 增减；`if App.get_bond() >= 8` 可做句内分支。
- `quit_app()`：延迟退出。测试播放中改为停止测试，不退出游戏。
- `run_confirmed_action(script_path, message, allow_no, arguments)`：等待确认后运行脚本的 `execute(arguments)`，拒绝时不执行。
- `send_wallpaper(path, message, allow_no)`：收到时解锁并保存，确认后自动更换壁纸。`allow_no = false` 表示只能选“是”。
- `damage_story_window(amount)` / `shatter_story_window()`：对正在播放的未知程序施加局部破损，或完整破碎并完成本段。详见 [Dialogue 剧情动作](../narrative/dialogue_actions.md)。
- `get_story_test_state()` / `get_story_catalog()` / `preview_next_story()`：测试台读取状态、目录和下一段。预览不修改存档。
- `read_story_draft()` / `update_story_draft()` / `apply_story_draft()` / `revert_story_draft()`：草稿编辑。只有应用会写当前游戏。
- `start_next_story()` / `jump_to_story()` / `stop_story_test()`：测试播放。调试模式关闭，或已有剧情在播放、排队时，不能启动。
- `reset_story_data()` / `list_story_backups()` / `restore_story_backup()`：只处理剧情。重置和恢复前自动备份。`reset_global_save()` 仍会同时重置教程。

## 剧情判断

没有独立的剧情判断器。

- 下一段播什么：`StoryManager._pick_dialogue_key()` / `_pick_bond_dialogue_key()`。
- 这一句显不显示：Dialogue Manager 的 `if` / `else`，条件可以调用 `App.get_bond()` 或 `App.get_flag()`。

好感度存在 `user://story_progress.tres` 的 `bond` 字段。增量只写在 `.dialogue` 里，不要再在代码里做一份对照表。

## 信号

- `card_presented(card_id, side, shown_text)`
- `card_answered(rating)`
- `dialogue_opened(dialogue_key)` / `dialogue_closed(dialogue_key)`
- `flags_changed(flag_name, value)`
- `story_progress_changed(current, threshold)`
- `story_state_changed`：进度、好感度、标记、完成记录或章节变化时发出。测试台用它刷新，原有进度和标记信号仍然发出。
- `story_test_stopped(reason)`：测试播放被停止，并带上要显示的原因。

## 桌面应用导航

桌面常驻时，open_app / close_app 由 WindowManager 管理单实例窗口；goto_scene 将闪卡页面放入闪卡宿主，AI 与控制面板分别打开独立窗口。request_dialogue 新增可选 source 来源节点，正式剧情进入隐藏软件，教程进入使用帮助。详见 ../scenes/desktop.md。

## 会话日期时间

AppClock 在 App 之前作为 Autoload 初始化，只持有进程内的时间偏移。日期时间窗口通过现有 App.open_app 与 WindowManager 注册表打开；独立设置页由 WindowContext.open_time_settings(content) 建立嵌入窗口。调时影响闪卡时间，不产生评分或剧情充能。见 [日期和时间](../scenes/date_time.md)。
