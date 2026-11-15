class_name TestSolver
extends RefCounted
## Bounded exhaustive search for level tests. Precursor of the production solver (M4).
## Uses only PuzzleSimulator, so it shares every rule with gameplay.
## Core runs are free and mechanism actions cost 1, so the first solution found uses
## the minimum possible number of mechanism actions.


class Solution:
	extends RefCounted
	var actions: Array[PuzzleAction] = []
	var mechanism_actions: int = 0


## Every action that could apply in some state of `level`, in a stable order.
static func candidate_actions(level: LevelDefinition) -> Array[PuzzleAction]:
	var actions: Array[PuzzleAction] = [PuzzleAction.run_core()]
	for obj: MovableObject in level.initial_objects:
		if obj.pushable:
			for direction: int in 4:
				actions.append(PuzzleAction.push(obj.id, direction as Grid.Direction))
	for zone: GravityZoneDefinition in level.gravity_zones:
		for direction: Grid.Direction in zone.allowed_directions:
			actions.append(PuzzleAction.set_gravity(zone.id, direction))
	return actions


## Returns a minimum-mechanism-action solution, or null if none exists within `max_states`.
static func solve(level: LevelDefinition, max_states: int = 200000) -> Solution:
	var actions := candidate_actions(level)
	var states: Array[PuzzleState] = [level.create_initial_state()]
	var parents: PackedInt32Array = [-1]
	var via: PackedInt32Array = [-1]
	var seen: Dictionary[String, bool] = {states[0].to_key(false): true}
	var layer: PackedInt32Array = [0]
	while not layer.is_empty() and states.size() <= max_states:
		# Close the layer under RUN_CORE (cost 0).
		var i := 0
		while i < layer.size():
			var node := layer[i]
			i += 1
			if states[node].phase == PuzzleState.Phase.LEVEL_COMPLETED:
				return _build_solution(actions, states, parents, via, node)
			var child := _expand(level, actions, 0, node, states, parents, via, seen)
			if child != -1:
				layer.append(child)
		# Mechanism actions (cost 1) form the next layer.
		var next_layer := PackedInt32Array()
		for node: int in layer:
			for action_index: int in range(1, actions.size()):
				var child := _expand(level, actions, action_index, node, states, parents, via, seen)
				if child != -1:
					next_layer.append(child)
		layer = next_layer
	return null


static func _expand(level: LevelDefinition, actions: Array[PuzzleAction], action_index: int, node: int,
		states: Array[PuzzleState], parents: PackedInt32Array, via: PackedInt32Array,
		seen: Dictionary[String, bool]) -> int:
	var result := PuzzleSimulator.apply_action(level, states[node], actions[action_index])
	if not result.is_ok():
		return -1
	var key := result.state.to_key(false)
	if seen.has(key):
		return -1
	seen[key] = true
	states.append(result.state)
	parents.append(node)
	via.append(action_index)
	return states.size() - 1


static func _build_solution(actions: Array[PuzzleAction], states: Array[PuzzleState],
		parents: PackedInt32Array, via: PackedInt32Array, node: int) -> Solution:
	var solution := Solution.new()
	solution.mechanism_actions = states[node].mechanism_action_count
	while parents[node] != -1:
		solution.actions.push_front(actions[via[node]])
		node = parents[node]
	return solution
