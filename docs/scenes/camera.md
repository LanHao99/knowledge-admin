# 摄像头窗口

## 入口与窗口行为

从桌面双击“摄像头”，或在开始菜单单击启动。应用 ID 为 `camera`，可通过 `App.open_app("camera")` 打开。默认整窗大小为 560×560，最小大小为 320×320；工作区更小时按可用空间缩小。标题栏、八向缩放、最小化、关闭和任务栏按钮沿用 ManagedWindow，重复打开只激活已有实例。

摄像头在八向缩放和最大化时保持方形。最大化使用扣除任务栏后的最大正方形并居中，还原回之前的大小与位置。注册表通过 `keep_square` 与 `min_size` 配置这个行为；其他应用继续使用原来的矩形缩放。

## 检查器编辑

打开 `res://scenes/desktop/camera.tscn`，选择根节点 **Camera**。节点挂载 `@tool` 脚本 `camera.gd`，下面的属性通过 `@export` 暴露；修改后可在 2D 编辑器中即时预览，保存场景后用于下次运行。

| 分组 | 属性 | 默认值与用途 |
| --- | --- | --- |
| Portrait | `portrait_texture` | `assets/characters/mira_camera.png`；可拖入其他 Texture2D。 |
| Portrait | `portrait_zoom` | 1；保持比例完整显示，增大用于拉近。 |
| Portrait | `portrait_offset` | (0, 0)；以画面尺寸为单位，正值向右、向下。 |
| Portrait | `portrait_flip_h` | false；水平镜像。 |
| Portrait | `background_color` | #102521；透明像素及图片范围外的背景。 |
| CRT | `crt_enabled` | true；关闭后保留立绘合成，显示无 CRT 的原画。 |
| CRT | `resolution` | (320, 240)；扫描线、RGB 栅格与像素化的虚拟分辨率，分量至少为 1。 |
| CRT | `pixelate` | false；开启虚拟像素采样。 |
| CRT | `scanlines_opacity` | 0.22；水平扫描线强度。 |
| CRT | `grille_opacity` | 0.06；RGB 竖向栅格强度。 |
| CRT | `warp_amount` | 0.6；玻璃弯曲与黑色圆角边缘。 |
| CRT | `aberration` | 0.008；颜色通道偏移。 |
| CRT | `brightness` | 1.18；补偿扫描线和栅格造成的变暗。 |
| CRT | `vignette_opacity` | 0.35；边缘暗角。 |
| Signal | `static_noise_intensity` | 0.035；细颗粒噪声。 |
| Signal | `roll` | true；开启滚动信号扰动。 |
| Signal | `roll_speed` | 2；滚动速度，可用负值反向。 |
| Signal | `distort_intensity` | 0.008；横向扰动强度。 |

修改窗口初始边长可在 `desktop.tscn` 根节点的 `application_sizes.camera` 中设置。单独运行 `camera.tscn` 预览内容；完整标题栏和方形窗口行为需要从桌面启动。

## 立绘与渲染

默认 MIRA 头像由内置 imagegen 按用户要求生成：二次元、眼镜、长麻花辫、厚夹克。原始文件为 1254×1254 PNG，保留真实透明通道；生成提示词和来源记录见 [人物素材](../../assets/characters/README.md)。图片没有烘焙 CRT，可随时关闭效果查看原画。

`camera_crt.gdshader` 参考 `D:/game design/godot/public-demo/13#crt_effect/CRT.gdshader`。保留原 CC0 来源说明，使用局部 UV 合成立绘、背景、屏幕弯曲、扫描线、RGB 栅格、色偏、噪声和滚动扰动。它不读取 `SCREEN_TEXTURE`，所以不会扭曲标题栏、任务栏或其他窗口，也不会把桌面合成进图片透明区域。

材质设置 `resource_local_to_scene = true`，不同实例不会共享编辑结果。图片保持原比例，空图片显示“等待图像信号”；运行时替换或清空 `portrait_texture` 会立即更新。状态文字为叠加在画面上的原生 Label。

## 验证

Godot 4.7.2 下，摄像头专项 5 项、原窗口 5 项、窗口管理器 8 项 GUT 测试通过，共 18 项、79 个断言。覆盖立绘接入与移除、材质独立、虚拟分辨率下限、八向方形缩放、最大化还原和小工作区，以及现有矩形窗口行为。

`tests/desktop/verify_camera.tscn` 必须在名称为 `KnowledgeAdminDesktopVerification` 的隔离工程运行。使用真实 Forward+ / D3D12 渲染验证 17 项检查：应用入口、单实例、默认方形、纵向透明测试贴图的等比显示与镜像、CRT 产生实际像素变化、标题栏像素不变、最小化恢复、80%／100%／150% 字号的方形最大化及关闭释放。

验收报告和真实默认界面保存在 [camera_review](desktop_review/camera/verification.json) 与 [摄像头截图](desktop_review/camera/mira_camera.png)。测试色卡仅用于验证采样，未作为 MIRA 素材保存到正式内容中。
