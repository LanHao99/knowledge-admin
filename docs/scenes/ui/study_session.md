# study_session.gd (StudySession)

> **路径**: `res://scenes/ui/study_session.gd` / `study_session.tscn`
> **继承**: `Control`
> **类型**: UI 层 — 学习入口场景
> **状态**: 已实现（牌组选择 + 卡片学习 + 完成统计）

## 概述

学习入口场景，负责**牌组选择 → 卡片学习 → 完成统计**的完整学习流程。自行创建全部 Manager 并注入 CardUI，CardUI 只负责学习渲染本身。

## 状态机

```
PICKING → LEARNING → DONE → PICKING
```

| 状态 | 视图 | 说明 |
|------|------|------|
| PICKING | DeckPicker 可见 | 展示牌组列表（含新/学习中/待复习统计），支持双击选择 |
| LEARNING | CardUI 可见 + InStudyBar 浮层 | 卡片学习流程，浮层栏显示牌组名和进度 |
| DONE | CompletionPanel 可见 | 展示会话统计（完成数/耗时/评分分布） |

## 节点结构

```
StudySession (Control, full-screen)
├── DeckPicker (Control, visible=切换)
│   └── RootMargin (MarginContainer)
│       └── MainVBox (VBoxContainer)
│           ├── TopBar (HBoxContainer)
│           │   ├── BackBtn "← 返回主菜单"
│           │   ├── TitleLabel "选择牌组开始学习"
│           │   └── TopSpacer
│           ├── DeckTree (Tree, columns=4: 牌组/新/学习中/待复习)
│           └── StatusBar → StatusLabel
├── CardUI (instance, visible=切换)
├── InStudyBar (HBoxContainer, layout_mode=0 浮层定位)
│   ├── ExitStudyBtn "← 退出学习"
│   ├── DeckNameLabel "牌组: xxx"
│   ├── StudySpacer (expand)
│   └── ProgressLabel "x / y"
└── CompletionPanel (Control, visible=切换)
    └── CompletionMargin → CompletionCenter → CompletionVBox
        ├── CompletionTitle "🎉 学习完成！"
        ├── CompletionStats (RichTextLabel, BBCode 统计)
        └── CompletionBackBtn "返回牌组列表"
```

## 数据流

```
PICKING: DeckTree双击
    → _on_deck_activated() 获取 deck_id + deck_name
    → _start_learning(deck_id)
        ├── 隐藏 DeckPicker，显示 CardUI + InStudyBar
        └── _card_ui.start_study(deck_id)

LEARNING: StudyManager信号
    → session_started → InStudyBar 显示牌组名称
    → queue_updated  → InStudyBar 刷新进度 (done/total)
    → session_ended  → 清空进度文字

DONE: CardUI.study_finished
    → _on_study_finished(stats)
        ├── 隐藏 CardUI + InStudyBar
        └── CompletionPanel 显示统计

退出学习: ExitStudyBtn
    → StudyManager.end_session()
    → 隐藏 CardUI + InStudyBar
    → _build_deck_list() 刷新
    → 显示 DeckPicker（回到 PICKING 状态）
```

## 依赖注入

```
StudySession._setup_managers()
    ├── DeckManager.setup(db_path)
    ├── CardManager.setup(db_path) + SimpleScheduler
    ├── NoteManager.setup(db_path)
    └── StudyManager (注入 CardManager + NoteManager)

StudySession._inject_into_card_ui()
    → card_ui.set_managers(sm, nm, cm)
```

## 信号

| 信号来源 | 信号 | 回调 | 说明 |
|----------|------|------|------|
| CardUI | `study_finished` | `_on_study_finished` | 学习结束，切换完成面板 |
| StudyManager | `session_started` | `_on_session_started` | 更新 InStudyBar 牌组名 |
| StudyManager | `queue_updated` | `_on_queue_updated` | 刷新 InStudyBar 进度 |
| StudyManager | `session_ended` | `_on_session_ended` | 清空进度 |

## 公共方法

### `class_name StudySession`
声明类名，可供其他场景引用。
