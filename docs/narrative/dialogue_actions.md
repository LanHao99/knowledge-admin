# Dialogue 剧情动作

## 发送壁纸

在 `.dialogue` 中直接调用，三个参数依次为图片路径、提示内容、是否允许“否”：

```text
do App.send_wallpaper("res://assets/wallpapers/mountain1.png", "收到一张壁纸，是否更换？", false)
```

`false` 表示只能选“是”；确认层没有标题栏关闭按钮，Esc、点击背景均不能拒绝。`true` 表示提供“是”和“否”，Esc 等同“否”。

图片在收到时解锁并立即保存。选择“是”后才运行 `game/dialogue/actions/send_wallpaper.gd`，自动更换并保存当前壁纸；选择“否”保留解锁状态，之后可到控制面板手动选择。无效图片不会弹窗，重复领取不会重复添加记录。

第二章第一段 `ch2_revelation.dialogue` 的 `~ 世界的真相` 开头发送 `mountain1.png`，不允许拒绝。`tower1.png` 也默认锁定，后续剧情可用同一调用解锁。

## 通用确认后运行脚本

```text
do App.run_confirmed_action("res://game/dialogue/actions/send_wallpaper.gd", "是否更换为已收到的壁纸？", true, ["res://assets/wallpapers/mountain1.png"])
```

参数为脚本路径、可编辑的提示、是否允许“否”和动作参数数组。脚本须继承 `RefCounted`，提供 `execute(arguments: Array) -> bool`；需要等待的动作可以在函数内使用 `await`。通用入口只负责确认与执行，壁纸须先由接收入口解锁。

```gdscript
extends RefCounted

## 在用户确认后执行剧情动作。## 输入: arguments (Array) - 剧本参数。输出: bool - 是否成功。
func execute(arguments: Array) -> bool:
	return not arguments.is_empty()
```

DialogueManager 会等待确认和动作执行完毕，再读取下一句。选“否”时不运行脚本。并发请求被拒绝，按钮重复点击只产生一次结果。

确认框布局位于 `game/dialogue/dialogue_action_confirmation.tscn`，使用现有主题，文案和是否允许“否”可在 Inspector 编辑，也可由上述剧情调用覆盖。CanvasLayer 覆盖剧情窗口，背景点击被拦截，Tab 在确认层按钮间循环。

测试播放会额外显示“停止测试”。停止会解除未决确认且不运行待确认动作，当前段不记完成；收到并已保存的解锁仍保留。剧情测试台的存档恢复只管理剧情数据，壁纸配置单独保存。

## 未知程序窗口破损

```text
do App.damage_story_window(0.7)
```

对当前正式剧情的未知程序使用窗口实验室相同的局部破损与整窗震动。`0` 恢复，`1` 最强。损伤在该窗口实例内保留，不写入存档，不影响继续阅读、选项和后续剧情。

```text
do App.shatter_story_window()
=> END
```

捕获最后画面，完成当前段剧情，退出并释放未知程序实例，然后继续播放桌面持有的破碎动画。释放后解除模态与任务栏状态，其他应用恢复使用，下段剧情创建新的无损窗口。快照失败时仍完成关闭，避免留下冻结窗口。

第一章 `~ 系统的警告` 中，“如果我不终止呢？”分支执行完整破碎并结束本段；另一分支到 `warning_choice` 的系统台词“再分配完成。非关键进程优先级已降低。”之后执行局部破损并继续对话。

剧情特效使用专用入口，只接受当前模态层中的未知程序。普通窗口特效仍保留剧情锁、帮助锁、学习会话、导入和确认框的保护。

## 壁纸存档

`WallpaperSettings` 在 `user://wallpaper_settings.cfg` 的 `[wallpaper]` 节保存 `path`、`mode` 和 `unlocked`。当前项目的 `user://` 由 SaveDirectory 指向项目 `saves/`。

`mountain1.png`、`tower1.png` 默认锁定，其他壁纸默认可用。控制面板显示“未解锁”并禁止选择，收到图片后已经打开的列表即时刷新。缺少解锁字段的旧存档保持这两张图片锁定；旧存档若正在使用其中一张而无解锁记录，回退为无壁纸。损坏或失效的解锁项被过滤。

## 验证入口

- `tests/unit/test_dialogue_actions.gd`：确认时序、是与否、Esc、重复调用、内部停止、接收存档及窗口释放。
- `tests/unit/test_wallpaper_settings.gd`：默认锁定、即时解锁落盘、读回、旧存档和损坏字段。
- `tests/desktop/verify_dialogue_actions.tscn`：隔离工程中验证真实剧情调用、两种破损、确认层与桌面壁纸的 GPU 画面。

Godot 4.7.2 下完整 GUT 95 项测试、646 条断言通过；剧情动作 GPU 35 项检查、原窗口特效 GPU 219 项检查及剧情测试台 GPU 265 项检查通过。覆盖 1280×720、1920×1080、80%～150% 字号，另由原回归验证最小窗口和画布缩放。

实际截图及报告保存在 [剧情动作验收目录](../scenes/desktop_review/dialogue_actions/validation.md)。
