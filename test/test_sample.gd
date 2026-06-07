extends GutTest


func before_all() -> void:
	gut.p("=== GUT 插件加载测试开始 ===")


func after_all() -> void:
	gut.p("=== GUT 插件加载测试结束 ===")


func test_gut_basic_assertions() -> void:
	assert_true(true, "基本断言 true 应通过")
	assert_eq(1 + 1, 2, "基本算术 1+1=2 应通过")
	assert_ne(1, 2, "基本不等 1≠2 应通过")


func test_gut_string_operations() -> void:
	assert_eq("hello", "hello", "字符串相等断言")
	assert_ne("hello", "world", "字符串不等断言")


func test_gut_type_checks() -> void:
	assert_typeof("string", TYPE_STRING)
	assert_typeof(42, TYPE_INT)
	assert_typeof(3.14, TYPE_FLOAT)
	assert_typeof(true, TYPE_BOOL)


func test_gut_null_checks() -> void:
	assert_null(null)
	assert_not_null(self)
