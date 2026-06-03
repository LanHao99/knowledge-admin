# card_ui.gd (CardUI)

> **路径**: `res://scenes/ui/card_ui.gd`
> **继承**: `Control`
> **类型**: UI层

## 概述

卡片学习组件，负责渲染单张卡片的正反面内容，提供翻面交互与四档评分按钮（重来/困难/良好/简单）。监听 `StudyManager` 信号驱动 UI 状态切换。**不创建 Manager 也不处理导航**，由父场景（`study.gd`）通过 `set_managers()` 注入依赖，学习结束时发出 `study_finished` 信号。

## 依赖注入

```
study.gd._setup_managers()
    ├── DeckManager.setup(db_path)
    ├── CardManager.setup(db_path) + SimpleScheduler
    ├── NoteManager.setup(db_path)
    └── StudyManager (注入 CardManager + NoteManager)

study.gd → card_ui.set_managers(sm, nm, cm)
```

## 节点结构

```
CardUI (Control, full-screen, anchors full)
├── MainVBox (VBoxContainer, 边距 32/20)
│   ├── TopBar
│   │   ├── TopSpacer
│   │   ├── ProgressLabel  "3 / 15"
│   │   └── QueueLabel     "新卡片"
│   ├── CardPanel (PanelContainer, 点击翻面, mouse_filter=STOP)
│   │   └── PanelCenter → CardContentVBox
│   │       ├── ContentLabel  (RichTextLabel, bbcode, font 28)
│   │       └── FlipHint      "点击翻面 →"
│   ├── AnswerBar (默认隐藏)
│   │   ├── AgainBtn "重来"(红)  → rating=1
│   │   ├── HardBtn  "困难"(橙)  → rating=2
│   │   ├── GoodBtn  "良好"(绿)  → rating=3
│   │   └── EasyBtn  "简单"(蓝)  → rating=4
│   └── StatusBar → StatusLabel
```

## 状态机

```
LOADING → FRONT → BACK → FRONT → ... → DONE (emit study_finished)
```

## 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `study_finished` | `stats: Dictionary` | 学习会话结束，携带统计信息 |

## 公共方法

### `set_managers(study_manager, note_manager, card_manager) -> void`
注入三个 Manager 并自动连接 StudyManager 信号。由父场景在 `_ready()` 中调用。

### `start_study(deck_id: int) -> void`
启动学习会话。必须在 `set_managers()` 之后调用。

## 数据传输链路

```
study.gd → card_ui.start_study(deck_id)
    │
    ├── StudyManager.start_session(deck_id)
    │     → CardManager.get_study_queue() → CardDB → SQLite
    │     → emit session_started + card_shown(card_0, false)
    │
    ▼ _on_card_shown(card, false)
    │     → NoteManager.get_content_for_card(card.id)
    │       → CardDB.get_card_by_id() → CardEntity
    │       → NoteDB.get_note_by_id() → NoteEntity
    │       → {front, back} 缓存
    │
    ▼ 用户点击 CardPanel → show_answer() → emit card_shown(card, true)
    │     → 渲染 _cached_back，显示 AnswerBar
    │
    ▼ 用户点击评分按钮 → StudyManager.answer(rating)
    │     → CardManager.answer_card() → SimpleScheduler → CardDB.record_review()
    │     → emit card_shown(next_card, false) [自动推进]
    │     → 队列空 → emit session_ended
    │
    ▼ _on_session_ended → emit study_finished(stats)
    │     → study.gd 显示 CompletionPanel
```

---

> **注意**: CardUI 不可独立使用，须由 study.gd 注入 Manager 后调用 `start_study()`。
