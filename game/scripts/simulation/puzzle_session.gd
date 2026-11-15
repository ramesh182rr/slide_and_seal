class_name PuzzleSession
extends RefCounted
## Owns the committed state and undo history for one play of a level.
## Contains no puzzle rules: every transition goes through PuzzleSimulator.
## Undo and restart behaviour follow decision P-005.

var _level: LevelDefinition
var _state: PuzzleState
## Previously committed states, oldest first. Committed states are never mutated, so references are safe.
var _history: Array[PuzzleState] = []


func _init(p_level: LevelDefinition) -> void:
	_level = p_level
	_state = p_level.create_initial_state()


func get_level() -> LevelDefinition:
	return _level


## The committed state. Treat as read-only.
func get_state() -> PuzzleState:
	return _state


## Validates and commits an action. A rejected action changes nothing.
func apply(action: PuzzleAction) -> ActionResult:
	var result := PuzzleSimulator.apply_action(_level, _state, action)
	if result.is_ok():
		_history.append(_state)
		_state = result.state
	return result


func preview(action: PuzzleAction) -> ActionResult:
	return PuzzleSimulator.preview_action(_level, _state, action)


func can_undo() -> bool:
	return not _history.is_empty()


func undo() -> bool:
	if _history.is_empty():
		return false
	_state = _history.pop_back()
	return true


func is_at_initial_state() -> bool:
	return _state.to_key() == _level.create_initial_state().to_key()


## Restores the exact authored initial state. Undoable; a no-op when already at the initial state.
func restart() -> bool:
	if is_at_initial_state():
		return false
	var initial := _level.create_initial_state()
	_history.append(_state)
	_state = initial
	return true
