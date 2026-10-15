# app.gd (App)

> **路径**: `res://src/app.gd`
> **继承**: `Node`
> **类型**: 全局单例 (Autoload)

## 概述

主逻辑门面。跨场景保存世界标记，把闪卡评分转给 AVG，并按 `MetaRules` 改设置行和卡面显示。

不包含 FSRS，也不解析 `.dialogue`。闪卡 Manager 仍由各个界面自己创建。

Autoload 顺序放在 `DialogueManager` 之后，保证启动时对话单例已经存在。

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
- `quit_app()`：延迟退出。

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

## 桌面应用导航

桌面常驻时，open_app / close_app 由 WindowManager 管理单实例窗口；goto_scene 将闪卡页面放入闪卡宿主，AI 与控制面板分别打开独立窗口。request_dialogue 新增可选 source 来源节点，正式剧情进入隐藏软件，教程进入使用帮助。详见 ../scenes/desktop.md。
