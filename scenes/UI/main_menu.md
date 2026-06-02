# main_menu (MainMenu) — UI 设计方案

> **路径**: `res://scenes/ui/main_menu.gd` / `main_menu.tscn`
> **继承**: `Control`（建议从 Node2D 迁移为 Control）
> **类型**: UI 层 — 程序入口场景
> **状态**: 设计中（待实现）

---

## 一、功能定位

作为知识管理工具的程序入口界面，提供：

1. **核心导航**：跳转到牌组管理、笔记浏览、开始学习三个主要场景
2. **概览看板**：展示牌组总数、待复习卡片数、今日学习进度
3. **快速入口**：一键进入第一个未完成学习的牌组
4. **调试入口**：开发阶段保留调试面板的快捷跳转

参考 Anki 桌面版主界面：简洁的牌组列表 + 顶部工具栏 + 底部状态栏。

---

## 二、界面布局

```
┌─────────────────────────────────────────────────────────┐
│  Knowledge Admin                         [设置][调试]  │ ← TopBar
├─────────────────────────────────────────────────────────┤
│                                                         │
│            ┌─────────────────────────┐                  │
│            │    📚 Knowledge Admin   │                  │
│            │                        │                  │
│            │   牌组: 5  待复习: 23  │                  │
│            │   今日已学: 12 张卡片   │                  │
│            │                        │                  │
│            │  ┌──────────────────┐  │                  │
│            │  │   📖 牌组管理     │  │                  │
│            │  └──────────────────┘  │                  │
│            │  ┌──────────────────┐  │                  │
│            │  │   📝 笔记浏览     │  │                  │
│            │  └──────────────────┘  │                  │
│            │  ┌──────────────────┐  │                  │
│            │  │   ▶  开始学习     │  │  ← 高亮主按钮   │
│            │  └──────────────────┘  │                  │
│            └─────────────────────────┘                  │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  v1.0.0 | Godot 4.6 | DeepSeek V4 Pro                   │ ← BottomBar
└─────────────────────────────────────────────────────────┘
```

---

## 三、节点树设计

```text
MainMenu (Control)
├── TopBar (HBoxContainer)
│   ├── AppTitle (Label, "Knowledge Admin")
│   ├── Spacer (Control, size_flags_horizontal=EXPAND)
│   ├── SettingsButton (Button, "⚙ 设置")
│   └── DebugButton (Button, "🔧 调试")     ← 开发阶段保留
│
├── CenterContainer (CenterContainer)
│   └── MainCard (PanelContainer)
│       └── CardVBox (VBoxContainer, separation=16)
│           ├── LogoLabel (Label, "📚 Knowledge Admin")
│           ├── StatsGrid (GridContainer, columns=3)
│           │   ├── DeckCountLabel (Label, "牌组")
│           │   ├── ReviewCountLabel (Label, "待复习")
│           │   └── TodayCountLabel (Label, "今日已学")
│           ├── Separator1 (HSeparator)
│           ├── DeckListButton (Button, "📖 牌组管理")
│           ├── NoteBrowseButton (Button, "📝 笔记浏览")
│           ├── StudyButton (Button, "▶ 开始学习")   ← 主按钮，强调样式
│           └── Separator2 (HSeparator)
│
├── BottomBar (HBoxContainer)
│   ├── VersionLabel (Label, "v1.0.0")
│   ├── Spacer (Control)
│   └── StatusLabel (Label, "数据库就绪 ✓")
│
└── 脚本: main_menu.gd
```

---

## 四、全局依赖

main_menu 通过 `App` Autoload 单例访问 Manager：

```gdscript
# 在 _ready 或按钮回调中：
@onready var _deck_mgr: DeckManager = App.get_deck_manager()
@onready var _note_mgr: NoteManager = App.get_note_manager()
@onready var _study_mgr: StudyManager = App.get_study_manager()
```

**前提**：`res://src/app.gd` 需在 `project.godot` 中注册为 Autoload（当前可能尚未注册），并暴露 `get_deck_manager()` / `get_note_manager()` / `get_study_manager()` 等公共方法。

---

## 五、按钮行为规格

| 按钮 | 点击行为 | 状态检查 | 失败处理 |
|------|---------|---------|---------|
| **牌组管理** | `change_scene_to_file("res://scenes/ui/deck_list.tscn")` | App 已就绪 | Toast 提示 |
| **笔记浏览** | `change_scene_to_file("res://scenes/ui/note_list.tscn")` | App 已就绪 | Toast 提示 |
| **开始学习** | `change_scene_to_file("res://scenes/ui/study_session.tscn")` | 存在待复习卡片 | "无待复习卡片"提示 |
| **设置** | 弹出 Popup/Dialog，或跳转设置场景 | — | — |
| **调试** | `change_scene_to_file("res://scenes/ui/debug_crud_panel.tscn")` | — | — |

---

## 六、统计面板数据源

| 指标 | 数据来源 | 获取方式 |
|------|---------|---------|
| 牌组数 | `DeckManager.get_all_decks()` | `result.data.size()` |
| 待复习 | `StudyManager.get_due_count()`（待实现） | 查询 cards 表中 `due_date <= now` 且 `status != 'suspended'` 的记录数 |
| 今日已学 | `StudyManager.get_today_studied_count()`（待实现） | 查询 `review_logs` 表中 `reviewed_at` 为今天的记录数 |

> **注**：统计面板在 Manager 层对应方法未就绪时，应降级显示 "—" 或隐藏，不阻塞主菜单加载。

---

## 七、初始化流程

```
main_menu._ready()
    │
    ├── 1. 等待 App Autoload 就绪（signal: App.ready 或轮询）
    │       ├── 如果 App 未就绪：显示"正在初始化…"遮罩
    │       └── 如果 5 秒超时：显示"初始化失败，请重启" + 退出按钮
    │
    ├── 2. 加载统计面板数据（可选降级）
    │       ├── 牌组数：始终可从 DeckManager 获取
    │       ├── 待复习数：StudyManager 未实现时显示 "—"
    │       └── 今日已学：同上
    │
    ├── 3. 连接刷新信号
    │       └── App.data_changed.connect(_refresh_stats)（待 App 实现）
    │
    └── 4. 更新底部状态栏为 "就绪"
```

---

## 八、样式规范

| 元素 | 字体 | 字号 | 颜色/备注 |
|------|------|------|----------|
| AppTitle | ark-pixel 粗体 | 24px | 主标题色 |
| 按钮文字 | ark-pixel 常规 | 16px | — |
| 统计数字 | ark-pixel 粗体 | 20px | 强调色 |
| 统计标签 | ark-pixel 常规 | 12px | 次要文字色 |
| 底部状态 | ark-pixel 常规 | 10px | 半透明 |

使用项目已有字体：
- `res://assets/fonts/ark-pixel-16px-proportional-zh_cn.ttf`（中文）
- `res://assets/fonts/ark-pixel-16px-proportional-latin.ttf`（拉丁）

---

## 九、与 Anki 的对应关系

| Anki 主界面 | Knowledge Admin 对应 | 说明 |
|-------------|---------------------|------|
| 牌组列表（左侧树） | "牌组管理"按钮 → deck_list 场景 | deck_list 内含多层级牌组树 |
| 顶部工具栏 | TopBar | 简化版，保留设置和调试 |
| "立即学习"按钮 | "开始学习"按钮（高亮） | 核心 CTA |
| 统计面板 | StatsGrid（简化版） | 仅显示三个核心指标 |
| 底部状态栏 | BottomBar | 显示版本和数据库状态 |

---

## 十、实现阶段划分

| 阶段 | 内容 | 预估工作量 |
|------|------|----------|
| **Phase 1** | 基础布局 + 三个导航按钮 + 调试入口 | 核心骨架 |
| **Phase 2** | 统计面板数据接入（牌组数 + 待复习 + 今日已学） | 依赖 StudyManager |
| **Phase 3** | 设置弹窗 / 主题切换 | 可延后 |
| **Phase 4** | 动画过渡 + 音效反馈 | 润色阶段 |

---

## 十一、注意事项

1. **根节点类型**：建议从 `Node2D` 改为 `Control`，以便使用 anchor/margin 做自适应布局
2. **场景导出**：必须在 `project.godot` 中将 `run/main_scene` 指向 `main_menu.tscn`
3. **App Autoload 就绪检查**：所有按钮点击前需确保 App 单例已完成数据库初始化，否则会崩溃
4. **调试按钮**：在正式发布前应从 UI 中移除或改为隐藏（通过 project settings 控制可见性）
5. **"开始学习"的牌组选择**：当前先简单进入 study_session；后续可先弹出牌组选择 Dialog 再跳转
