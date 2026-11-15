extends SceneTree
## Headless test runner (decision D-004).
##
## Usage from the repository root:
##   tools/run_tests.sh
## or directly (after an import pass so class_name types resolve):
##   godot --headless --path game --script res://tests/run_tests.gd
##
## Discovers every `test_*.gd` under TEST_ROOTS, runs each `test_*` method in name order,
## and exits with code 0 only if every test passed. Any engine/script error logged while
## a test runs (e.g. a null dereference) fails that test, so crashes cannot pass silently.

const TEST_ROOTS := ["res://tests/unit", "res://tests/integration", "res://tests/levels"]


class ErrorCollector:
	extends Logger
	var _mutex := Mutex.new()
	var _messages: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		_messages.append("engine error: %s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var messages := _messages
		_messages = PackedStringArray()
		_mutex.unlock()
		return messages


var _started := false


## Tests run on the first frame, not in _initialize: only then is the root viewport inside the
## tree, so scenes added by tests receive _ready like in the real game.
func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var exit_code := _run_all(collector)
	OS.remove_logger(collector)
	quit(exit_code)
	return false


func _run_all(collector: ErrorCollector) -> int:
	var files := PackedStringArray()
	for root: String in TEST_ROOTS:
		_collect(root, files)
	files.sort()

	var passed := 0
	var failed := 0
	for path: String in files:
		var script := load(path) as GDScript
		var load_errors := collector.take()
		if script == null or not load_errors.is_empty() or not script.can_instantiate():
			failed += 1
			_report_failure(path, "<load>", load_errors)
			continue
		var instance: Variant = script.new()
		if not instance is TestCase:
			failed += 1
			_report_failure(path, "<load>", PackedStringArray(["does not extend TestCase"]))
			continue
		var test_case: TestCase = instance
		for method_name: String in _test_methods(test_case):
			test_case.begin_test()
			test_case.call(method_name)
			var failures := test_case.get_failures()
			failures.append_array(collector.take())
			if failures.is_empty():
				passed += 1
				print("  PASS  %s :: %s" % [path.get_file(), method_name])
			else:
				failed += 1
				_report_failure(path, method_name, failures)

	print("\n%d passed, %d failed, %d total" % [passed, failed, passed + failed])
	if passed + failed == 0:
		printerr("No tests found.")
		return 1
	return 0 if failed == 0 else 1


static func _test_methods(test_case: TestCase) -> PackedStringArray:
	var names := PackedStringArray()
	for method: Dictionary in test_case.get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


static func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub_dir: String in dir.get_directories():
		_collect(dir_path.path_join(sub_dir), out)
	for file_name: String in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))


static func _report_failure(path: String, method_name: String, failures: PackedStringArray) -> void:
	print("  FAIL  %s :: %s" % [path.get_file(), method_name])
	for failure: String in failures:
		print("        - " + failure)
