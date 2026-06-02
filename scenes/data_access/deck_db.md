# deck_db.gd (DeckDB)

> **路径**: `res://scenes/data_access/deck_db.gd`
> **继承**: `DBManager`
> **类型**: 数据层

## 概述
牌组数据访问层，提供牌组（deck）的增删改查、树形结构组装及卡片统计功能。

## 公共方法

### `create_deck(name: String, parent_id: int = 0, sort_order: int = 0) -> Dictionary`
**输入**: name (String) — 牌组名称，不能为空；parent_id (int) — 父牌组 ID，0 表示根级牌组；sort_order (int) — 同级排序值，越小越靠前。
**输出**: 返回标准字典。成功时 `data` 为 DeckEntity。
**说明**: 创建一个新牌组并返回创建后的实体对象。

### `get_deck_by_id(deck_id: int) -> Dictionary`
**输入**: deck_id (int) — 牌组 ID。
**输出**: 返回标准字典。成功时 `data` 为 DeckEntity；未找到时为 null。
**说明**: 根据 ID 查询单个牌组。

### `get_deck_by_name(name: String) -> Dictionary`
**输入**: name (String) — 牌组名称。
**输出**: 返回标准字典。成功时 `data` 为 DeckEntity；未找到时为 null。
**说明**: 根据名称查询单个牌组。

### `update_deck(deck: DeckEntity) -> Dictionary`
**输入**: deck (DeckEntity) — 待更新的牌组实体，要求 id > 0。
**输出**: 返回标准字典。成功时 `data` 为 null。
**说明**: 更新已有牌组数据。

### `delete_deck(deck_id: int) -> Dictionary`
**输入**: deck_id (int) — 要删除的牌组 ID。
**输出**: 返回标准字典。成功时 `data` 为 null。
**说明**: 删除指定牌组。

### `get_all_decks(include_archived: bool = false) -> Dictionary`
**输入**: include_archived (bool) — 是否包含归档牌组。
**输出**: 返回标准字典。成功时 `data` 为 Array[DeckEntity]。
**说明**: 获取全部牌组列表。

### `get_child_decks(parent_id: int) -> Dictionary`
**输入**: parent_id (int) — 父牌组 ID；传 0 获取根级牌组。
**输出**: 返回标准字典。成功时 `data` 为 Array[DeckEntity]。
**说明**: 获取某个父牌组下的直接子牌组。

### `get_deck_tree() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典。成功时 `data` 为树节点数组，节点结构为 `{deck: DeckEntity, children: Array}`。
**说明**: 组装牌组树结构。

### `get_deck_card_counts(deck_id: int) -> Dictionary`
**输入**: deck_id (int) — 牌组 ID。
**输出**: 返回标准字典。成功时 `data` 为 `{new, learning, review, total}`。
**说明**: 获取某个牌组下的卡片统计。

## 常量
| 常量 | 值 | 说明 |
|------|-----|------|
| — | — | 本文件未定义常量，引用外部 `CardEntity.QUEUE_NEW`、`CardEntity.QUEUE_LEARNING`、`CardEntity.QUEUE_REVIEW`。 |
