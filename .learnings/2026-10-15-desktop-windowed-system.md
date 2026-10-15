# 2026-10-15 Classic98 桌面 Shell 与窗口化应用系统

**日期**: 2026-10-15  
**任务**: 实现 Classic98 伪桌面体验

## 实现内容

- `scenes/desktop/boot_screen.{gd,tscn}` — 约 2 秒启动画面，点击/按键可跳过
- `scenes/desktop/desktop.{gd,tscn}` — 桌面主场景，青绿背景、图标网格、任务栏
- `scenes/desktop/managed_window.{gd,tscn}` — 可拖拽/可缩放模拟窗口，8 方向缩放，标题栏颜色激活状态
- `scenes/desktop/taskbar.{gd,tscn}` — 底部任务栏（时钟、开始按钮、任务按钮）
- `scenes/desktop/start_menu.{gd,tscn}` — 弹出式开始菜单，含确认退出
- `scenes/desktop/unknown_program.{gd,tscn}` — 剧情应用，含锁定关闭/最小化的逻辑
- `scenes/desktop/my_computer.{gd,tscn}`, `recycle_bin.tscn` — 演示深度应用
- `src/window_manager.gd` — Autoload：单实例应用管理、Z 轴排序、任务栏同步
- `tests/unit/test_window_manager.gd` — 8 个 GUT 测试，全部通过

## 关键设计决策

### in-window 页面导航
`App.goto_scene(path)` 检测 WindowManager 是否就绪；就绪时调用 `navigate_in_active()`，在当前活动窗口的 ContentArea 内替换场景内容；无活动窗口时降级为全屏切换，保持向后兼容。

### `get_window()` 方法名冲突
`Node` 基类有 `get_window() -> Window` 内置方法，GDScript 4.7 禁止重写。将自定义方法改名为 `get_app_window(app_id)`。教训：命名前检查 Godot 内置方法表。

### const REGISTRY 为只读字典
Godot 4.x `const Dictionary` 在运行时不可修改。测试中不得尝试写入，需改用完全不存在的 key 进行负向测试。

### 任务栏调用 `_on_minimize_pressed` 的方式
对 ManagedWindow 公开方法的调用（最小化）需要通过公开接口，而不是调用私有方法。当前用 `call()` 临时实现；后续应改为公开 `minimize()` 方法。

## 待完善事项

- 现有应用场景（main_menu、deck_list 等）内有嵌套桌面背景，需在后续任务中剥离，实现干净的 in-window 显示
- 未知程序的剧情触发逻辑（`App._on_story_triggered` 调用 `open_app("unknown_program")`）需与现有对话覆盖层整合
- 桌面图标目前为纯文字按钮，需替换为图标 + 标签的双击样式
- App.open_app / close_app 对 WindowManager 未就绪时的降级路径仍用 `Engine.has_singleton()`，可改为直接引用 WindowManager autoload

## 验证结果

- Godot 4.7.2 headless: 所有单元测试 22/22 通过（14 个原有 + 8 个新增）
- 已有场景的 `_switch_scene` 调用已全部替换为 `App.goto_scene()`
