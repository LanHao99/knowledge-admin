# Learnings

Corrections, insights, and knowledge gaps captured during development.

**Categories**: correction | insight | knowledge_gap | best_practice

---

## [LRN-20260603-001] best_practice

**Logged**: 2026-06-03T09:30:00+08:00
**Priority**: high
**Status**: pending
**Area**: config

### Summary
Agent-Skill-Reference 三层架构设计 —— GodotPrompter 多 agent 方案核心模式

### Details
从 jame581/GodotPrompter 学习到的多 agent 协作方案：
- **Agent 层**: YAML frontmatter (description + 触发条件 + 路由规则) + Markdown 系统提示
- **Skill 层**: 每个 SKILL.md ≤ 16KB (~4K tokens)，包含 canonical recipe + distinguishing choices + anti-patterns
- **Reference 层**: 按需加载的详细文档，无大小限制
- **Token 预算**: 典型 agent 调用（agent + 主 skill + 1-3 交叉引用）≈ 20-25K tokens
- **协作流程**: 架构师设计 → 实现者编码 → 审查者审查，各 agent 通过显式路由互相委托
- **Distinguishing Choices**: 每个 skill 嵌入"何时选 A 而非 B"的决策矩阵

### Suggested Action
knowledge-admin 项目已采用此模式：将 skill 升级为 agent（.opencode/agents/），每个 agent 声明 skills 依赖，通过 agent_open 子进程运行隔离上下文。

### Metadata
- Source: conversation
- Related Files: .opencode/agents/*.md
- Tags: architecture, multi-agent, godot, skill-design

---

## [LRN-20260603-002] best_practice

**Logged**: 2026-06-03T09:30:00+08:00
**Priority**: medium
**Status**: pending
**Area**: frontend

### Summary
运行时 theme_override 应迁移到 .tscn 编辑器属性，使 WYSIWYG

### Details
main_menu.gd 中的 `_setup_panel_style()` 和 `_apply_bbcode_overrides()` 在运行时用代码设置 custom_minimum_size、font_color、StyleBoxFlat。这导致编辑器预览与实际运行时不一致（MainCard 过窄）。
解决方案：将所有样式覆盖迁移到 .tscn 节点属性和 sub_resource 块中：
- custom_minimum_size → 节点属性
- theme_override_colors/font_color → 节点属性
- StyleBoxFlat → [sub_resource] 块 + theme_override_styles/panel 引用
迁移后删除了 2 个函数，净减少 44 行代码。

### Suggested Action
新增 UI 节点样式时，优先在 .tscn 编辑器中设置，不要写 `add_theme_*_override()` 代码。

### Metadata
- Source: user_feedback
- Related Files: scenes/ui/main_menu.gd, scenes/ui/main_menu.tscn
- Tags: godot-ui, theme, tscn, wysiwyg

---

## [LRN-20260603-003] insight

**Logged**: 2026-06-03T09:30:00+08:00
**Priority**: medium
**Status**: pending
**Area**: config

### Summary
融合审查视角到设计和实现 agent，形成"设计→实现→审查"质量闭环

### Details
将 code-reviewer 的架构审查视角融合到 godot-game-architect（前置质量把关）和 godot-ui-designer（实现后自查清单）。三个 agent 形成的闭环：
- godot-game-architect: 设计方案中包含"架构审查"检查表
- godot-ui-designer: 实现完成后运行"代码质量自查"
- code-reviewer: 交付后多角色独立审查

### Suggested Action
未来新增 agent 时，考虑它们如何融入现有的质量闭环。

### Metadata
- Source: conversation
- Related Files: .opencode/agents/godot-game-architect.md, .opencode/agents/godot-ui-designer.md, .opencode/agents/code-reviewer.md
- Tags: architecture, quality, agent-design

---

## [LRN-20260603-004] best_practice

**Logged**: 2026-06-03T09:30:00+08:00
**Priority**: high
**Status**: pending
**Area**: config

### Summary
子 agent 结果是自报告，必须用工具独立验证

### Details
agent_open 启动的子 agent 返回的结果是自报告（self-report）。必须在信赖之前用 read_file 读取实际文件、用 git_diff 检查变更、用 agent_eval 获取最新状态。本次 ui-mainmenu-fix agent 完成后通过 read_file 验证了 main_menu.gd 和 main_menu.tscn 的实际内容。

### Suggested Action
子 agent 完成后永远执行验证步骤 —— Constitution Article V 强制要求。

### Metadata
- Source: conversation
- Related Files: scenes/ui/main_menu.gd, scenes/ui/main_menu.tscn
- Tags: verification, sub-agent, reliability

---

## [LRN-20260603-005] knowledge_gap

**Logged**: 2026-06-03T12:00:00+08:00
**Priority**: high
**Status**: pending
**Area**: backend

### Summary
NoteEntity 缺少 deck_id 字段 —— Entity 类必须与数据库 schema 严格同步

### Details
在实现 note_list 按牌组分组功能时，发现 NoteEntity 没有 deck_id 字段，但 notes 表明确有 deck_id 列。这是因为 Entity 创建时只映射了部分字段。GDScript 的 Dictionary.has() 不会报错——`from_dict()` 悄悄跳过了未处理的键。教训：Entity 的 to_dict/from_dict 必须覆盖数据表的所有列，否则查询出的数据会静默丢失。

### Suggested Action
每次修改数据库 schema 后，检查对应 Entity 的 to_dict() 和 from_dict() 是否覆盖了所有列。可以在 Entity 的 from_dict() 中添加未知键的 push_warning 来检测遗漏。

### Metadata
- Source: conversation
- Related Files: src/entities/note_entity.gd, data/数据结构.md
- Tags: entity, schema-sync, data-integrity

---

## [LRN-20260603-006] best_practice

**Logged**: 2026-06-03T12:00:00+08:00
**Priority**: medium
**Status**: pending
**Area**: frontend

### Summary
UI 场景独立创建 Manager 实例而非依赖 Autoload —— 降级方案

### Details
项目中 Autoload（app.gd）尚未实现，note_list 模仿 debug_crud_panel 的模式：每个 UI 场景在 _ready() 中创建自己的 NoteManager/DeckManager 实例（new + add_child + setup），在 _exit_tree() 中释放。这确保了场景独立、可测试。代价是每个场景有独立数据库连接。未来若实现 Autoload，应统一通过 App 单例获取 Manager。

### Suggested Action
实现 Autoload 系统后，将所有 UI 场景的 Manager 创建改为通过 App.get_*_manager() 获取。

### Metadata
- Source: conversation
- Related Files: scenes/ui/note_list.gd, scenes/ui/debug_crud_panel.gd
- Tags: architecture, autoload, manager, dependency-injection

---

## [LRN-20260603-007] best_practice

**Logged**: 2026-06-03T14:00:00+08:00
**Priority**: medium
**Status**: pending
**Area**: backend

### Summary
跨牌组全局统计查询应放在 CardDB 层，用 scalar() 做 COUNT 聚合，避免在 UI 层逐牌组累加

### Details
main_menu Phase 2 需要三个全局统计：牌组数、待复习数、今日已学数。待复习和今日已学没有现成方法，需要在 CardDB 层新增 `get_global_due_count()` 和 `get_today_studied_count()`，使用 DBManager 已有的 `scalar()` 方法做 COUNT 聚合。CardManager 各加一个包装方法透传。保持了"数据访问在 DB 层、业务编排在 Manager 层、UI 只调 Manager"的分层约束。

### Suggested Action
后续需要跨实体聚合统计时，遵循同样的分层模式：先加 DB 层方法，再加 Manager 层包装。

### Metadata
- Source: conversation
- Related Files: scenes/data_access/card_db.gd, scenes/business_logic/card_manager.gd, scenes/ui/main_menu.gd
- Tags: stats, aggregation, sql, architecture

---

## [LRN-20260603-008] best_practice

**Logged**: 2026-06-03T21:30:00+08:00
**Priority**: critical
**Status**: done
**Area**: config

### Summary
UTF-8 BOM 导致 Godot 4.x class_name 全局注册失败 —— 级联编译错误

### Details
Windows 部分编辑器（记事本、VS Code 某些编码设置）保存 UTF-8 文件时默认附加 BOM (U+FEFF, `﻿`)。Godot 4.x GDScript 解析器将 BOM 视为非法字符，导致该文件的 `class_name` 无法注册。

本次事故中 4 个文件被 BOM 污染：
- `manager.gd`（基类 `Manager`）
- `db_manager.gd`（基类 `DBManager`）
- `card_manager.gd`（`CardManager`）
- `note_manager.gd`（`NoteManager`）

两个基类污染产生级联效应：所有 `extends Manager` 和 `extends DBManager` 的子类全部失效，导致 `card_ui.gd` 无法识别 `StudyManager`/`NoteManager`/`CardManager`。

修复：移除 4 个文件的 BOM 字节（`raw[3:]`）。

### Suggested Action
1. 优先用 Godot 内置编辑器编辑 `.gd` 文件
2. `.editorconfig` 中 `[*.gd]` 显式声明 `charset = utf-8` + `end_of_line = lf`
3. `.git/hooks/pre-commit` Python 脚本硬拦截 BOM 污染提交
4. 编译报错时排查级联依赖：基类失效 → 所有子类报错，根因在依赖链顶端

### Metadata
- Source: debugging
- Related Files: scenes/business_logic/manager.gd, scenes/data_access/db_manager.gd, scenes/ui/card_ui.gd
- Tags: bom, encoding, class_name, godot-parser, cascade-failure, git-hooks
