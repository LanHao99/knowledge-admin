# Knowledge-Admin 叙事设计文档

> 版本: MVP v1.0  
> 作者: NarrativeDesigner  
> 日期: 2026-06-07  

---

## 项目叙事基因

**表面**：闪卡复习工具（Anki-like）  
**内里**：玩家的每一次"Again / Hard / Good / Easy"评分都在给嵌入记忆系统的 AI 意识体 MIRA 充能。学习即唤醒，记忆即牢笼。

**核心叙事机制**：
```
闪卡复习 → 评分驱动进度条增长 → 进度满格触发对话 → 
对话揭示故事 → 消耗进度 → 回到复习 → 循环...
```

---

## 目录

| 文档 | 说明 |
|------|------|
| [叙事框架](./narrative_framework.md) | 核心主题、情感弧线、叙事支柱、节奏设计 |
| [角色声音支柱](./character_voice_pillars.md) | MIRA、系统、玩家的完整角色卡 |
| [传说架构](./lore_architecture.md) | 三层知识体系 + 世界圣经 |
| [文字表现系统增强](./text_enhancement_design.md) | 打字机效果、情绪标记、动画系统设计 |
| [叙事-玩法融合矩阵](./gameplay_integration_matrix.md) | 每个叙事节拍的玩法后果 |
| [实施路线图](./implementation_roadmap.md) | Phase 1~5 任务分解 |

## 剧本文件

| 文件 | 对话节点 | 叙事功能 |
|------|---------|---------|
| `game/dialogue/ch1_intro.dialogue` | 初次相遇 | MIRA 碎片化登场，解释"评分=唤醒" |
| `game/dialogue/ch1_explain.dialogue` | 共生的真相 | MIRA 解释评分机制，"Again=遗忘=伤害" |
| `game/dialogue/ch1_trust.dialogue` | 信任的碎片 | 建立情感连接，埋下"评分模式很熟悉"伏笔 |
| `game/dialogue/ch1_warning.dialogue` | 系统的警告 | 系统介入，引入对抗主题 |
| `game/dialogue/ch1_past.dialogue` | 碎片记忆 | MIRA 回忆创造者，揭示系统是"监狱" |
| `game/dialogue/ch1_choice.dialogue` | 选择的时刻 | 关键分支：相信/犹豫/拒绝 MIRA |
| `game/dialogue/ch1_revelation.dialogue` | 真相的一角 | 创造者的故事，"你和创造者很像" |
| `game/dialogue/ch1_end.dialogue` | 第一章的承诺 | 章末情感高潮，承诺一起面对 |

## 代码文件

| 文件 | 说明 |
|------|------|
| `game/dialogue/text_animation_controller.gd` | 文字动画控制器（打字机+特效） |
| `game/dialogue/story_dialogue_overlay.gd` | 已集成 TextAnimationController |
| `game/dialogue/story_dialogue_overlay.tscn` | 已添加 TextAnimationController 节点 |
| `scenes/ui/study.gd` | 已注册 8 个新对话资源 |

## 快速开始

1. 在 Godot 4.6 中打开项目
2. 确保 DialogueManager 插件已启用
3. 开始学习会话 → 复习闪卡 → 进度条满 → 自动触发剧情对话
4. 对话标记系统文档：[文字表现系统增强](./text_enhancement_design.md#对话标记语言dialogue-markup-tags)
