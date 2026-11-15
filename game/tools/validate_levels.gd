extends SceneTree
## Command-line level validator. Usage from the repository root: tools/validate_levels.sh
## Exit code 0 = every level valid (warnings allowed), 1 = at least one error.

const LEVELS_DIR := "res://data/levels"


func _initialize() -> void:
	var reports := LevelValidator.validate_directory(LEVELS_DIR)
	var failed := 0
	for report: LevelValidator.Report in reports:
		print(report.to_text())
		if not report.is_valid():
			failed += 1
	print("\n%d levels, %d failed" % [reports.size(), failed])
	quit(1 if failed > 0 or reports.is_empty() else 0)
