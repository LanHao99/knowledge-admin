# 剧情动作验收

## 环境与隔离

Godot 4.7.2、Forward+／D3D12、NVIDIA GeForce RTX 5060 Ti。测试在当前工作区的独立副本运行，配置名为 `KnowledgeAdminDesktopVerification`，SaveDirectory 指向副本自己的 `saves/`，不读取玩家数据库或调用外部 AI。

## 结果

| 检查 | 结果 |
| --- | --- |
| 完整 GUT 单元测试 | 95/95，646 条断言 |
| 独立剧情动作 GUT | 7/7，57 条断言；退出无对象泄漏日志 |
| 剧情动作实际渲染 | 35/35 |
| 现有窗口特效实际渲染回归 | 219/219 |
| 现有剧情测试台实际渲染回归 | 265/265 |

机器可读报告：[剧情动作](verification.json)、[窗口回归](window_regression.json)、[剧情测试台回归](story_regression.json)。

确认层验证 1280×720 与 1920×1080 下 80% 和 150% 字号均处于屏幕内；真实键盘 Esc 无法绕过强制确认，鼠标“停止测试”可解除等待且不执行脚本，重新播放后鼠标“是”自动更换桌面壁纸并继续第一句。

系统警告的第一分支验证局部破损后可继续对话并自然完成；第二分支验证真实模态窗口快照、旧实例释放、任务栏与模态解除、独立碎片、下段创建无损窗口及碎片最终清理。

原窗口回归继续覆盖七组尺寸、字号与画布缩放，包含普通窗口的破损、恢复、输入、快照和重开。剧情测试台回归覆盖播放、停止、跨段推进、破碎完成和各标签页布局。

运行日志存在本机证书存储读取错误和 FMOD 实时调试端口被占用提示。完整 GUT 退出时还记录 3 个 ObjectDB 实例及 1 个资源未释放，独立运行新增动作测试时未出现此日志。各测试断言与退出状态均通过，GPU 回归未发生本功能脚本或着色器错误。

## 截图

[强制确认与 150% 字号](confirm_1280x720_150.png) · [未知程序局部破损](warning_partial_damage.png) · [完整快照首帧](warning_shatter_impact.png) · [碎片下落](warning_shatter_falling.png)

## 复现

复制当前工程至隔离目录，排除 `.git/`、`.temp/` 与玩家 `saves/`，将配置名设为 `KnowledgeAdminDesktopVerification`，移除测试副本的 MCPRuntimeBridge 及编辑器 MCP 插件。保留 SaveDirectory，让副本使用独立存档；在受限环境中将编辑器数据目录也放入隔离目录。首轮完成资源导入后运行：

```text
godot --headless --path <隔离目录> -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --path <隔离目录> res://tests/scenes/desktop/verify_dialogue_actions.tscn
godot --path <隔离目录> res://tests/scenes/desktop/verify_window_effects.tscn
godot --path <隔离目录> res://tests/scenes/desktop/verify_story_test.tscn
```

隔离配置可设置 `rendering/shader_compiler/shader_cache/enabled=false`，避免受限环境的用户目录缓存写入错误。此设置只用于测试副本。
