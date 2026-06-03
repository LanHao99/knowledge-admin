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
