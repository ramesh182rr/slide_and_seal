# SLIDE & SEAL — Interactive Mechanical Labyrinth

**Artifact pack:** v2.0  
**Design status:** Revised concept baseline, ready for prototype planning  
**Engine:** Godot 4.x  
**Platform:** Android first  
**Presentation:** Hybrid — deterministic 2D puzzle simulation + premium isometric 3D board + custom 2D UI

> Reconfigure reality. Control the maze. Complete the seal.

## What changed

This package replaces the previous “move blocks to guide an automatically stepping object” concept. The new game is an interactive mechanical puzzle in which players manipulate an interconnected labyrinth using gravity, push mechanisms, portals, switches, rotating sections, energy routing and magnetic polarity.

The energy core travels through the maze and pauses at authored interaction checkpoints. Players can inspect and change the environment without timers or reaction pressure, then resume the journey.

## Start here

1. `docs/01_Master_GDD.md`
2. `docs/02_Core_Gameplay_and_Checkpoints.md`
3. `docs/03_Mechanics_Bible.md`
4. `docs/04_Technical_Architecture_Godot.md`
5. `docs/05_Hybrid_2D_3D_Presentation.md`
6. `docs/06_Visual_Identity_and_UI.md`
7. `docs/07_Campaign_and_Worlds.md`
8. `docs/08_Level_Design_and_Solver.md`
9. `docs/14_Claude_Code_Implementation_Guide.md`

## Confirmed decisions

- Hybrid board presentation.
- Core movement pauses at authored checkpoints.
- Godot 4.x.
- Experimental launch mechanic scope: all eight systems are included in the design vision.
- High-end custom UI and premium 3D art direction.
- Android first.
- Quality-first development.
- 50 campaign levels: 30 free + 20 premium.
- Daily Puzzle included.
- Offline-first campaign.

## Important implementation philosophy

- Puzzle rules are simulated on a discrete 2D grid.
- The 3D board is a visual representation of the simulation state.
- The 2D UI is a separate layer.
- Godot's real-time physics engine must not determine puzzle outcomes.
- All puzzle actions are deterministic, inspectable and reversible where practical.
- The player is never required to react within a countdown.

## Visual asset note

`assets/` contains generated concept boards, cropped visual references, world concepts, UI direction and mechanism overviews. These are **art-direction references**, not final production meshes, sprites, logos or usable UI screens. Some concept-board text may be imperfect; use the written specifications as authoritative.

## Folder map

- `docs/` — full Markdown design and production documentation.
- `assets/concept_boards/` — complete visual reference boards.
- `assets/worlds/` — seven world visual concepts.
- `assets/mechanics/` — mechanic visual concepts.
- `assets/ui/` — screen and hybrid-board concepts.
- `assets/icons/svg/` — scalable custom mechanic glyphs.
- `design/level_concepts/` — level brief templates.
- `data/levels/` — example level data.
- `data/daily/` — daily schedule template.
- `godot_project/` — intended Godot project layout placeholder.
- `tests/` — QA and test planning.

## First milestone

Build one vertical-slice level with:
1. A 2D grid state model.
2. A 3D isometric board renderer.
3. A moving energy core.
4. One authored checkpoint.
5. Gravity and push interactions.
6. Pause, preview, resume, undo and restart.
7. Headless tests proving deterministic outcomes.

Do not build all 50 levels, billing or advertising before this slice is validated.
