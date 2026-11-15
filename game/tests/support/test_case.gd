class_name TestCase
extends RefCounted
## Minimal assertion base for the headless runner (res://tests/run_tests.gd).
## Test files extend this class and define `func test_xxx() -> void` methods.

var _failures: PackedStringArray = PackedStringArray()


func begin_test() -> void:
	_failures = PackedStringArray()


func get_failures() -> PackedStringArray:
	return _failures


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("expected true" + _suffix(message))


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("expected false" + _suffix(message))


## Strict equality: types must match too.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		fail("expected <%s> but got <%s>%s" % [expected, actual, _suffix(message)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same(actual, unexpected):
		fail("expected a value other than <%s>%s" % [unexpected, _suffix(message)])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("expected null but got <%s>%s" % [value, _suffix(message)])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected a non-null value" + _suffix(message))


static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


static func _suffix(message: String) -> String:
	return "" if message.is_empty() else " — " + message
