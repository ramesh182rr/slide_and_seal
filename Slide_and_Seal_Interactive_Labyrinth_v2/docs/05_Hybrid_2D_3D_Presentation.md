# 05 — Hybrid 2D/3D Presentation Specification

## 1. Visual architecture

- 2D simulation: authoritative grid and state.
- 3D presentation: isometric board, mechanisms, environment, lights and effects.
- 2D UI: menus, HUD, controls, overlays and accessibility.

The board is not a separate 3D physics game. It is a 3D representation of discrete puzzle state.

## 2. Camera

Default:
- Orthographic or near-orthographic.
- Elevated isometric angle.
- Board centered with enough space for HUD and controls.
- Stable camera during ordinary moves.

Contextual focus:
- Gravity reactor: subtle tilt/zoom.
- Portal: short focus and follow transition.
- Rotating section: frame the entire rotating region.
- Energy beam: camera may track beam route briefly.
- Completion: pull back to reveal the environment.

Keep camera transitions short, skippable and non-blocking.

## 3. Hybrid transitions

Do not switch between separate 2D and 3D games. The simulation remains the same. Camera changes and overlays communicate different information.

Examples:
- Preview: highlight affected cells and draw a projected route.
- Gravity: show directional field, then animate affected pieces.
- Portal: show entrance/exit connection and brief traversal effect.
- Rotation: animate a bounded section while preserving the grid's logical state.
- Energy routing: draw a crisp beam path and receiver status.

## 4. Gameplay readability

- Every cell boundary should remain understandable.
- Selected objects need a clear outline.
- Interactive mechanisms need a distinct silhouette.
- Color must be paired with shape/symbol.
- Avoid decorative geometry that looks interactable.
- Keep particle effects away from important route information.
- Use a neutral board lighting preset for difficult puzzles.

## 5. 2D UI overlay

Use Godot Control nodes and custom themed components. Do not rely on default theme controls in final screens.

HUD:
- Level/world title.
- Action counter.
- Core status.
- Checkpoint indicator.
- Undo/restart.
- Hint.
- Run/resume.
- Contextual mechanism panel.

## 6. Motion rules

- Model state commits before animation.
- Animation reads old/new state and interpolates.
- Gameplay input is locked during non-interruptible transitions.
- Reduced-motion mode replaces long camera moves and particles with quick fades or direct changes.
- Animation callbacks never determine collisions, gate logic or win conditions.
