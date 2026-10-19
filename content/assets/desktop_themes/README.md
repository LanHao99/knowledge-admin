# Desktop Themes 资源来源

## 来源

Classic95 资源复制自本机参考项目：

`D:\game design\godot\4.6projects\godot-desktop-themes-master\Themes\Classic95`

原项目作者：Violin Iliev。许可证为 MIT，完整许可见 [LICENSE](LICENSE)。

## 使用方式

PNG 纹理保持原始内容。
StyleBox 资源仅将路径改为当前项目的 `res://content/assets/desktop_themes/Classic95/`，并去除跨项目重复的 UID。

应用主题在 `content/assets/UI/app_theme.tres` 中保留 Classic95 的按钮、标签页、滚动条、凹陷输入区和窗口样式，并加入统一字体字号类型。
主界面和设置页标题栏用 AtlasTexture 直接引用原始 Window.png 中的蓝色渐变区域。
运行时窗口标题字号变化需要独立的 StyleBox 与 Image 副本，避免修改原始资源。
