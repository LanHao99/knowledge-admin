# 窗口实验室

## 使用方式

从桌面双击“窗口实验室”，或在开始菜单单击启动。默认大小为 900×620，采用普通应用的单实例、拖动、缩放和任务栏行为。

应用提供三个按钮与可编辑文本：

| 操作 | 结果 |
| --- | --- |
| 完全破碎窗口 | 原应用先释放；完整快照猛烈震动约 0.18 秒，再切成约 80 块玻璃碎片，文字、按钮和边框一起旋转并向下加速，最终掉出屏幕。 |
| 不完全破损 | 整个窗口短促震动约 0.26 秒，标题栏、边框和内容共同出现稳定裂纹与轻微折射，仍能编辑文本、操作按钮、拖动及缩放。重复点击会重新施加冲击，但保持同一损伤。 |
| 恢复 | 清除裂纹和折射，保留输入内容、窗口位置与大小。 |

完全破碎只结束这个游戏内应用，桌面与其他应用继续运行。从桌面重新打开时创建无损的新实例，旧碎片的清理不会影响新窗口。局部损伤仅改变显示像素，保留控件原有布局与点击区域；恢复不会恢复已经完全破碎的旧实例。

单独运行 `window_lab.tscn` 只展示内容并提示从桌面启动，动作按钮禁用；整窗效果需要 ManagedWindow 宿主。

## 渲染与释放

局部破损由 ManagedWindow 最上方的 DamageOverlay 绘制。DamageCopy 在它之前复制屏幕，着色器把采样夹在目标窗口边界内，避免折射到其他窗口或桌面。材质按场景实例独立，未破损时覆盖层隐藏、复制关闭。

DamageCopy 使用 COPY_MODE_VIEWPORT。当前 Forward+ 渲染路径的矩形复制存在忽略节点变换的行为，局部矩形复制会在移动后留下未初始化黑色区域；全视口复制配合窗口边界采样夹限，经实际 GPU 验证可避免此问题。参见 [Godot 渲染实现](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp) 与 [屏幕读取着色器](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)。

完全破碎的顺序为：

- 接受请求时立即标记窗口关闭中，递归禁用业务处理，包括 PROCESS_MODE_ALWAYS 子节点，释放键盘焦点并遮挡输入。
- 将目标窗口临时置于碎片和普通窗口之上，等待 frame_post_draw，再从真实视口画面裁出完整窗口。剧情模态层仍位于其上方；被剧情遮挡时不生成错误快照。
- 在桌面 WindowEffects 层建立零进度的静止快照网格，移除注册和任务栏按钮，将原窗口移出场景树并 queue_free。静止快照避免等待释放时闪回桌面。
- 等待原窗口实际销毁，才启用碎片运动并发出 effect_started。运动阶段不含真实 UI 节点。
- 快照先以统一偏移猛烈震动，冲击阶段各三角形保持拼合。冲击结束后，每个三角形保留原纹理 UV，着色器绕各自中心旋转并叠加速度与重力。碎片不受原窗口边界裁剪，可经过任务栏，全部落出屏幕后释放。

碎裂请求按实例标识去重，旧回调不能关闭同 ID 的新实例。捕获期间禁止恢复、导航及重复关闭；捕获失败仍关闭旧应用，不遗留冻结窗口。正式剧情、帮助窗口、来源帮助锁、活动学习会话、导入写入和可见确认框均不能被特效接口绕过。

局部破损的震动直接移动整个 ManagedWindow，因此边框、UI 和输入区域一起移动。震动采用快速往返、平方衰减的波形，以整数逻辑像素偏移避免字体模糊；结束后精确回到原位置。恢复、开始拖动或缩放、最大化、最小化和关闭会先结束当前震动，布局记录始终使用原始坐标。完全破碎则在原实例释放后移动快照，不等待活应用播放震动。

## 可调整参数与接口

打开 `scenes/desktop/desktop.tscn`，选择 WindowEffects：

| 属性 | 默认值 | 含义 |
| --- | --- | --- |
| shard_grid | (8, 5) | 抖动网格经 Delaunay 剖分，默认生成 80 个三角碎片。 |
| gravity | 1800 | 向下加速度，单位为逻辑像素／秒²。 |
| horizontal_speed | 190 | 随机水平速度幅度。 |
| initial_lift | 130 | 碎裂开始时的短暂向上速度幅度。 |
| spin_speed | 3 | 随机角速度幅度，单位为弧度／秒。 |
| impact_amplitude | 24 | 完全破碎前的整窗震幅，单位为逻辑像素。 |
| impact_duration | 0.18 | 快照保持拼合并震动的秒数，之后才开始碎片运动。 |
| impact_frequency | 24 | 冲击频率，单位为 Hz。 |

局部破损的参数位于 `managed_window.tscn` 根节点的 Impact 分组：impact_amplitude 默认为 14，impact_duration 为 0.26 秒，impact_frequency 为 22 Hz。两种冲击的震幅、时长和频率分别可调；将震幅设为 0 可关闭对应震动。

在 `window_lab.tscn` 根节点调整 damage_strength，默认为 0.7。在 `managed_window.tscn` 的 DamageOverlay 材质中调整 cell_size、crack_width 和 refraction_pixels，控制裂纹分区、线宽与错位强度；damage 和 window_size 由运行时维护。

`WindowManager.set_app_damage(app_id: String, amount: float) -> bool` 设置损伤，0 表示恢复，有效数值限制在 0～1，非有限值拒绝。`WindowManager.shatter_app(app_id: String) -> bool` 请求完全破碎，返回是否接受请求。动画由桌面拥有，不需要应用页面等待异步完成。

## 验收

Godot 4.7.2、Forward+／D3D12 实际渲染：

- 窗口相关 GUT 共 27 项测试、216 条断言通过，覆盖注册、独立材质、损伤恢复、冻结、请求去重、业务保护、旧实例回调、网格面积与 UV，以及整窗震动、布局还原和先震动后碎裂的时序。
- 特效 GPU 验收 219 项检查通过，覆盖 1280×720、1920×1080 和 80%、100%、150% 字号，另测 1280×720 显示下的 1920×1080 逻辑画布。
- 每组额外检查标题栏与输入区同步震动、反向回弹、真实画面变化及结束归位；完全破碎检查原 UI 释放后快照仍能震动，且冲击结束前碎片不分离。
- 验证破损后输入与拖动、恢复保留内容和布局、完整与破损窗口碎裂、最大化后碎裂、首帧像素与快照一致、首帧运动前旧 UI 已释放、其他应用可用、动画期间重新打开及碎片清理。
- 现有完整桌面 GPU 回归 150 项检查通过，包括导航、窗口操作、导入、学习、剧情与帮助。

测试均在独立工程和存档目录运行，不使用玩家数据库或外部 AI 请求。测试机器输出一条系统证书存储读取错误，未发生本功能脚本或着色器错误，全部断言与退出状态通过。

证据保存在 [window_lab 验收目录](desktop_review/window_lab/verification.json)，其中有正常、破损、碎裂及重新打开的实际截图，以及桌面回归报告。

复现时复制当前工作区到隔离工程，保留最新资源与插件，将 application/config/name 设置为 KnowledgeAdminDesktopVerification，移除 MCPRuntimeBridge 和编辑器 MCP 插件，使用该工程自己的 saves 目录。运行 `tests/desktop/verify_window_effects.tscn` 执行 GPU 验收；原桌面回归使用 `tests/desktop/verify_desktop.tscn`。
