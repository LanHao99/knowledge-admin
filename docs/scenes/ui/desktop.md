# 桌面 Shell 与窗口化应用系统

## 概述

Classic98 伪桌面体验。游戏从启动画面进入桌面，所有应用在可拖拽、可缩放的模拟窗口内运行。

## 入口

- 主场景：`res://scenes/desktop/boot_screen.tscn`
  - 启动时播放约 3 秒，单击或按键加速中心溶解
  - 下层提前初始化 `res://scenes/desktop/desktop.tscn`，遮罩溶解后恢复桌面交互
  - 全屏液态波浪与“正在启动系统”文字统一溶解，露出下层真实桌面，具体设计及参数见 [启动封面](../boot_screen.md)

## 桌面场景

`res://scenes/desktop/desktop.tscn` + `desktop.gd`

- 背景：青绿色 ColorRect
- 左侧图标网格：从 `WindowManager.get_visible_apps()` 动态生成
- 图标共享桌面实例内的 `ButtonGroup`，单击切换唯一选中高亮；重复单击保持选中，双击仍启动应用
- 窗口容器（%WindowContainer）：所有窗口在此层级内排列
- 任务栏（%Taskbar）：底部 32px，显示开始按钮、任务按钮、时钟

## 窗口管理器

路径：`res://src/window_manager.gd`（Autoload `WindowManager`）

应用注册表 `REGISTRY`（const Dictionary）包含：

| 键 | 描述 |
|---|---|
| `knowledge_admin` | 知识管理主界面 |
| `ai_cards` | AI 制卡助手 |
| `control_panel` | 控制面板（设置） |
| `my_computer` | 我的电脑（演示） |
| `recycle_bin` | 回收站（演示） |
| `unknown_program` | 未知程序（hidden，剧情触发） |

主要接口：

- `open_app(app_id)` — 单实例，已开启则激活现有窗口
- `close_app(app_id)` — 释放窗口节点，清理任务栏按钮
- `navigate_in_active(path)` — 在当前活动窗口内切换内容场景
- `get_visible_apps()` — 返回 entry_visible=true 的应用列表
- `get_app_window(app_id)` — 返回窗口实例（含最小化状态）

## 模拟窗口

`res://scenes/desktop/managed_window.tscn` + `managed_window.gd`

功能：

- 标题栏拖拽（防止超出屏幕顶部）
- 双击标题栏切换最大化/恢复
- 最小化（隐藏节点）、最大化（充满除任务栏外区域）、关闭
- 8 方向缩放（边缘 6px 响应区）
- 激活/非激活时标题栏颜色切换（蓝/灰）
- `set_close_locked(bool)` / `set_minimize_locked(bool)` — 剧情锁定
- `navigate_to(path)` — 在 %ContentArea 内切换场景

## 任务栏

`res://scenes/desktop/taskbar.gd`

- 时钟每秒更新
- 开始菜单弹出层（popup，点击外部关闭）
- `add_app_button / remove_app_button / set_active_button` — 由 WindowManager 调用

## 开始菜单

`res://scenes/desktop/start_menu.tscn` + `start_menu.gd`

- 动态列出可见应用
- "关闭系统"弹出确认对话框后调用 `App.quit_app()`

## App 接口变化

新增：
- `App.open_app(app_id)` — 委托给 WindowManager
- `App.close_app(app_id)` — 委托给 WindowManager

变更：
- `App.goto_scene(path)` — 优先调用 `WindowManager.navigate_in_active(path)`；无活动窗口时降级为全屏切换

## 未知程序（剧情应用）

`res://scenes/desktop/unknown_program.tscn` + `unknown_program.gd`

- 不出现在桌面图标或开始菜单中（`entry_visible = false`）
- 由剧情触发 `WindowManager.open_app("unknown_program")`
- 剧情进行时：窗口关闭和最小化被锁定
- 对话结束后进入待机状态；关闭待机窗口只隐藏，背景实例保留

## 应用内导航

所有导航调用已从 `get_tree().change_scene_to_file(path)` 改为 `App.goto_scene(path)`，修改的文件：

- `scenes/ui/main_menu.gd`
- `scenes/ui/settings.gd`
- `scenes/ui/note_list.gd`
- `scenes/ui/deck_list.gd`
- `scenes/ui/study_session.gd`
- `scenes/ui/debug_crud_panel.gd`
- `game/AI/ai_debug.gd`

## 演示应用

- `my_computer.tscn` — 显示预设目录列表，演示深度
- `recycle_bin.tscn` — "回收站为空"提示，演示深度

## 测试

`tests/unit/test_window_manager.gd` — 8 个测试覆盖注册表、信号、空值安全

`tests/desktop/verify_desktop.tscn` 支持 `--desktop-selection-only`：真实鼠标依次点击所有图标，检查唯一高亮、重复单击及双击启动。

Godot 4.7.2 验证结果：1280×720 与 1920×1080 各 41 项交互检查通过；窗口管理与窗口场景 GUT 测试 13 项、42 个断言通过。

截图和实际渲染检查见 [review](review/)（如有）。
