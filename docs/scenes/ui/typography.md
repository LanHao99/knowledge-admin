# 全局字号与桌面主题

## 视觉来源

主界面和设置页以 `godot-desktop-themes-master` 的 Classic95 示范界面为参考。
窗体、按钮、标签页、白色凹陷面板、滚动条和禁用状态使用原始纹理，标题栏通过 AtlasTexture 引用原始窗口纹理中的蓝色渐变。

原始纹理位于 `assets/desktop_themes/Classic95/Styles/`，来源和许可证见该目录上级的 README 与 LICENSE。
布局使用可编辑的 `.tscn` 节点；主题基准位于 `assets/UI/app_theme.tres`。

悬浮提示使用不透明浅黄底和黑字，不沿用工具窗口纹理或引擎默认的半透明面板。树项目悬浮时文字保持黑色；已选中项维持蓝底白字。只读 `TextEdit` 使用 `font_readonly_color`，颜色为不透明深灰。

## 字号规则

保留 `ChillBitmap_16px.ttf`。设置页提供一个全局倍率：80%–150%，每次调整 5%，默认 100%。
像素字体按整数像素渲染，倍率计算统一使用四舍五入。

| 语义类型 | 100% 字号 | 用途 |
|---|---:|---|
| UiCaption / UiMuted | 20 | 辅助说明与状态 |
| UiBody、默认控件 | 24 | 标签、按钮、输入框、列表与树 |
| UiHeading | 28 | 小节标题 |
| UiTitle | 32 | 页面标题与字号预览 |
| UiMetric | 40 | 可选强调数字 |
| UiWindowTitle | 24 | 桌面窗体标题 |
| UiCardText | 32 | 卡片正文 |
| UiDialogueText | 28 | 剧情与教程正文 |

Classic95 主菜单的统计采用普通正文大小，与参考项目的紧凑桌面布局保持一致。
粗体、斜体、粗斜体与等宽富文本字号一起换算。

## 运行时管理

`UiSettings` 为 Autoload，应排在 `App` 之前。
服务还会检查已经进入场景树的主题边界，保证常驻剧情层在自动加载顺序变化时仍能接入。

| 接口 | 行为 |
|---|---|
| `font_scale` | 当前全局倍率 |
| `set_font_scale(value)` | 立即应用倍率并延迟保存 |
| `reset_font_scale()` | 恢复 100% |
| `font_scale_changed(scale)` | 同步设置控件 |
| `apply_theme(target)` | 将共享主题应用到 Control 或 Window |
| `set_rich_text(label, source)` | 保存未缩放来源，刷新显式 BBCode 字号 |
| `settings_save_failed(error)` | 保存失败反馈 |

所有场景引用应用主题后，在进入树时被替换为同一份运行时副本。
新弹窗也接入共享主题；动态创建的控件通过继承与 `theme_type_variation` 获取字号。
每次调整从基准主题计算，不使用上一次渲染字号作为输入。

窗口标题变大时，仅在运行时伸展原始标题纹理，源 StyleBox 与缓存 Image 均复制后处理。
原始 PNG、原始基准主题不被修改。

## 内容和存档

配置位于 `user://ui_settings.cfg` 的 `[appearance]` 段，键名 `font_scale`。
停止调整 0.3 秒后保存；退出时保存尚未写入的设置。
缺失、损坏或类型错误的配置回退到 100%；数值越界时限制到有效范围。
保存失败时维持当前显示效果，并在设置页提示。

卡片和对话的未缩放文本由显示层缓存，显式 `[font_size]` 标签只在展示时换算。
刷新字体保留可见字符数和滚动位置，不重启打字机 Tween，也不修改笔记或剧情原文。
正文通过滚动适配空间，评分和对话选项可换行。

## 验证

- Godot 4.7.2；GUT 14 个测试、89 个断言通过。
- GPU 渲染验证覆盖 1280×720、1920×1080，以及 80%、100%、150% 字号。
- 269 项布局、导航、动态控件、存档、长文本滚动、左键传递及打字机检查通过。
- 统计失败注入验证“—”占位符和错误状态，不把读取失败呈现为零。
- 验证工程使用独立的 `KnowledgeAdminUiVerification` 存档，不写入正式玩家存档。

截图与检查结果保存在 [review](review/)。
