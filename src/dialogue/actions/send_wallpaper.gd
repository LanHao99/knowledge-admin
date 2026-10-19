extends RefCounted
## 由剧情确认入口执行的壁纸切换动作；解锁在接收壁纸时完成。


## 将已解锁的图片设为桌面壁纸并保存。## 输入: arguments (Array) - 第一项为壁纸路径。
## 输出: bool - 图片切换且保存成功时为 true。
func execute(arguments: Array) -> bool:
	if arguments.size() != 1 or not arguments[0] is String:
		return false
	var path: String = arguments[0]
	if not WallpaperSettings.is_wallpaper_unlocked(path):
		return false
	WallpaperSettings.set_wallpaper(path)
	return WallpaperSettings.wallpaper_path == path and WallpaperSettings.save_settings() == OK
