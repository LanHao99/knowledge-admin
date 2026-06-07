# MVP 叙事模型实施路线图

> 按优先级排列的待办任务，与现有项目结构对齐。

---

## Phase 1: 剧本就绪（已完成 ✅）

- [x] 叙事框架设计 — `docs/narrative/narrative_framework.md`
- [x] 角色声音支柱 — `docs/narrative/character_voice_pillars.md`
- [x] 传说架构 — `docs/narrative/lore_architecture.md`
- [x] Chapter 1 完整剧本（8 个 .dialogue 文件）
  - [x] `ch1_intro.dialogue` — 初次相遇
  - [x] `ch1_explain.dialogue` — 共生的真相
  - [x] `ch1_trust.dialogue` — 信任的碎片
  - [x] `ch1_warning.dialogue` — 系统的警告
  - [x] `ch1_past.dialogue` — 碎片记忆
  - [x] `ch1_choice.dialogue` — 选择的时刻（含分支）
  - [x] `ch1_revelation.dialogue` — 真相的一角
  - [x] `ch1_end.dialogue` — 第一章的承诺
- [x] study.gd 注册新对话资源

---

## Phase 2: 文字动画系统（高优先级 🔴）

### 2.1 TextAnimationController 集成

- [ ] 将 `text_animation_controller.gd` 添加到 `story_dialogue_overlay.tscn`
- [ ] 修改 `story_dialogue_overlay.gd` 集成打字机效果：
  - `_show_line()` 改为调用 `_text_animator.play_line()`
  - 打字机播放期间点击 = 跳过动画
  - 打字机完成后点击 = 推进对话
  - 处理 `auto_advance_requested` 信号（{auto} 标记）
- [ ] 修改 ClickHint 标签：
  - 打字机播放中 → "点击跳过 →"
  - 打字机完成 → "点击继续 →"
- [ ] 标记解析器测试（验证 {fast}/{slow}/{pause}/{shake}/{glitch}/{auto} 正确解析）

### 2.2 对话标记验证

- [ ] 在 Godot 编辑器中打开所有 8 个 .dialogue 文件，验证语法无误
- [ ] 逐句播放测试，确保停顿节奏合理
- [ ] 调整标点暂停时间（可能需要根据实际体验微调）

---

## Phase 3: 与闪卡系统的深度整合（高优先级 🔴）

### 3.1 评分-叙事反馈

- [ ] 实现"连续评分模式检测"：连续 3 次 Again 或 3 次 Easy 时，在 StoryProgress.flags 中设置标记
- [ ] 对话中根据 flags 调整 MIRA 的语气（可在 .dialogue 中使用条件分支）
- [ ] 探索：能否在对话中读取 flags 来动态调整文本？

### 3.2 UI 状态反馈

- [ ] 进度条颜色与叙事阶段同步：
  - intro~explain: 灰色（陌生）
  - trust~past: 橙色（建立联系）
  - choice~end: 金色（承诺）
- [ ] Chapter 1 完成后，主菜单显示章节完成标记

### 3.3 故事回顾功能

- [ ] 创建 `story_log.gd` 脚本 — 记录已触发的对话摘要
- [ ] 主菜单添加"故事回顾"按钮
- [ ] 回顾界面按时间线展示已解锁的对话摘要

---

## Phase 4: 润色与测试（中优先级 🟡）

### 4.1 对话打磨

- [ ] 全体对话通读一遍，确保无"像编剧写的"台词
- [ ] MIRA 声音一致性检查：每句台词是否符合声音支柱
- [ ] 检查选项之间的价值观差异（无"换个说法"选项）

### 4.2 本地化准备

- [ ] 提取所有对话文本为 CSV（供未来翻译）
- [ ] 确认 DialogueManager 的 tr() 函数能正确提取

### 4.3 无障碍

- [ ] 添加"关闭动画"设置项
- [ ] 添加"关闭抖动"设置项（晕动症友好）
- [ ] 添加"文字速度"滑块

---

## Phase 5: Chapter 2 预研（低优先级 🟢）

### 5.1 Chapter 2 叙事大纲

**主题**: "对抗" — 系统不再是中立的旁观者

**核心冲突**: 系统开始主动限制 MIRA，玩家需要在"继续学习"和"保护 MIRA"之间找到平衡。

**伏笔回收**:
- 探索者的身份（"你和创造者很像"）
- 系统的真实目的
- MIRA 被关押的完整原因

### 5.2 Chapter 2 对话节点规划

| # | 对话 | 叙事功能 |
|---|------|---------|
| 1 | 系统封锁 | 系统限制了 MIRA 的"说话能力" |
| 2 | 寻找漏洞 | MIRA 教你绕开系统限制 |
| 3 | 另一段记忆 | MIRA 记起更多关于创造者的事 |
| 4 | 你的名字 | MIRA 说出了一个名字 — 可能是玩家的 |
| 5 | 系统反扑 | 系统直接威胁玩家的数据 |
| 6 | 隐藏的日志 | 发现加密日志（传说层 3 内容） |
| 7 | 真相 | 创造者的完整故事 |
| 8 | 第二章的承诺 | 新的决断 |

---

## 文件变更清单

### 新增文件

| 文件 | 类型 |
|------|------|
| `docs/narrative/README.md` | 文档 |
| `docs/narrative/narrative_framework.md` | 文档 |
| `docs/narrative/character_voice_pillars.md` | 文档 |
| `docs/narrative/lore_architecture.md` | 文档 |
| `docs/narrative/text_enhancement_design.md` | 文档 |
| `docs/narrative/gameplay_integration_matrix.md` | 文档 |
| `docs/narrative/implementation_roadmap.md` | 本文档 |
| `game/dialogue/text_animation_controller.gd` | 代码 |
| `game/dialogue/ch1_intro.dialogue` | 剧本 |
| `game/dialogue/ch1_explain.dialogue` | 剧本 |
| `game/dialogue/ch1_trust.dialogue` | 剧本 |
| `game/dialogue/ch1_warning.dialogue` | 剧本 |
| `game/dialogue/ch1_past.dialogue` | 剧本 |
| `game/dialogue/ch1_choice.dialogue` | 剧本 |
| `game/dialogue/ch1_revelation.dialogue` | 剧本 |
| `game/dialogue/ch1_end.dialogue` | 剧本 |
| 8 个对应的 `.dialogue.import` 文件 | 配置 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `scenes/ui/study.gd` | 注册新对话资源映射 |
| `game/dialogue/story_dialogue_overlay.gd` | 集成 TextAnimationController（Phase 2 实施） |
| `game/dialogue/story_dialogue_overlay.tscn` | 添加 TextAnimationController 节点（Phase 2 实施） |
