# debug_crud_panel.gd

> **路径**: `res://scenes/ui/debug_crud_panel.gd`
> **继承**: `Control`
> **类型**: UI层

## 概述

调试控制台面板，提供 Deck + Note 的完整 CRUD 操作界面和日志输出。

## 公共方法

### `truncate_string(s: String, max_len: int) -> String`

**输入**: `s` (String) — 原始字符串；`max_len` (int) — 最大长度。
**输出**: String — 截断后字符串，超出部分用 … 替代。
**说明**: 截断字符串到指定长度。
**修饰**: `static`
