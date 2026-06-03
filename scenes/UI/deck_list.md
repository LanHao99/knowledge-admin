# deck_list.gd (DeckList)

> **路径**: `res://scenes/ui/deck_list.gd`
> **继承**: `Control`
> **类型**: UI层

## 概述

牌组管理界面，用 Tree 控件展示牌组树形结构（支持 parent_id 嵌套层级）。双击展开编辑面板，支持重命名/移动父级/归档/删除操作。新建牌组通过 ConfirmationDialog 弹出。

## 功能

1. **树形列表**：`Tree` 控件递归展示 `DeckDB.get_deck_tree()` 的嵌套牌组结构，四列（牌组名 / 新卡片数 / 复习卡片数 / 总计）
2. **卡片统计**：每个牌组节点显示 `DeckDB.get_deck_card_counts()` 的实时统计，归档牌组灰色显示
3. **内嵌编辑**：双击牌组展开编辑面板，可修改名称、移动父牌组、归档/恢复、查看卡片统计
4. **新建牌组**：`ConfirmationDialog` 弹出，选择父牌组（支持根级）
5. **自动刷新**：监听 `DeckManager.entity_created/updated/deleted` 信号

## 公共方法

### `_ready() -> void`
初始化 DeckManager、绑定信号、刷新列表。

### `_rebuild_tree() -> void`
从 `DeckDB.get_deck_tree()` 获取树形数据，递归构建 Tree 节点，每节点附带卡片统计。

### `_add_deck_tree_node(parent_item, node) -> void`
递归辅助方法，将 `{deck, children}` 节点添加到 Tree。

### `_show_editor(deck: DeckEntity) -> void`
展开编辑面板，填充名称/父牌组下拉/归档状态/卡片统计。

### `_on_save_pressed() -> void`
批量检查变更并调用 `DeckManager.rename_deck()` / `move_deck()` / `archive_deck()`。

### `_refill_parent_select(option, current_parent_id, exclude_id) -> void`
填充父牌组下拉列表，自动排除当前编辑的牌组（防止循环引用）。

## 信号

无自定义信号。通过 DeckManager 继承信号驱动刷新。

## 与 note_list 的对比

| 特性 | deck_list | note_list |
|------|-----------|-----------|
| 数据结构 | 树形 (parent_id 嵌套) | 按 deck_id 分组 |
| 列表控件 | Tree（递归嵌套） | Tree（两层分组） |
| 列数 | 4（名称/新/复习/总计） | 3（摘要/牌组/日期） |
| 编辑内容 | 名称、父级、归档 | fields_data 字段 |
| 统计信息 | 卡片统计 (new/learning/review/total) | 笔记计数 |
