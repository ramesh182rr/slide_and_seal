# 18 — Open Design Decisions and Prototype Questions

These items need validation during the first vertical slice. The pack contains recommended defaults, but playtesting may change them.

1. **Core route model:** explicit route graph versus deterministic pathfinding through currently open cells. Recommended: explicit authored route graph for early levels; add dynamic pathfinding only when a mechanic needs it.
2. **Checkpoint placement:** fixed authored cells, mechanism-triggered checkpoints or both. Recommended: authored cells plus optional trigger conditions.
3. **Gravity scope:** global or local. Recommended: local zones first, global only in dedicated levels.
4. **Push behavior:** one-cell push or push-until-blocked. Recommended: one-cell standard; special lanes may use longer push with clear visuals.
5. **Portal compatibility:** core only or movable objects too. Recommended: core and explicitly tagged objects.
6. **Rotation collision policy:** reject invalid rotation rather than pushing entities automatically.
7. **Magnetic resolution:** one discrete pulse per action rather than continuous force.
8. **Energy routing loops:** stop and report loop; never hang simulation.
9. **Undo boundary:** allow undo across checkpoint travel segments or only mechanism actions. Recommended: allow undo of committed actions and provide a clear “rewind to checkpoint” option if full segment history is retained.
10. **Portrait vs landscape:** prototype both; default portrait unless board readability strongly favors landscape.

Record final decisions in `docs/` before implementing production content.
