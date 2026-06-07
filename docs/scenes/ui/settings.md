# Settings 设置场景

## 概述

设置场景，提供调试模式开关、教程重置和应用信息展示。

## 文件

| 文件 | 路径 |
|------|------|
| 场景 | `res://scenes/ui/settings.tscn` |
| 脚本 | `res://scenes/ui/settings.gd` |

## 节点树

```
Settings (Control)
├── RootMargin (MarginContainer)
│   └── MainVBox (VBoxContainer)
│       ├── TopBar (HBoxContainer)
│       │   ├── TitleLabel (Label) — "设置"
│       │   ├── TopSpacer (Control)
│       │   └── BackButton (Button, %BackButton) — "← 返回"
│       ├── ContentScroll (ScrollContainer)
│       │   └── SectionsVBox (VBoxContainer)
│       │       ├── GeneralSection (PanelContainer)
│       │       │   └── GeneralVBox
│       │       │       ├── SectionLabel — "通用"
│       │       │       ├── HSeparator
│       │       │       └── DebugRow (HBoxContainer)
│       │       │           ├── DebugLabel — 功能说明
│       │       │           └── DebugCheck (%DebugCheck)
│       │       ├── DataSection (PanelContainer)
│       │       │   └── DataVBox
│       │       │       ├── SectionLabel — "数据"
│       │       │       ├── HSeparator
│       │       │       └── TutorialRow (HBoxContainer)
│       │       │           ├── TutorialLabel — 功能说明
│       │       │           └── ResetTutorialBtn (%ResetTutorialBtn)
│       │       └── AboutSection (PanelContainer)
│       │           └── AboutVBox
│       │               ├── SectionLabel — "关于"
│       │               ├── HSeparator
│       │               ├── AppNameLabel — "Knowledge Admin"
│       │               └── DescLabel (RichTextLabel) — 应用描述
│       └── BottomBar (HBoxContainer)
│           ├── StatusLabel (%StatusLabel)
│           └── BottomSpacer (Control)
└── ResetTutorialConfirm (%ResetTutorialConfirm, ConfirmationDialog)
```

## 功能

### 调试模式开关

- 读取/写入 `DebugSettings` autoload（`res://src/debug_settings.gd`）
- 监听 `DebugSettings.debug_mode_changed` 信号，外部修改时同步 UI
- `CheckButton.toggled` → `DebugSettings.set_debug_mode(enabled)`

### 重置教程

- 点击按钮弹出 `ConfirmationDialog` 确认
- 确认后调用 `TutorialManager.reset_all()` 清除所有教程进度
- 状态栏显示成功提示

### 关于

- 显示应用名称和描述（RichTextLabel + BBCode）

### 返回

- `← 返回` 按钮通过 `get_tree().change_scene_to_file()` 跳转到 `main_menu.tscn`

## 脚本接口

### 生命周期

| 方法 | 说明 |
|------|------|
| `_ready()` | 连接信号、加载当前设置、检查教程 |
| `_connect_signals()` | 连接 UI 信号和 DebugSettings 全局信号 |
| `_load_current_settings()` | 从 DebugSettings 同步调试模式开关状态 |

### 回调

| 方法 | 说明 |
|------|------|
| `_on_back_pressed()` | 返回主菜单 |
| `_on_debug_toggled(enabled)` | 写入调试模式到 DebugSettings |
| `_on_reset_tutorial_pressed()` | 弹出确认对话框 |
| `_on_reset_tutorial_confirmed()` | 执行教程重置 |
| `_on_external_debug_changed(enabled)` | 外部修改时同步 UI |

### 工具方法

| 方法 | 说明 |
|------|------|
| `_switch_scene(path, label)` | 安全场景跳转 |
| `_set_status(text)` | 更新底部状态栏（BBCode 支持） |

## 依赖

| 模块 | 用途 |
|------|------|
| `DebugSettings` (Autoload) | 调试模式持久化 |
| `TutorialManager` (class_name) | 教程进度管理 |

## 入口

从主菜单 `TopBar → ⚙ 设置` 按钮跳转进入（`main_menu.gd:_on_settings_pressed()`）。
