# 学习快捷键

学习中的翻面、评分和退出可以改键。鼠标点击保持可用。快捷键只作用于当前这局闪卡，不关闭桌面窗口，也不写入笔记原文。

## 默认绑定

| 动作 | 标识 | 默认键 | 生效时机 | 行为 |
|---|---|---|---|---|
| 翻面 | `flip_card` | 空格 | 卡片正面 | 调用 `StudyManager.show_answer()` |
| 重来 | `rate_again` | `1` | 卡片背面 | 评分 `CardEntity.RATING_AGAIN` |
| 困难 | `rate_hard` | `2` | 卡片背面 | 评分 `CardEntity.RATING_HARD` |
| 良好 | `rate_good` | `3` | 卡片背面 | 评分 `CardEntity.RATING_GOOD` |
| 简单 | `rate_easy` | `4` | 卡片背面 | 评分 `CardEntity.RATING_EASY` |
| 退出学习 | `exit_study` | Esc | 学习中或完成统计 | 学习中等同「退出学习」；完成页等同「返回牌组列表」 |
| 保存文档 | `save_computer_document` | `Ctrl+S` | 我的电脑正在编辑文档 | 把当前文档写入 `user://my_computer_documents.cfg` |

数字键是主键区的 `1`–`4`，与小键盘分开。每个动作同时只有一个绑定。允许附加 Ctrl、Alt、Shift、Meta。

正面按评分键、背面按翻面键时吞掉按键，不评分、不翻面、不触发按钮。牌组选择页不拦截这些键，Esc 在这一页不退出应用。

## 何时不响应

以下情况把按键留给原来的界面：

- 当前活动窗口不是闪卡应用，或当前页不是学习场景。
- 剧情对话正在播放。对话仍用引擎的 `ui_cancel` 跳过打字，Esc 不结束学习。
- 开始菜单打开。Esc 先关掉菜单。
- 有可见的子弹窗，例如结束学习确认框。Esc 先关闭弹窗。
- 焦点在 `LineEdit` 或 `TextEdit` 上。这只拦住学习键。我的电脑正在编辑文档时，保存键仍然生效，否则无法在文本框里保存。

按住不重复。只认按下，不认松开。单独按修饰键不算绑定。

## 与引擎默认动作的关系

空格属于引擎的 `ui_accept`，Esc 属于 `ui_cancel`。学习快捷键不写入 `InputMap`，也不删掉这两项，避免菜单、对话框和对话跳过失效。

路由放在 `study.gd` 的 `_input`。学习窗口确实要响应时，先标记事件已处理，避免焦点停在评分按钮上时空格被当成再次点击。`CardUI` 只提供翻面和评分入口，`StudySession` 只提供退出和返回牌组列表入口。保存文档不走学习路由；`resolve_shortcut()` 会忽略它。我的电脑在自己的 `_input` 里处理，并且只在该窗口处于前台、没有开始菜单或确认框时生效。

## 界面提示

绑定变化后立即刷新文案：

- 翻面提示：有绑定时为「点击或按 空格 翻面」，未绑定时为「点击翻面」。
- 评分按钮：`重来  1`、`困难  2`、`良好  3`、`简单  4`。未绑定则只显示动作名。
- 退出按钮：`← 退出学习  Esc`。完成页不额外占键位提示。

显示名使用中文短名：空格、Esc、回车、小键盘数字。其余键用 `OS.get_keycode_string()`。修饰键写在前面，例如 `Ctrl+Shift+F`。

## 设置页

控制面板新增「快捷键」标签，放在「数据」和「关于」之间，样式沿用 Classic95。

每一行是动作名、生效说明、当前按键按钮。点击按钮后文字变为「请按键…」，同一时间只录一行。再点该按钮，或点另一行，取消录制且不改原绑定。

录制规则：

- 下一个有效按键写入该动作。Esc 可以录成退出键，不能拿来取消录制。
- Backspace 或 Delete 清除该动作的绑定。清除后只能用鼠标。
- 与其他动作冲突时不写入，状态栏写明被哪一项占用，原绑定保持不变。
- 「恢复默认快捷键」恢复上表七项并立即保存。

## 存档

Autoload：`ShortcutSettings`，脚本 `res://src/shortcut_settings.gd`，排在 `App` 之前。

文件：`user://shortcut_settings.cfg`，不要放进 `user://ui_settings.cfg`。字号保存会整文件重写，只保留字体倍率。

```
[bindings]
flip_card="Space"
rate_again="1"
rate_hard="2"
rate_good="3"
rate_easy="4"
exit_study="Escape"
save_computer_document="Ctrl+S"
```

空字符串表示未绑定。某一项缺失、无法解析、或与已成功读取的自定义键冲突时，只放弃这一项并回退默认；若默认键也被占用，则这一项保持未绑定。其余项保留。保存失败时内存中的新绑定仍然生效，设置页状态栏提示失败。

## 接口

| 方法 | 行为 |
|---|---|
| `get_binding(action)` | 返回键码与修饰键 |
| `get_display_text(action)` | 返回按钮和提示用的短名；未绑定返回空字符串 |
| `match_action(event)` | 命中时返回动作标识，否则返回空 `StringName` |
| `set_binding(action, event)` | 成功、冲突或无效。冲突时不修改 |
| `clear_binding(action)` | 解除绑定并保存 |
| `reset_defaults()` | 恢复七项默认并保存 |
| `bindings_changed` | 提示和设置按钮刷新 |
| `settings_save_failed(error)` | 保存失败 |

`CardUI` 增加 `request_flip()`、`request_rating(rating)`、`refresh_shortcut_hints()`。`StudySession` 增加 `request_exit()`、`request_back_to_picker()`，内部走现有退出和完成返回路径。

## 验证

`tests/unit/test_shortcut_settings.gd` 覆盖默认值、改键、冲突拒绝、清除、损坏配置回退，以及正面不评分、背面不翻面的匹配结果。场景测试确认对话打开、开始菜单和确认框期间不退出学习。
