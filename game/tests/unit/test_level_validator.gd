extends TestCase
## LevelValidator: release-gate errors and designer warnings.

const PUSH := MechanismIds.PUSH_PULSE


func _report(data: Dictionary) -> LevelValidator.Report:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load")
	return LevelValidator.validate_level(level, "fixture")


func _has(messages: PackedStringArray, fragment: String) -> bool:
	for message: String in messages:
		if message.contains(fragment):
			return true
	return false


func test_valid_level_passes_with_matching_optimum() -> void:
	var data := LevelFixtures.corridor()
	data["scoring"] = {"target_actions": 0, "optimal_actions": 0}
	var report := _report(data)
	assert_true(report.is_valid(), str(report.errors))
	assert_eq(report.minimum_actions, 0)
	assert_eq(report.warnings, PackedStringArray())


func test_unsolvable_level_is_an_error() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "heavy", Vector2i(5, 1), false)
	var report := _report(data)
	assert_false(report.is_valid())
	assert_true(_has(report.errors, "level is unsolvable"), str(report.errors))


func test_target_below_minimum_is_an_error() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(5, 1))
	LevelFixtures.allow_everywhere(data, [PUSH])
	data["scoring"] = {"target_actions": 0, "optimal_actions": null}
	assert_true(_has(_report(data).errors, "target_actions 0 is below the proven minimum 1"))


func test_wrong_optimal_actions_is_an_error() -> void:
	var data := LevelFixtures.corridor()
	data["scoring"] = {"target_actions": 3, "optimal_actions": 2}
	assert_true(_has(_report(data).errors, "optimal_actions 2 does not match the proven minimum 0"))


func test_missing_optimal_actions_is_a_warning() -> void:
	var report := _report(LevelFixtures.corridor())
	assert_true(report.is_valid())
	assert_true(_has(report.warnings, "optimal_actions is null; the proven minimum is 0"))


func test_dead_ends_are_warnings_with_example() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(5, 1))
	data["setup"] = {"allowed_mechanisms": [PUSH]}
	data["scoring"] = {"target_actions": 1, "optimal_actions": 1}
	var report := _report(data)
	assert_true(report.is_valid(), "softlocks are recoverable with undo, so they warn rather than fail")
	assert_true(report.dead_end_states > 0)
	assert_true(_has(report.warnings, "dead-end states (undo recovers); shortest: run"), str(report.warnings))
