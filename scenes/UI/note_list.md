# note_list.gd (NoteList)

> **路径**: `res://scenes/ui/note_list.gd`
> **继承**: `Control`
> **类型**: UI层

## 概述

笔记列表界面，按牌组分组展示所有笔记（类似 Windows 文件系统布局）。支持双击编辑、新建笔记、自动刷新。

## 功能

1. **树形列表**：`Tree` 控件按 `deck_id` 分组，三列（笔记摘要 / 牌组 / 创建时间）
2. **内嵌编辑**：双击笔记项展开 `EditPanel`，动态生成 `fields_data` 字段编辑器
3. **新建笔记**：`ConfirmationDialog` 弹出，选择牌组 + 填写正面/背面内容
4. **自动刷新**：监听 `NoteManager.entity_created/updated/deleted` 信号，自动重建列表

## 公共方法

### `_ready() -> void`
初始化 Manager、绑定信号、刷新列表。失败时显示"数据库初始化失败"。

### `_exit_tree() -> void`
断开信号连接并释放 NoteManager/DeckManager 实例。

### `_rebuild_tree() -> void`
全量重建 Tree：按 `deck_id` 分组，每组显示笔记摘要（fields_data 首个字段前 40 字符）。

### `_show_editor(note: NoteEntity) -> void`
展开编辑面板，为 `note.fields_data` 每个字段生成 Label + LineEdit 编辑行。

### `_on_new_note_pressed() -> void`
弹出新建对话框，填充牌组下拉列表。

## 信号

无自定义信号。通过 NoteManager 继承信号驱动刷新。

## 常量

无。

## 依赖

- `NoteManager` — 场景内自建实例（`add_child + setup(db_path)`）
- `DeckManager` — 场景内自建实例（获取 deck_id → deck_name 映射）
- `NoteEntity` — 数据载体（v1.1 已添加 `deck_id` 字段）

## 与 debug_crud_panel 的差异

| 特性 | debug_crud_panel | note_list |
|------|-----------------|-----------|
| 目的 | 调试/开发用 CRUD 控制台 | 用户使用的笔记浏览界面 |
| 列表控件 | `ItemList` (平铺) | `Tree` (按牌组分组的树形) |
| 编辑方式 | 表单 + 按钮触发 CRUD | 双击展开内嵌编辑面板 |
| 刷新机制 | 手动点击"刷新"按钮 | 自动监听 Manager 信号 |
