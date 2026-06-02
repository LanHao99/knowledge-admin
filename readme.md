# 项目结构

本项目使用使用godot来模仿anki的卡片功能

### 文件结构总览

```text
res://
├── scenes/
│   ├── UI/                          # UI 层场景
│   │   ├── main_menu.tscn
│   │   ├── deck_list.tscn
│   │   ├── note_list.tscn
│   │   ├── study_session.tscn
│   │   └── card_ui.tscn
│   ├── Business Logic/              # 逻辑层
│   │   ├── manager.gd               # 基类（已有 ✅）
│   │   ├── deck_manager.gd          # 待填充
│   │   ├── note_manager.gd          # 待填充
│   │   ├── card_manager.gd          # 待填充
│   │   └── study_manager.gd         # 待填充
│   └── Data Access/                 # 数据层
│       ├── db_manager.gd            # 基类（已有 ✅，需补 last_insert_rowid）
│       ├── deck_db.gd               # 待填充
│       ├── note_db.gd               # 待填充
│       └── card_db.gd               # 待填充
├── src/                             # 新增：实体层 + 调度层
│   ├── entities/
│   │   ├── deck_entity.gd
│   │   ├── note_entity.gd
│   │   ├── card_entity.gd
│   │   └── study_session_entity.gd
│   └── scheduler/
│       ├── scheduler.gd             # 抽象基类
│       └── simple_scheduler.gd      # 默认实现
├── data/
│   └── db_schema.json               # 表结构配置（已有 ✅）
└── scenes/
    └── 程序结构.md                   # 本文档
```

### 架构总览（五层解耦）

```text
┌──────────────────────────────────────────────────────────────────┐
│  UI 层 (Control/Scene)                                          │
│  main_menu / deck_list / note_list / study_session / card_ui    │
│  职责：渲染、接收输入、订阅信号刷新、绝不直接碰数据库              │
├──────────────────────────────────────────────────────────────────┤
│  逻辑层 (Business Logic / Manager)                              │
│  DeckManager / NoteManager / CardManager / StudyManager         │
│  职责：业务规则校验、事务编排、跨实体协调、发射变更信号            │
├──────────────────────────────────────────────────────────────────┤
│  调度层 (Scheduler)  ← 新增解耦层                                │
│  Scheduler / FsrsScheduler (未来可扩展)                          │
│  职责：纯算法 —— 输入【当前状态+评分】→ 输出【下一状态】            │
│  绝不触碰数据库，便于替换算法（SM-2 → FSRS → 自定义）              │
├──────────────────────────────────────────────────────────────────┤
│  实体层 (Entity)  ← 新增解耦层                                    │
│  DeckEntity / NoteEntity / CardEntity                            │
│  职责：纯数据结构（数据行映射），替代 Dictionary 裸传               │
├──────────────────────────────────────────────────────────────────┤
│  数据层 (Data Access / Repository)                               │
│  DBManager (基类) / deck_db / note_db / card_db                 │
│  职责：SQL 拼装、参数绑定、结果集 → Entity 映射、基础 CRUD         │
└──────────────────────────────────────────────────────────────────┘
```

### 解耦核心原则

| 层级              | 允许做的事                                | 禁止做的事                       |
| --------------- | ------------------------------------ | --------------------------- |
| **UI 层**        | 调用 Manager 方法、连接信号、展示数据              | 直接操作 `_db`、拼 SQL、修改 Entity  |
| **Manager 层**   | 调用多个 DB 方法、启动事务、调用 Scheduler、emit 信号 | 直接执行 SQL、直接操作 Godot 节点树     |
| **Scheduler 层** | 纯数学/状态计算                             | 任何 I/O、数据库访问、UI 操作          |
| **Entity 层**    | 存数据、提供序列化/反序列化辅助                     | 任何业务逻辑、数据库访问                |
| **DB 层**        | 执行 SQL、参数绑定、返回 Entity 或字典            | 业务规则判断、跨表事务编排（由 Manager 负责） |

---

## 二、节点类型设计（Godot 节点树规划）

> 明确每个组件在 Godot 中的存在形式：**场景(.tscn)**、**子节点实例**、**Autoload 单例** 还是 **纯脚本(RefCounted)**。

### 2.1 总览表

| 节点/脚本                     | 层级  | Godot 类型           | 放置方式                                       | 说明                         |
| ------------------------- | --- | ------------------ | ------------------------------------------ | -------------------------- |
| `main_menu`               | UI  | **场景 .tscn**       | 根级场景切换 (`get_tree().change_scene_to_file`) | 独立全屏入口界面                   |
| `deck_list`               | UI  | **场景 .tscn**       | 根级场景切换                                     | 牌组列表主界面                    |
| `deck_editor`             | UI  | **场景 .tscn**       | `deck_list` 的子节点实例                         | 嵌入在牌组列表内的编辑面板（滚动式设置界面）     |
| `note_list`               | UI  | **场景 .tscn**       | 根级场景切换                                     | 笔记列表主界面                    |
| `note_editor`             | UI  | **场景 .tscn**       | `note_list` 的子节点实例 / 弹窗                    | 嵌入在笔记列表内的编辑面板（按字段数动态生成编辑栏） |
| `study_session`           | UI  | **场景 .tscn**       | 根级场景切换                                     | 学习进度展示主界面                  |
| `card_ui`                 | UI  | **场景 .tscn**       | `study_session` 的子节点实例                     | 嵌入在学习界面内的卡片展示区（正反面翻转）      |
| `App`（或 `ServiceLocator`） | 全局  | **Autoload .gd**   | 项目设置 → 自动加载                                | 全局唯一容器，统筹所有 Manager 和 DB   |
| `db_manager`              | 数据  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 数据库基类，一般不独立使用              |
| `deck_db`                 | 数据  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 牌组数据访问                     |
| `note_db`                 | 数据  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 笔记数据访问                     |
| `card_db`                 | 数据  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 卡片数据访问                     |
| `manager`（基类）             | 逻辑  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 逻辑基类，一般不独立使用               |
| `deck_manager`            | 逻辑  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 牌组业务逻辑                     |
| `note_manager`            | 逻辑  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 笔记业务逻辑                     |
| `card_manager`            | 逻辑  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 卡片业务逻辑                     |
| `study_manager`           | 逻辑  | **Node .gd**       | `App` 的子节点（运行时实例化）                         | 学习会话编排                     |
| `DeckEntity`              | 实体  | **RefCounted .gd** | **不进入节点树**                                 | 纯数据对象，Manager 方法间传递        |
| `NoteEntity`              | 实体  | **RefCounted .gd** | **不进入节点树**                                 | 纯数据对象                      |
| `CardEntity`              | 实体  | **RefCounted .gd** | **不进入节点树**                                 | 纯数据对象                      |
| `StudySessionEntity`      | 实体  | **RefCounted .gd** | **不进入节点树**                                 | 纯数据对象（暂态会话数据）              |
| `Scheduler`               | 调度  | **RefCounted .gd** | **不进入节点树**                                 | 抽象基类，纯算法                   |
| `SimpleScheduler`         | 调度  | **RefCounted .gd** | **不进入节点树**                                 | 具体算法实现                     |
| `FsrsScheduler`           | 调度  | **RefCounted .gd** | **不进入节点树**                                 | 未来预留算法                     |

### 2.2 为什么这样设计？

| 类型                       | 适用场景                                 | 本项目对应                                                     |
| ------------------------ | ------------------------------------ | --------------------------------------------------------- |
| **场景 .tscn**             | 有视觉控件、需要编辑器布局、需要独立生命周期               | 所有 UI 界面（菜单、列表、编辑器、学习界面）                                  |
| **子节点实例**                | 作为某个父场景的组成部分，跟随父场景一起加载/销毁            | `deck_editor` 嵌入 `deck_list`；`card_ui` 嵌入 `study_session` |
| **Autoload .gd**         | 全局唯一、跨场景存续、需要被任何脚本随时访问               | `App` 单例容器，持有所有 Manager 和 DB                              |
| **Node .gd（非 Autoload）** | 需要加入节点树（接收 `_ready`、信号传播）、但不适合做成场景文件 | Manager 和 DB 作为 `App` 的子节点运行时实例化                          |
| **RefCounted .gd**       | 纯数据或纯算法，不需要节点树生命周期，用完自动释放            | Entity 实体类、Scheduler 调度器                                  |

## Anki 设计模式参考摘要

| Anki 模式                 | 本项目的对应实现                                       | 收益                 |
| ----------------------- | ---------------------------------------------- | ------------------ |
| `Collection` 中央协调器      | `Manager` 基类提供统一 DB 入口                         | 避免各子管理器各自持有数据库连接   |
| `Card`/`Note` 实体类       | `CardEntity`/`NoteEntity`                      | 类型安全、代码补全、消除裸字典    |
| `DBProxy` 封装原始 SQL      | `DBManager` 基类                                 | 统一错误处理、返回值格式、事务管理  |
| `Scheduler` 算法独立        | `Scheduler` 抽象层 + `SimpleScheduler`            | 算法可替换、可单测、不耦合 I/O  |
| `OpChanges` 变更通知        | Manager 层的 `entity_created/updated/deleted` 信号 | UI 自动刷新、避免手动轮询     |
| `hooks.card_will_flush` | Godot `signal` 系统                              | 扩展点：插件/外部模块可监听关键事件 |
| 事务由调用方（Manager）控制       | `run_in_transaction(Callable)`                 | 跨表操作原子性，失败自动回滚     |

## 下一步实施建议

1. **P0 — 先补基础设施**：
   
   - DBManager 加 `last_insert_rowid()`
   
   - 创建 `src/entities/` 下的三个实体类
   
   - 创建 `src/scheduler/scheduler.gd` 基类

2. **P1 — 填充 DB 层**：
   
   - 按本章 3.2/3.3/3.4 实现 `deck_db` / `note_db` / `card_db`
   
   - 每个方法需附带单测（或至少手动验证 SQL）

3. **P2 — 填充 Manager 层**：
   
   - 按 5.2/5.3/5.4/5.5 实现四个 Manager
   
   - `StudyManager` 建议最后实现，因为它依赖其他三个 Manager

4. **P3 — 对接 UI**：
   
   - UI 层逐步从"直接思维"改为"订阅信号 + 调用 Manager"
   
   - 验证 `deck_list` → `study_session` 完整流程

六、跨层调用流程示例

### 6.1 创建 Note + 自动生成 Card（典型写流程）

```text
UI 层 (note_editor)
    │  用户点击"保存"
    ▼
调用 NoteManager.create_note(fields, deck_id)
    │
    ├─ 开启事务 (run_in_transaction)
    │
    ├─→ note_db.create_note(...) ──→ SQLite INSERT
    │       return NoteEntity (id=101)
    │
    ├─→ _generate_cards_for_note(101, deck_id, note_type_id)
    │       return [CardEntity(template_order=0)]
    │
    ├─→ card_db.create_card(note_id=101, deck_id=1, ...) ──→ SQLite INSERT
    │       return CardEntity (id=201)
    │
    ├─ 提交事务
    │
    ├─ emit entity_created("note", 101)
    ├─ emit entity_created("card", 201)
    │
    ▼
return ok({note: NoteEntity, cards: [CardEntity]})
    │
    ▼
UI 层收到成功结果 → 刷新列表
```

### 6.2 学习流程（典型读-算-写流程）

```text
UI 层 (study_session)
    │  用户选择 Deck，点击"开始学习"
    ▼
调用 StudyManager.start_session(deck_id)
    │
    ├─→ CardManager.get_study_queue(deck_id)
    │       ├─→ card_db.get_due_cards(deck_id, NEW)
    │       ├─→ card_db.get_due_cards(deck_id, LEARNING)
    │       └─→ card_db.get_due_cards(deck_id, REVIEW)
    │   return {new:[], learning:[], review:[]}
    │
    ├─ 组装 _current_queue
    ├─ emit session_started
    ▼
return ok({counts: {...}})
    │
    ▼
UI 展示第一张卡片（正面）
    │  用户点击"显示答案"
    ▼
调用 StudyManager.show_answer()
    ├─ emit card_shown(card, is_back=true)
    ▼
UI 展示背面 + 四个评分按钮
    │  用户点击"Good"
    ▼
调用 StudyManager.answer(Rating.GOOD)
    │
    ├─ 计算 time_taken_ms
    │
    ├─→ CardManager.answer_card(card_id, GOOD, time_taken_ms)
    │       │
    │       ├─→ card_db.get_card_by_id(card_id) → CardEntity
    │       │
    │       ├─→ scheduler.calculate_next_state(card, GOOD, now)
    │       │       【纯计算，无 I/O】
    │       │       return {queue:2, due:186, reps:5, ...}
    │       │
    │       ├─→ 更新 CardEntity 字段
    │       │
    │       ├─→ card_db.record_review(card_id, GOOD, time_taken_ms,
    │       │                        186, 2, 5, 0, 3.2, 5.1, "[...]")
    │       │       【单条 UPDATE/INSERT】
    │       │
    │       ├─ emit entity_updated("card", card_id)
    │       │
    │       ▼
    │   return ok({card: CardEntity, interval_days: 4})
    │
    ├─ 队列出队/重排
    ├─ emit card_answered + queue_updated
    ├─ 自动获取下一张 → get_current_card()
    ▼
return ok({next_card: CardEntity, counts: {...}, interval: "4天后"})
    │
    ▼
UI 展示下一张卡片（或"学习完成"界面）
```

---

## 七、当前缺口与需求汇报

### 7.1 DBManager 基类需补充

| 方法                            | 用途                                       | 优先级    |
| ----------------------------- | ---------------------------------------- | ------ |
| `last_insert_rowid()`         | INSERT 后获取自增 ID（创建 deck/note/card 后立即使用） | **P0** |
| `table_exists(table_name)`    | 数据库迁移/兼容性检查                              | P1     |
| `count(table, where, params)` | 快速统计行数                                   | P1     |

### 7.2 *_db 子类当前状态

| 子类           | 当前状态                      | 需实现方法数 |
| ------------ | ------------------------- | ------ |
| `deck_db.gd` | 空壳（仅 `extends DBManager`） | 约 10 个 |
| `note_db.gd` | 空壳                        | 约 10 个 |
| `card_db.gd` | 空壳                        | 约 15 个 |

### 7.3 新增文件清单

| 文件路径                                         | 层级  | 说明            |
| -------------------------------------------- | --- | ------------- |
| `res://src/entities/deck_entity.gd`          | 实体层 | 纯数据，新文件       |
| `res://src/entities/note_entity.gd`          | 实体层 | 纯数据，新文件       |
| `res://src/entities/card_entity.gd`          | 实体层 | 纯数据，新文件       |
| `res://src/entities/study_session_entity.gd` | 实体层 | 纯数据，新文件       |
| `res://src/scheduler/scheduler.gd`           | 调度层 | 抽象基类，新文件      |
| `res://src/scheduler/simple_scheduler.gd`    | 调度层 | SM-2 简化实现，新文件 |
| `scenes/Data Access/deck_db.gd`              | 数据层 | 在现有空壳上填充      |
| `scenes/Data Access/note_db.gd`              | 数据层 | 在现有空壳上填充      |
| `scenes/Data Access/card_db.gd`              | 数据层 | 在现有空壳上填充      |
| `scenes/Business Logic/deck_manager.gd`      | 逻辑层 | 在现有空壳上填充      |
| `scenes/Business Logic/note_manager.gd`      | 逻辑层 | 在现有空壳上填充      |
| `scenes/Business Logic/card_manager.gd`      | 逻辑层 | 在现有空壳上填充      |
| `scenes/Business Logic/study_manager.gd`     | 逻辑层 | 在现有空壳上填充      |

### 7.4 Schema 待确认项

1. **notes 表无外键到 decks**：当前 notes → cards → decks 是间接关联。若 note 直接属于 deck，建议加 `deck_id` 到 notes 表；否则删除 deck 时 notes 会成孤儿。
2. **缺少 `note_types` 表**：当前 `note_type_id` 无对应表，需确认是硬编码 ID 还是预留未来表。
3. **缺少 `review_logs` 独立表**：当前复习历史存在 `cards.review_history_json` 中。长期建议拆分为独立表，便于统计查询。
