# 启动封面

## 场景与视觉

入口为 `res://scenes/desktop/boot_screen.tscn`，对应逻辑为同目录的 `boot_screen.gd`。

深色背景叠加青蓝雾光、稀疏星点、细网格和移动扫描光。中央能量核心包含玻璃球体、流动波纹、相向旋转的青蓝／紫色弧线、倾斜轨道与移动光点。主文案为“正在启动系统”，下方保留英文品牌信息、细进度条及跳过提示，沿用项目的像素字体。

所有文案、进度条和布局均保存在原生场景节点中。背景与能量核心各使用一个 `ColorRect` 和独立 `ShaderMaterial`，没有外部贴图、屏幕采样、光线步进或后处理依赖。着色器使用 `TIME`，打开场景即可预览动态。

## 参数调整

| 位置 | 参数 | 作用 |
| --- | --- | --- |
| BootScreen 根节点 | `boot_duration` | 封面播放时长，默认 2.2 秒 |
| Background → Material | `accent_color` / `secondary_color` | 背景雾光与网格配色 |
| Background → Material | `animation_speed` | 背景扫描和星点变化速度，0 为静止 |
| EnergyCore → Material | `accent_color` / `secondary_color` | 核心及旋转光环配色 |
| EnergyCore → Material | `animation_speed` | 核心弧线、波纹和轨道光点速度，0 为静止 |
| EnergyCore → Material | `glow_strength` | 核心发光强度 |
| BootContent 下的 Label 节点 | `text` / 字体覆盖项 | 中文文案、品牌文字与字号 |

核心边长随可用视口高度调整，限制在 192～420 像素之间；布局缩小时给底部提示保留空间。背景按屏幕宽高比计算图案坐标。

## 启动行为

封面及内容平滑淡入，播放末尾淡出，再进入 `res://scenes/desktop/desktop.tscn`。进度条表示封面播放进度，不报告资源加载百分比。桌面仍按原有方式同步切换。

鼠标按下或非重复的键盘按下事件可立即跳过，松开按键及键盘自动重复事件不会触发跳转。装饰节点设置为忽略鼠标输入，点击核心、文字或进度条都能跳过。跳转只执行一次。

## 验收

2026-10-15，Godot 4.7.2，Forward+ / D3D12，在独立 `KnowledgeAdminBootVerification` 工程验证，不使用正式玩家数据库或存档。

- 实际 GPU 截图覆盖 1280×720、1920×1080、800×600；核心、文字和提示均完整显示且不重叠。
- 连续两帧图像不同，确认着色器持续运动。
- 真实鼠标与键盘输入均能进入桌面；按键释放与自动重复不会跳过。
- 默认 2.2 秒、进度推进、计时到期及真实时间自动切换均通过。
- 启动专项共 16 项检查通过；现有 4 组 GUT 脚本共 30 项测试、139 个断言通过。

截图及报告见 [1280×720](boot_screen_review/boot_1280x720.png)、[1920×1080](boot_screen_review/boot_1920x1080.png)、[800×600](boot_screen_review/boot_800x600.png) 和 [验收报告](boot_screen_review/verification.json)。

着色器内置变量与二维材质行为参考 [Godot CanvasItem shaders 官方文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)。
