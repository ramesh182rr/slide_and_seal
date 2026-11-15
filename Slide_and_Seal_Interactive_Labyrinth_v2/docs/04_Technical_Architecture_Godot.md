# 04 — Technical Architecture: Godot 4.x

## 1. Engine recommendation

Use Godot 4.x with typed GDScript. Pin the exact stable minor version used for production and record it in the repository. Start with the Mobile renderer for Android. Profile on physical devices before selecting final rendering features.

## 2. Architectural principle

**One deterministic 2D simulation, one 3D board renderer, one 2D UI layer.**

The simulation owns truth. The renderer never decides gameplay rules. Animation never changes puzzle state.

## 3. Layer model

### Simulation layer
- Grid and terrain.
- Core route and checkpoint state.
- Mechanism state.
- Collision and occupancy.
- Action validation.
- Solver and validator.

### 3D presentation layer
- Board tiles and environment.
- Blocks, core and mechanisms.
- Lights, materials, particles and shaders.
- Camera rig and focus transitions.
- Animation playback.

### 2D interface layer
- Menus and HUD.
- Mechanism selection and controls.
- Preview overlays.
- Hints, undo, restart, pause.
- Daily and campaign UI.

## 4. Suggested project structure

```text
slide_and_seal/
  project.godot
  scenes/
    app/
    home/
    world_select/
    level_select/
    gameplay/
      gameplay_root.tscn
      puzzle_world_3d.tscn
      board_3d.tscn
      camera_rig.tscn
    daily/
    completion/
    settings/
    store/
  scripts/
    model/
      puzzle_state.gd
      level_data.gd
      mechanism_state.gd
      core_state.gd
    simulation/
      puzzle_simulator.gd
      core_route_resolver.gd
      gravity_resolver.gd
      push_resolver.gd
      portal_resolver.gd
      switch_gate_resolver.gd
      rotation_resolver.gd
      energy_beam_resolver.gd
      polarity_resolver.gd
      collision_service.gd
    solver/
      puzzle_solver.gd
      state_hasher.gd
      level_validator.gd
    controllers/
      gameplay_controller.gd
      interaction_controller.gd
      camera_controller.gd
    presentation/
      board_renderer_3d.gd
      mechanism_renderer_3d.gd
      core_renderer_3d.gd
      animation_director.gd
      effects_director.gd
    ui/
      hud_controller.gd
      mechanism_panel.gd
      preview_overlay.gd
    services/
      save_manager.gd
      daily_manager.gd
      purchase_manager.gd
      ads_manager.gd
  data/
    levels/
    daily/
    worlds/
  assets/
    environments/
    meshes/
    materials/
    shaders/
    textures/
    audio/
    fonts/
    ui/
  tests/
    unit/
    integration/
    levels/
  docs/
```

## 5. Core data types

Use explicit data models:
- `GridCoord` or `Vector2i`.
- `Direction` enum.
- `PuzzleState`.
- `LevelDefinition`.
- `MechanismDefinition`.
- `CoreRouteState`.
- `CheckpointDefinition`.
- `PuzzleAction`.
- `ActionResult`.

## 6. Simulation API

Suggested conceptual API:

```gdscript
func apply_action(
    level: LevelDefinition,
    state: PuzzleState,
    action: PuzzleAction
) -> ActionResult:
    pass

func simulate_core_segment(
    level: LevelDefinition,
    state: PuzzleState
) -> CoreTravelResult:
    pass

func preview_action(
    level: LevelDefinition,
    state: PuzzleState,
    action: PuzzleAction
) -> ActionResult:
    pass
```

The functions should not mutate the caller's state. Return a new state or a clearly defined immutable snapshot.

## 7. State and action transaction

1. Receive player action.
2. Validate action phase.
3. Clone or snapshot state.
4. Apply resolver.
5. Validate invariants.
6. Commit new state.
7. Emit a presentation event.
8. Animate the committed result.

If validation fails, state remains unchanged.

## 8. 3D coordinate mapping

Map grid `(x, y)` to a consistent world-space transform. Keep the mapping in one service. Do not scatter coordinate conversion formulas across individual mechanisms.

Use an orthographic camera for default gameplay. A slight perspective camera may be used for cinematic world reveals, but puzzle readability takes priority.

## 9. Rendering and performance

- Mobile renderer initially.
- Modular meshes and material reuse.
- Baked lighting for static environment geometry where appropriate.
- Limit real-time shadow-casting lights.
- Use emission carefully; avoid excessive transparent overdraw.
- Use LOD or simplified distant geometry where needed.
- Pool frequently reused particles if profiling shows benefit.
- Test low/mid-range Android devices early.
- Provide scalable visual quality options if needed.

## 10. Android requirements

- Portrait-first layout unless prototype testing strongly favors landscape.
- Respect safe areas and system insets.
- Test touch input and Android back behavior.
- Handle pause/resume and process termination.
- Campaign playable offline.
- Secure signing configuration; never commit keystores or secrets.
- Billing and ads behind service interfaces.

## 11. Solver

The solver must call the same simulation rules as gameplay. Start with BFS for unit-cost actions and small boards. Use canonical state serialization and visited-state tracking. Add A* only after correctness is established and a useful heuristic is defined.

## 12. Testing

- Unit tests for every mechanic.
- Preview equals committed simulation result.
- Undo restores full state.
- Solver and gameplay agree.
- Level validator checks every shipped level.
- Device tests cover touch, resolution, performance and lifecycle.
