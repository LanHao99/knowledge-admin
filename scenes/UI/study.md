# study.gd (Study)

> **路径**: `res://scenes/ui/study.gd`
> **继承**: `Node2D`
> **类型**: UI层

## 概述

学习主入口场景，管理 **牌组选择 → 卡片学习 → 完成统计** 的完整流程。负责创建全部 Manager（DeckManager/CardManager/NoteManager/StudyManager/SimpleScheduler）并注入 CardUI，CardUI 只负责学习渲染本身。

## 状态机

```
PICKING ──► LEARNING ──► DONE
   ▲                        │
   │   返回牌组列表          │ 学习结束
   └────────────────────────┘
```

| 状态 | 可见元素 | 操作 |
|------|---------|------|
| `PICKING` | DeckPicker (牌组 Tree) | 双击牌组开始学习 |
| `LEARNING` | CardUI + InStudyBar (退出按钮) | 翻面、评分 |
| `DONE` | CompletionPanel (统计) | 返回牌组列表 |

## 节点结构

```
Study (Node2D)
├── DeckPicker (Control, full-screen)
│   └── MarginContainer → MainVBox
│       ├── TopBar (BackBtn "← 返回主菜单", TitleLabel)
│       ├── DeckTree (4列: 牌组/新/学习中/待复习)
│       └── StatusBar → StatusLabel
├── StudySession (Control) [保留, 占位]
├── CardUI (Control, full-screen) [实例化 card_ui.tscn]
├── CompletionPanel (Control, full-screen)
│   └── Margin → Center → VBox
│       ├── CompletionTitle  "🎉 学习完成！"
│       ├── CompletionStats  (RichTextLabel)
│       └── CompletionBackBtn "返回牌组列表"
├── InStudyBar (HBoxContainer, 学习时可见)
│   ├── ExitStudyBtn  "← 退出学习"
│   └── StudyingLabel "学习中…"
└── Camera2D
```

## 信号连接

| 来源 | 信号 | 回调 | 说明 |
|------|------|------|------|
| `DeckTree` | `item_activated` | `_on_deck_activated` | 双击牌组开始学习 |
| `BackBtn` | `pressed` | `_on_back_pressed` | 返回主菜单 |
| `ExitStudyBtn` | `pressed` | `_on_exit_study_pressed` | 学习中退出 |
| `CompletionBackBtn` | `pressed` | `_on_completion_back_pressed` | 完成面板返回 |
| `CardUI` | `study_finished` | `_on_study_finished` | 学习结束 |

## 公共方法

无。study.gd 为场景入口，不对外提供方法。

## 依赖注入链

```
Study._setup_managers()
├── DeckManager.setup(db_path) → DeckDB
├── CardManager.setup(db_path) → CardDB
│     └── set_scheduler(SimpleScheduler.new())
├── NoteManager.setup(db_path) → NoteDB + CardDB + DeckDB
└── StudyManager
      ├── set_card_manager(card_manager)
      └── set_note_manager(note_manager)

Study._inject_into_card_ui()
└── card_ui.set_managers(sm, nm, cm)
```

## 路由入口

`main_menu.gd` 中"开始学习"按钮 → `res://scenes/ui/study.tscn`
