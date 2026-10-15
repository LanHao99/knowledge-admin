# Classic98 桌面系统

## 启动与应用

主入口为 boot_screen.tscn；约 2.2 秒后进入桌面，鼠标或按键可以跳过。桌面不自动打开闪卡。双击或键盘确认快捷方式可启动应用；开始菜单单击启动。所有应用采用单实例。

WindowManager 注册 knowledge_admin、ai_cards、control_panel、my_computer、recycle_bin、unknown_program、help。后两者没有桌面或开始菜单入口。我的电脑提供预设目录与文本查看，回收站是空内容演示；不读写真实目录。

## 窗口与布局

ManagedWindow 的标题栏、内容区、边框及八个缩放把手均保存在场景中。标题栏拖动、八向缩放、双击最大化、最小化、关闭与任务栏切换共用状态。最大化只使用工作区，任务栏高度只扣除一次。

在 desktop.tscn 根节点 Inspector 调整 taskbar_height 和 application_sizes；在 managed_window.tscn 根节点调整 min_window_size。默认位置大小只在本次运行记忆。字体倍率沿用 UiSettings，标题栏和按钮同步缩放。小窗口、大字号时通过内容滚动访问页面。

最小化保留页面实例。学习中关闭需确认并调用 end_session；正在执行导入事务时不允许关闭。关闭系统有确认和取消。

任务栏的程序入口使用方形图标按钮，复用应用注册表中的图标，不显示程序名称文字。悬停提示和无障碍名称保留完整标题，当前应用保持按下高亮；点击仍然激活、最小化或恢复对应窗口。按钮与图标随字体倍率同步缩放，可在任务栏 Inspector 中调整 app_button_size 与 app_icon_size，按钮外观保存在 taskbar_app_button.tscn。

## 页面接入

App.open_app(app_id) 返回 bool；App.close_app(app_id) 请求关闭应用。App.goto_scene(path) 保留错误码返回：闪卡页面始终导航到 knowledge_admin，AI 和设置分别打开独立应用，不依赖哪个窗口当前激活。WindowContext 保留单独运行页面时的兼容路径。

恢复焦点时调用可选的 desktop_refresh：主页刷新统计，牌组和笔记仅在未编辑时刷新；进行中的学习和输入表单不重载。

## 剧情与教程

App.request_dialogue(resource, key, track_story=true, source=null) 接受串行请求。正式剧情先于未开始的教程；同类型按请求顺序处理。TutorialManager 传递来源节点，已销毁页面的待播教程丢弃并允许下次重新请求。

StoryDialogueOverlay 现在是可复用 Control，继续使用 DialogueManager 与 TextAnimationController。正式剧情装入未知程序；教程装入使用帮助，且只锁住来源应用。完成后沿用 dialogue_opened / dialogue_closed 通知学习场景。

剧情窗口可以拖动、缩放、最大化，但不能关闭或最小化。模态遮罩、背景处理禁用与焦点禁用共同隔离输入。已有非菜单弹窗暂存隐藏；异步新弹窗也被拦截。完成后恢复原窗口、弹窗和学习现场，未知程序最小化到任务栏。待机窗口关闭只隐藏，不销毁；后续剧情复用同一实例。Esc 只能加速打字，不能跳过选项或完成剧情。

## 验证方式

tests/unit/test_desktop_window.gd 使用真实场景检查窗口矩形、八向缩放、最小化保留内容与按钮锁定。

tests/desktop/verify_desktop.tscn 必须在 application/config/name 为 KnowledgeAdminDesktopVerification 的隔离工程运行；不会使用正式玩家的数据库和存档。它注入真实鼠标事件，检查启动、导航、AI 结果导入、JSON 文件导入、学习评分、剧情与帮助，并输出 desktop_review/verification.json 和 GPU 截图。

截图矩阵覆盖 1280×720、1920×1080 以及 80%、100%、150% 字号。AI 验收使用预设生成结果经过真实导入入口，不向外部模型服务发送请求。


## 验收记录

Godot 4.7.2：30 项 GUT 测试通过；真实 GPU 验收覆盖开机、八向鼠标缩放、菜单、两种导入、学习评分、剧情选项、弹窗恢复和六组分辨率／字号组合。报告及总览截图保存在 desktop_review 目录。未调用外部模型接口。

任务栏图标专项验收：运行 verify_desktop.tscn 时追加 `-- --taskbar-icons-only`，检查六组分辨率与字号组合下的方形比例、图标、名称提示和点击状态切换。118 项检查通过；预览与报告为 desktop_review/taskbar_icons.png 和 taskbar_icons_verification.json。
