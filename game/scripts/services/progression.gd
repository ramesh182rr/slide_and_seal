class_name Progression
extends RefCounted
## Pure progression rules (P-013): sequential unlocking in catalog order and star ratings
## (docs/01 §10). Stars never gate progression.


## TEMPORARY (owner request, 2026-11-16, D-037): every level is open so the whole game can be
## reviewed on a phone. Set to false to restore solve-to-unlock. Tests turn it off (run_tests.gd).
static var unlock_all: bool = true


## The first level is always open; every other level opens when the one before it is completed.
static func is_unlocked(catalog: LevelCatalog, progress: ProgressStore, level_id: String) -> bool:
	var entry := catalog.entry(level_id)
	if entry == null:
		return false
	if unlock_all or entry.order == 0:
		return true
	return progress.is_completed(catalog.entries[entry.order - 1].level_id)


## 0 = not completed, 1 = completed, 2 = designer target met, 3 = solver-proven optimum matched.
## Three stars are only possible when `optimal_actions` is known (never claim an unproven optimum).
static func stars(actions: int, target_actions: int, optimal_actions: int) -> int:
	if actions < 0:
		return 0
	if optimal_actions >= 0 and actions <= optimal_actions:
		return 3
	if actions <= target_actions:
		return 2
	return 1
