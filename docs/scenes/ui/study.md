# study.gd (Study)

> **路径**: `res://src/ui/study.gd`
> **继承**: `Node2D`
> **类型**: UI层

## 软件时间变化

Study 订阅 AppClock 的手动调时和自然跨复习日信号，调用 StudyManager.refresh_for_time_change()，随后刷新牌组选择页。刷新保持当前卡片、正反面、正文和已有完成数，读取失败通过 CardUI 暂停评分并显示重试。单题和整轮耗时使用单调计时。完整规则见 [日期和时间](../date_time.md)。
