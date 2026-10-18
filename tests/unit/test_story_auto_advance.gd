extends GutTest
## 验证无正文的自动推进行和关闭动画后的自动推进，不依赖玩家存档。

var _animator: TextAnimationController
var _label: RichTextLabel


## 建立真实文字控制器和显示控件。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_label = add_child_autofree(RichTextLabel.new()) as RichTextLabel
	_animator = add_child_autofree(TextAnimationController.new()) as TextAnimationController
	_animator.setup(_label)
	watch_signals(_animator)


## 只有自动标记的结尾行应完成并且只推进一次。## 输入: 无。
## 输出: 无。
func test_auto_only_line_advances_once() -> void:
	_animator.play_line("{auto}")
	_animator.skip_to_end()
	assert_signal_emit_count(_animator, "auto_advance_requested", 1)
	assert_signal_emit_count(_animator, "typewriter_completed", 1)
	assert_false(_animator.is_playing())
	assert_eq(_label.text, "")


## 禁用文字动画时仍应保留自动推进语义。## 输入: 无。
## 输出: 无。
func test_instant_text_keeps_auto_advance() -> void:
	_animator.disable_all_animations = true
	_animator.play_line("继续剧情{auto}")
	_animator.skip_to_end()
	assert_signal_emit_count(_animator, "auto_advance_requested", 1)
	assert_false(_animator.is_playing())
	assert_eq(_label.text, "继续剧情")


## 普通空白行不能意外触发自动推进。## 输入: 无。
## 输出: 无。
func test_empty_line_without_auto_does_not_advance() -> void:
	_animator.play_line("")
	assert_signal_not_emitted(_animator, "auto_advance_requested")
	assert_false(_animator.is_playing())
