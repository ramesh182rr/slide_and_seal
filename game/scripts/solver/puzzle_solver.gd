class_name PuzzleSolver
extends RefCounted
## Exhaustive search over the real simulation (docs/08 §4). Every transition is
## PuzzleSimulator.apply_action, so the solver can never disagree with gameplay.
## States are merged by PuzzleState.to_key(false): counters do not affect future behaviour.
## Cost model: core runs are free, each mechanism action costs 1.

const DEFAULT_MAX_STATES := 200000
## Per-state cap when proving a dead end by exhausting its closure.
const DEFAULT_CLOSURE_LIMIT := 4000


class Result:
	extends RefCounted
	var solvable: bool = false
	## True when the search stopped at max_states before finding a solution: "unsolvable" is then unproven.
	var limit_hit: bool = false
	var states_explored: int = 0
	## Proven minimum number of mechanism actions, or -1.
	var minimum_actions: int = -1
	## One minimum solution, including the RUN_CORE actions.
	var solution: Array[PuzzleAction] = []


class Analysis:
	extends RefCounted
	## Mechanism-action depth examined from the start (all states within it are classified).
	var depth: int = 0
	var examined_states: int = 0
	## Proven softlocks: unfinished states whose entire closure contains no completion. Undo recovers.
	var dead_end_states: int = 0
	## States whose closure exceeded the cap: neither proven solvable nor proven dead.
	var unknown_states: int = 0
	## A shortest (fewest mechanism actions) path from the start into a proven dead end.
	var dead_end_example: Array[PuzzleAction] = []
	## True when max_states cut the depth-bounded enumeration short.
	var limit_hit: bool = false


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
	for switch_def: SwitchDefinition in level.switches:
		if switch_def.kind == SwitchDefinition.Kind.TOGGLE:
			actions.append(PuzzleAction.toggle_switch(switch_def.id))
	return actions


## Finds a solution with the proven minimum number of mechanism actions.
static func solve(level: LevelDefinition, max_states: int = DEFAULT_MAX_STATES) -> Result:
	var result := Result.new()
	var search := _Search.new(level, max_states)
	var found := search.layered(-1)
	result.states_explored = search.states.size()
	result.limit_hit = search.limit_hit
	if found >= 0:
		result.solvable = true
		result.minimum_actions = search.costs[found]
		result.solution = search.path_to(found)
	return result


## Classifies every state reachable within `depth` mechanism actions as completable,
## proven dead end, or unknown (closure larger than `closure_limit`).
static func analyze(level: LevelDefinition, depth: int, closure_limit: int = DEFAULT_CLOSURE_LIMIT,
		max_states: int = DEFAULT_MAX_STATES) -> Analysis:
	var analysis := Analysis.new()
	analysis.depth = depth
	var search := _Search.new(level, max_states)
	search.layered(depth, false)
	analysis.limit_hit = search.limit_hit
	analysis.examined_states = search.states.size()
	var classifier := _Classifier.new(level, closure_limit)
	# Nodes are in non-decreasing cost order, so the first dead end has the fewest actions.
	for node: int in search.states.size():
		match classifier.classify(search.states[node]):
			_Classifier.DEAD:
				if analysis.dead_end_states == 0:
					analysis.dead_end_example = search.path_to(node)
				analysis.dead_end_states += 1
			_Classifier.UNKNOWN:
				analysis.unknown_states += 1
	return analysis


## Deduplicated state store with BFS-tree parents and mechanism-action costs.
class _Search:
	extends RefCounted
	var level: LevelDefinition
	var actions: Array[PuzzleAction]
	var max_states: int
	var limit_hit: bool = false
	var states: Array[PuzzleState] = []
	var parents := PackedInt32Array()
	var via := PackedInt32Array()
	var costs := PackedInt32Array()
	var _index: Dictionary[String, int] = {}

	func _init(p_level: LevelDefinition, p_max_states: int) -> void:
		level = p_level
		max_states = p_max_states
		actions = PuzzleSolver.candidate_actions(level)
		_add(level.create_initial_state(), -1, -1, 0)

	## Layered search: each layer holds every state reachable with k mechanism actions, closed under
	## free core runs. Returns the first completed node (minimum cost) when `stop_at_solution`,
	## otherwise -1 after enumerating up to `max_cost` (-1 = unbounded).
	func layered(max_cost: int, stop_at_solution: bool = true) -> int:
		var layer := PackedInt32Array([0])
		var cost := 0
		while not layer.is_empty():
			var i := 0
			while i < layer.size():
				var node := layer[i]
				i += 1
				if states[node].phase == PuzzleState.Phase.LEVEL_COMPLETED:
					if stop_at_solution:
						return node
					continue
				var child := expand(node, 0, cost)
				if child >= 0:
					layer.append(child)
			if cost == max_cost or limit_hit:
				break
			var next_layer := PackedInt32Array()
			for node: int in layer:
				if states[node].phase == PuzzleState.Phase.LEVEL_COMPLETED:
					continue
				for action_index: int in range(1, actions.size()):
					var child := expand(node, action_index, cost + 1)
					if child >= 0:
						next_layer.append(child)
			layer = next_layer
			cost += 1
		return -1

	## Applies an action to `node`. Returns the new node, or -1 if rejected, already known or over the limit.
	func expand(node: int, action_index: int, cost: int) -> int:
		var result := PuzzleSimulator.apply_action(level, states[node], actions[action_index])
		if not result.is_ok():
			return -1
		if _index.has(result.state.to_key(false)):
			return -1
		if states.size() >= max_states:
			limit_hit = true
			return -1
		return _add(result.state, node, action_index, cost)

	func path_to(node: int) -> Array[PuzzleAction]:
		var path: Array[PuzzleAction] = []
		while parents[node] != -1:
			path.push_front(actions[via[node]])
			node = parents[node]
		return path

	func _add(state: PuzzleState, parent: int, action_index: int, cost: int) -> int:
		states.append(state)
		parents.append(parent)
		via.append(action_index)
		costs.append(cost)
		_index[state.to_key(false)] = states.size() - 1
		return states.size() - 1


## Proves states completable or dead by bounded forward search, sharing results between queries.
class _Classifier:
	extends RefCounted
	const COMPLETABLE := 1
	const DEAD := 2
	const UNKNOWN := 0

	var level: LevelDefinition
	var actions: Array[PuzzleAction]
	var closure_limit: int
	var _status: Dictionary[String, int] = {}

	func _init(p_level: LevelDefinition, p_closure_limit: int) -> void:
		level = p_level
		closure_limit = p_closure_limit
		actions = PuzzleSolver.candidate_actions(level)

	func classify(root: PuzzleState) -> int:
		var root_key := root.to_key(false)
		if _status.has(root_key):
			return _status[root_key]
		# Local BFS over the root's closure. Stops at a completion or a known-completable state.
		var keys := PackedStringArray([root_key])
		var states: Array[PuzzleState] = [root]
		var parents := PackedInt32Array([-1])
		var seen: Dictionary[String, bool] = {root_key: true}
		var head := 0
		while head < states.size():
			var node := head
			head += 1
			var key := keys[node]
			if states[node].phase == PuzzleState.Phase.LEVEL_COMPLETED or _status.get(key, UNKNOWN) == COMPLETABLE:
				while node != -1:  # Everything on the path to a completion is completable.
					_status[keys[node]] = COMPLETABLE
					node = parents[node]
				return COMPLETABLE
			if _status.get(key, UNKNOWN) == DEAD:
				continue
			if states.size() >= closure_limit:
				return UNKNOWN
			for action: PuzzleAction in actions:
				var result := PuzzleSimulator.apply_action(level, states[node], action)
				if result.is_ok():
					var child_key := result.state.to_key(false)
					if not seen.has(child_key):
						seen[child_key] = true
						keys.append(child_key)
						states.append(result.state)
						parents.append(node)
		# Closure exhausted without a completion: every state in it is a dead end.
		for key: String in keys:
			_status[key] = DEAD
		return DEAD
