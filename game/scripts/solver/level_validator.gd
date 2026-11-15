class_name LevelValidator
extends RefCounted
## Release gate for level data (docs/08 §2, docs/12). Combines schema validation, the solver
## and a full reachability analysis. Errors block shipping; warnings need a designer decision.


class Report:
	extends RefCounted
	var path: String = ""
	var level_id: String = ""
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()
	var minimum_actions: int = -1
	var solution: Array[PuzzleAction] = []
	var analysis_depth: int = 0
	var examined_states: int = 0
	var dead_end_states: int = 0
	var unknown_states: int = 0

	func is_valid() -> bool:
		return errors.is_empty()

	func to_text() -> String:
		var lines := PackedStringArray()
		lines.append("%s  %s" % ["PASS" if is_valid() else "FAIL", level_id if level_id != "" else path])
		if minimum_actions >= 0:
			var steps := PackedStringArray()
			for action: PuzzleAction in solution:
				steps.append(action.describe())
			lines.append("      minimum %d actions: %s" % [minimum_actions, " > ".join(steps)])
		if examined_states > 0:
			lines.append("      softlock scan: %d states within %d actions, %d dead ends, %d unknown"
				% [examined_states, analysis_depth, dead_end_states, unknown_states])
		for message: String in errors:
			lines.append("      ERROR: " + message)
		for message: String in warnings:
			lines.append("      warning: " + message)
		return "\n".join(lines)


static func validate_file(path: String, max_states: int = PuzzleSolver.DEFAULT_MAX_STATES) -> Report:
	var report := Report.new()
	report.path = path
	var loaded := LevelLoader.load_file(path)
	if not loaded.is_ok():
		report.errors = loaded.errors
		return report
	return validate_level(loaded.level, path, max_states)


static func validate_level(level: LevelDefinition, path: String = "",
		max_states: int = PuzzleSolver.DEFAULT_MAX_STATES) -> Report:
	var report := Report.new()
	report.path = path
	report.level_id = level.id

	var result := PuzzleSolver.solve(level, max_states)
	if not result.solvable:
		if result.limit_hit:
			report.errors.append("no solution found within %d states (search limit; unsolvability not proven)" % max_states)
		else:
			report.errors.append("level is unsolvable (every reachable state explored)")
		return report
	report.minimum_actions = result.minimum_actions
	report.solution = result.solution
	if level.target_actions < result.minimum_actions:
		report.errors.append("target_actions %d is below the proven minimum %d" % [level.target_actions, result.minimum_actions])
	if level.optimal_actions == -1:
		report.warnings.append("optimal_actions is null; the proven minimum is %d" % result.minimum_actions)
	elif level.optimal_actions != result.minimum_actions:
		report.errors.append("optimal_actions %d does not match the proven minimum %d" % [level.optimal_actions, result.minimum_actions])

	# Softlock scan: every state a player can reach within one action beyond the minimum.
	var analysis := PuzzleSolver.analyze(level, result.minimum_actions + 1, PuzzleSolver.DEFAULT_CLOSURE_LIMIT, max_states)
	report.analysis_depth = analysis.depth
	report.examined_states = analysis.examined_states
	report.dead_end_states = analysis.dead_end_states
	report.unknown_states = analysis.unknown_states
	if analysis.limit_hit:
		report.warnings.append("softlock scan stopped at %d states; depth %d not fully covered" % [max_states, analysis.depth])
	if analysis.dead_end_states > 0:
		var steps := PackedStringArray()
		for action: PuzzleAction in analysis.dead_end_example:
			steps.append(action.describe())
		report.warnings.append("%d proven dead-end states (undo recovers); shortest: %s"
			% [analysis.dead_end_states, " > ".join(steps)])
	if analysis.unknown_states > 0:
		report.warnings.append("%d states could not be classified within the closure limit" % analysis.unknown_states)
	return report


## Validates every *.json level in `directory`, in name order.
static func validate_directory(directory: String, max_states: int = PuzzleSolver.DEFAULT_MAX_STATES) -> Array[Report]:
	var reports: Array[Report] = []
	var names := Array(DirAccess.get_files_at(directory))
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".json"):
			reports.append(validate_file(directory.path_join(file_name), max_states))
	return reports
