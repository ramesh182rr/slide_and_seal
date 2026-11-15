# 01 — Master Game Design Document

**Title:** Slide & Seal  
**Subtitle:** Interactive Mechanical Labyrinth  
**Version:** 2.0  
**Status:** Revised design baseline  
**Engine:** Godot 4.x  
**Platform:** Android first

## 1. High concept

Slide & Seal is a premium-feeling interactive mechanical logic puzzle. Players explore a modular labyrinth and manipulate its physical systems to guide a geometric energy core to a sealed destination.

The player changes the environment rather than directly steering a character. The core travels along deterministic routes and pauses at deliberately authored interaction checkpoints. At these points, the player can change gravity, push structures, configure portals, activate switches, rotate maze sections, route energy and alter magnetic polarity.

The puzzle is about understanding how connected systems behave and choosing the right sequence of changes.

## 2. Product promise

**Easy to understand. Deep to master. Beautiful to explore.**

The first minute should communicate:
- There is a maze.
- There is an energy core.
- There is a destination.
- Mechanisms change the maze.
- The core travels when the player runs it.
- At marked checkpoints, the core pauses so the player can solve the next part.

No tutorial should require reading a long explanation before the player can act.

## 3. Confirmed decisions

| Area | Decision |
|---|---|
| Board presentation | Hybrid 2D simulation + 3D isometric board + 2D UI |
| Core movement | Travels and pauses at authored checkpoints |
| Engine | Godot 4.x |
| Launch mechanic scope | Experimental set: all eight mechanics designed |
| Platform | Android first |
| Visual standard | High-end custom UI and art direction |
| Campaign | 50 levels: 30 free + 20 premium |
| Daily mode | Included |
| Development priority | Quality-first |
| Connectivity | Offline-first campaign |

## 4. Core pillars

1. **Mechanical discovery:** players learn how systems interact.
2. **Predictability:** identical state + action always produces identical result.
3. **Agency without pressure:** checkpoints pause the core; no reflex tests.
4. **Readable spectacle:** beautiful 3D presentation never obscures puzzle logic.
5. **Layered mastery:** simple early interactions grow into multi-system puzzles.
6. **Premium craft:** custom visual identity, animation, sound and interface.

## 5. Core gameplay loop

1. Observe the maze, core, destination and mechanisms.
2. Inspect available controls and interaction checkpoints.
3. Manipulate one or more mechanisms.
4. Preview the consequences where supported.
5. Run or resume the core.
6. The core travels deterministically.
7. At the next authored checkpoint, it pauses.
8. The player changes the environment and resumes.
9. The core reaches the destination and completes the seal.

## 6. Player experience

The game is not a race. There are no countdowns, energy timers or required fast reactions. The player may take as long as needed at a checkpoint.

The core may move with animated motion between checkpoints, but the simulation resolves the complete travel segment deterministically. Animation is presentation only.

## 7. Eight mechanic systems

1. Gravity Shift.
2. Push Pulse.
3. Portal Network.
4. Switches & Seals.
5. Rotating Sections.
6. Energy Routing.
7. Magnetic Polarity.
8. Energy Core and checkpoint travel.

See `03_Mechanics_Bible.md` for proposed rules and unresolved design decisions.

## 8. Campaign

50 handcrafted campaign levels across seven worlds:
- World 1: The Awakening — 1–6.
- World 2: Gravity Works — 7–12.
- World 3: The Push Protocol — 13–18.
- World 4: Portal Nexus — 19–24.
- World 5: The Sealed Chambers — 25–30.
- World 6: The Shifting Labyrinth — 31–40.
- World 7: The Final Machine — 41–50.

Levels 1–30 are free. Levels 31–50 are unlocked through the premium full-game purchase.

## 9. Daily Puzzle

Daily Puzzle is available to free and premium players. Use handcrafted, prevalidated puzzle data and a pre-authored schedule. Target 90 puzzles at launch. Daily content can focus on a featured mechanic or combination. The same simulation engine must power campaign and daily content.

## 10. Progression and scoring

Recommended:
- One star for completion.
- Two stars for meeting a designer move/action target.
- Three stars for a verified optimal or best-known solution target.

Do not label a score “optimal” unless the solver proves optimality. Progression must not require three stars.

Track mechanism actions and core travel segments separately from elapsed real-world time.

## 11. Monetization

Recommended:
- 30 free campaign levels.
- One-time premium unlock for levels 31–50.
- Daily Puzzle remains free.
- Optional rewarded hint ads only.
- No forced interstitials during gameplay.
- No subscriptions or consumable energy at launch.

Price points are hypotheses and should be tested in Google Play Console. A simple premium unlock that also removes ads is preferable to confusing overlapping purchases.

## 12. Accessibility and UX

- Reduced motion.
- Adjustable audio and haptics.
- High-contrast mode.
- Shape and symbol cues in addition to color.
- Clear selected-mechanism state.
- Optional route and mechanism preview.
- Large touch targets.
- No timed decisions.
- Undo/restart with predictable behavior.

## 13. Quality bar

- Deterministic simulation.
- Same rules used by gameplay, preview, hints, solver and validator.
- Every shipped level has a validated solution.
- Undo restores all puzzle-relevant state.
- No gameplay state changes from animation callbacks.
- No input accepted during core transit unless a level explicitly defines a safe interruption.
- Save data is versioned and recoverable.
- 3D presentation is performant on target Android devices.

## 14. Success measures

Track privacy-conscious events:
- Level start/completion/abandonment.
- Mechanism interactions.
- Checkpoint reached.
- Hint request/use.
- Daily start/completion.
- Premium store view and purchase.
- Crash-free sessions and performance.

Set numeric targets only after external playtesting and soft launch.

## 15. Design risks

- Eight mechanics can overwhelm new players. Mitigate with one-mechanic teaching worlds.
- 3D visuals can obscure grid logic. Mitigate with a clear top-down/isometric camera, outlines and preview.
- Core movement can feel like a passive cutscene. Mitigate with meaningful checkpoints and player-authored changes.
- Solver complexity can grow quickly. Mitigate with small boards, canonical state keys and incremental mechanic rollout.
- High-end visuals can hurt Android performance. Mitigate with modular meshes, baked lighting, controlled transparency and device profiling.
