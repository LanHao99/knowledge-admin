# 知识空间

## 体验与入口

从桌面双击「知识空间」，或在开始菜单启动。应用 ID 为 `knowledge_space`，默认大小 1100×740，最小 720×480，复用普通窗口的单实例、拖动、缩放、最大化与任务栏行为。

黑蓝色空间中，每份闪卡和剧情档案都是带标题栏的悬浮窗口。普通闪卡按来源牌组分群，分布在中央档案通道两侧。所有窗口保持平行，不跟随摄像头转动；近处和远处窗口的遮挡与透视形成空间纵深。已解锁的剧情档案使用琥珀色页面、明确的「档案」标识及轻微边框脉冲。未解锁页面不实例化，也不显示标题或占位信息。

首版不绘制引用线，不实现语义分析或自动引用，也不记录档案发现进度或发放收集奖励。知识结构通过牌组分群和来源标识呈现。

## 操作

| 操作 | 行为 |
| --- | --- |
| 按住右键 | 捕获鼠标并进入飞行；开始手动操作立即中断自动聚焦。 |
| 鼠标移动 | 调整摄像头朝向，俯仰有限制，不翻滚。 |
| WASD | 在摄像头前后左右移动。 |
| Q / E | 沿世界竖直方向下降、上升。 |
| Shift | 加速。 |
| 松开右键 / Esc | 退出飞行并释放鼠标。 |
| 单击页面 | 选择文档。 |
| 标题栏「−」 | 最小化为原位置的标题栏，隐藏正文并让出原来的正文区域。 |
| 标题栏「□」 | 全屏：若已折叠则展开，平滑回到正对该窗口的视角，让完整窗口入镜。 |
| 标题栏「×」 | 本次打开知识空间期间移除该窗口。 |
| 双击页面 / 聚焦 | 展开所选文档，平滑靠近正面，按视口比例让整页入镜。 |
| 阅读全文 | 打开窗口内的只读阅读层，保留完整问题和答案。 |
| 返回空间 / 阅读时 Esc | 关闭阅读层，保持摄像头位置。 |
| 回到入口 | 平滑回到初始视角。 |
| 刷新内容 | 重新读取最近创建的闪卡，不重置摄像头位置。 |

切换应用、最小化、剧情模态、系统失焦、父级暂停或禁用以及关闭窗口都会停止飞行和移动动画，并释放本窗口持有的鼠标。恢复窗口保留实例和视角。最小化期间关闭 3D 视口更新。独立运行 `knowledge_space.tscn` 也能浏览本地卡片。

每份文档的三个标题栏按钮都使用左键。关闭和折叠只影响当前知识空间实例；刷新内容、切换应用、外层窗口最小化及剧情进度更新都会保留这些状态。关闭整个「知识空间」再打开，文档恢复显示和展开；剧情档案仍须满足解锁条件。关闭不会删除卡片，折叠和全屏也不写入学习或剧情数据。标题栏操作优先于双击聚焦，避免关闭操作同时启动聚焦。

这里的全屏是将摄像头移到文档正前方，并按当前视图区大小完整取景。正文仍处于原来的 3D 位置，飞行操作可以随时中断自动移动。界面数量统计当前可见的文档窗口；全部关闭后提示重新打开知识空间恢复。

## Inspector 配置

打开 `content/data/desktop/knowledge_space.tres`，或在场景根节点展开 `configuration`。此资源集中保存文档规模、页面尺寸、配色、飞行速度和六份剧情档案。

| 属性 | 默认值 | 含义 |
| --- | --- | --- |
| card_limit | 24 | 最近创建的卡片数量，读取和显示均限制在 1～64。 |
| page_size | (7.2, 8.4) | 页面在 3D 中的尺寸；实际最小按 (4, 5) 处理。 |
| excerpt_length | 360 | 空间摘录字符上限；还会按字体换行后的实际高度缩短，全文不受影响。 |
| card_color / card_border | 灰蓝色 | 普通文档的背景与边框。 |
| archive_color / archive_border | 暗琥珀色 | 剧情档案的背景与边框。 |
| text_color / background_color | 浅灰 / 黑蓝 | 正文与空间背景。 |
| flight_speed | 9 | 每秒移动的世界距离。 |
| boost_multiplier | 3 | Shift 加速倍率。 |
| mouse_sensitivity | 0.0025 | 转向灵敏度。 |
| focus_duration | 0.65 | 聚焦或返回入口的移动时长，单位秒。 |
| entrance_position | (0, 3, 26) | 初始及返回入口时的摄像头位置。 |

`archives` 中的每个 `KnowledgeSpaceArchive` 包含 `archive_id`、`title`、多行 `content`、`spatial_position` 和 `required_story_record`。ID 必须非空且不重复。完成记录使用完整的 `chapter_1/intro` 形式；留空表示始终显示，不能用短剧情名替代。正文、位置和解锁条件均可在 Inspector 修改，不需要修改窗口脚本。

六份默认档案分别要求完成：第一章的初次相遇、共生解释、系统警告，以及第二章的世界真相、Xanaku 计划、木马真相。正文依据对应已揭示内容整理，不执行对话脚本。剧情档案拥有独立的预留位置，解锁不会重排闪卡文档。

场景根节点的 `database_path` 默认是 `user://knowledge_admin.db`，沿用项目现有 SaveDirectory。`auto_load_cards` 供隔离验证注入样本使用，正常场景保持开启。

## 数据与渲染

`NoteManager.get_spatial_documents(limit)` 调用 NoteDB 的限量 SELECT，关联卡片、笔记和牌组，只读取 ID、来源及字段文本。查询按卡片 ID 倒序取最近创建的记录，不读取复习历史；同组显示再按卡片 ID 排序。正反面与学习界面共用字段回退规则，兼容中英文正反面名称及自定义字段顺序。

普通页面以问题作为标题、答案作为空间摘录。阅读层包含完整问题与答案。BBCode 排版被转换为纯文本，普通方括号保留；图片以文字标识显示，不加载外部资源。此路径不调用 `App.present_card_text`，不发出卡片展示或评分事件，不改变调度或剧情进度。失败时保留已有文档与刷新按钮；空库给出提示，已解锁档案仍可探索。

剧情显隐只读取 `App.get_story_progress()`，监听 `App.story_state_changed`。已完成章节的同名剧情不会误解锁另一章的档案。剧情重置后移除失去条件的页面，若当前正在阅读该页则同步关闭阅读层。

窗口使用 `Control → SubViewportContainer → SubViewport → Node3D`，独立 World3D 中所有文档共用一个视口。页面场景为 `knowledge_space_document.tscn`，使用不透明网格与有深度测试的 Label3D；每份文档使用独立背景、边框和标题栏材质。三个按钮的图标由简单网格构成，不依赖特殊字符字形，也不增加文档视口。仅剧情边框持续更新，普通页面保持静态。摘录用 TextParagraph 按实际字体及换行规则限制高度，并扣除标题栏占用的空间，完整正文仍由阅读层显示。

选取使用当前 Camera3D 的射线与窗口实际矩形求交，取最近的有效命中，再识别该窗口正面标题栏的按钮；折叠后背景网格和命中范围同步缩小，原正文区域可以选中后面的文档。视图区 GUI 坐标按 SubViewport 的实际尺寸转换。输入仅由外层窗口控制，避免后台应用响应 WASD，也不修改全局 InputMap。`KnowledgeSpace` 以稳定文档 ID 保存本次关闭及折叠状态，重建卡片和同步档案时重新应用，不重新排列其他文档。

## 验证与证据

使用本地 Godot 4.7.2，Forward+ / D3D12，NVIDIA GeForce RTX 5060 Ti。Godot CLI 连接器默认仍是 4.6.3，复现时应显式指定 4.7.2 的可执行文件。

`tests/unit/test_knowledge_space.gd`：20 项测试、218 条断言通过，无孤儿节点。覆盖空库、最近记录和查询上限、字段回退、删除刷新、暂时读取失败后重试、纯文本转换、长正文、平行布局、共享视口、独立材质、章节完成记录、进度信号及只读性；同时检查关闭后的刷新与重开、折叠后的网格及射线范围、后方窗口选取、展开恢复、剧情重锁再解锁及三个按钮的正反面命中。

`tests/scenes/desktop/verify_knowledge_space.tscn` 在名称为 `KnowledgeAdminDesktopVerification` 的隔离工程运行，创建自己的卡片和进度样本，不读取玩家数据库。107 项检查通过，验证真实快捷方式、开始菜单、任务栏、选择与聚焦、持续按键飞行、手动中断、输入释放、最小化停渲染、档案解锁与重锁、关闭重开及 F6 独立场景。三个标题栏按钮通过真实鼠标路由操作，包含偏移视角下展开正视、刷新保留关闭与折叠、关闭按钮的双击处理、外层最小化恢复及重新打开空间后恢复文档。画面覆盖 1280×720、1920×1080 与 80%、100%、150% 字号，逐项验证按钮命中，并额外检查 720×480 最小窗口和长正文滚动。

现有 `verify_desktop.tscn -- --desktop-selection-only` 的 84 项检查通过，覆盖开机进入桌面、开始菜单、包含知识空间的新图标网格、唯一选择、重复单击及双击启动。

结果与截图见 [知识空间验收](desktop_review/knowledge_space/verification.json)，包含 [折叠](desktop_review/knowledge_space/document_minimized.png)、[全屏正视](desktop_review/knowledge_space/document_fullscreen.png)、[关闭](desktop_review/knowledge_space/document_closed.png)、聚焦阅读、各分辨率字号、最小窗口和独立场景的实际 GPU 图像。

知识空间初次接入时的全量 GUT 回归为 118 项中的 111 项通过；7 项失败全部来自已有的 `test_desktop_file_catalog.gd`。当时工作区的 `my_computer.tscn` 已删除 InfoLabel，而原脚本仍查找 `%InfoLabel`。该场景未在本功能中修改，历史完整日志保存在验收目录。本次悬浮窗口操作的验证为上述 20 项 GUT 与 107 项实际渲染检查。

## 参考

空间观感参考 [XanaduSpace](https://xanadu.com/xuspViewer.html) 与 [OpenXanadu 文档演示](https://xanadu.com/xanademos/MoeJusteOrigins.html)。实现使用 [Godot 视口](https://docs.godotengine.org/en/4.7/tutorials/rendering/viewports.html) 与 [Label3D](https://docs.godotengine.org/en/4.7/classes/class_label3d.html)，不引入原演示的运行库或引用系统。
