# Changelog

All notable changes to Slide & Seal are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are dated (YYYY-MM-DD).

## [Unreleased]

### 2026-11-16 — M13: No more freezes; a 3D environment for each world

Owner report: switching between worlds lags, and the game lags a bit overall. Owner request: optimise further, and use the supplied reference images to build immersive 3D worlds.

**Fixed: freezes** (desktop, Compatibility renderer, 1080×2400)
- **Cause:** every board made its own materials. In the Compatibility (OpenGL) renderer a shader compiles synchronously on first draw and is released when its last material is freed. Each world switch or level load therefore freed and recompiled every shader: about 1 s per world switch and 0.45 s per level load on desktop, worse on a phone.
- **`MaterialLibrary`'s cache is now static.** Its keys include every parameter, so equal requests share one material for the whole run and compiled shaders stay alive.
- **`ShaderWarmup`:** behind the startup splash, it renders off screen one real gameplay scene and one diorama per world (including the showcase boards), so every shader variant compiles before play. The splash holds its opening frame with a slim loading bar until this finishes; taps are ignored while it loads.
- **One shared diorama:** Home and Campaign share one `DioramaView`, owned by `AppRoot`. It caches one board per world, and the warm-up fills it, so paging through worlds never rebuilds or compiles anything.
- **Results:**

  | | Before | After |
  |---|---|---|
  | World switch | 830–990 ms | no frame over 25 ms |
  | Level load | 450 ms | 30–48 ms |
  | Campaign open | 46 ms | 34 ms |

**Changed: phone settings**
- The 3D view renders at 80% resolution on phones (`rendering/scaling_3d/scale.mobile=0.8`), with the same in the dioramas. UI and text stay at full resolution. This is about 36% fewer 3D pixels per frame.
- Frames are capped at 60 fps on phones (`application/run/max_fps.mobile=60`). The frame rate stays steady, and 120 Hz screens no longer overheat and throttle.

**Added: world environments** (`WorldTheme.Style`, built by `IslandDecor`)
- **World 1, The Awakening:** the mossy floating island (unchanged).
- **World 2, Gravity Works** (ice chamber reference):
  - a frozen chamber of stacked ice blocks, with snow caps, icicles, frost pillars with crystal crowns, and falls of frozen light
  - ice flagstones around the board, on a glacier rock
  - an ice cave sky with stalactites and spires
- **World 3, The Push Protocol** (industrial reference):
  - a foundry deck with a riveted frame, pipes with flanges, glowing vents and pressure tanks
  - support legs down into a glowing lava pool
  - orange seams between the floor plates
  - a sky of smoke stacks
- **World 4, Portal Nexus:** an island with four standing portal rings, one at the middle of each edge.
- **World 5, The Sealed Chambers:** a temple island with gold-capped columns and a great seal ring turning beneath it.
- **World 6, The Shifting Labyrinth** (neon ruins reference):
  - dark tech masonry on stepped plinths, with magenta circuit seams
  - circuit pillars with teal and magenta strips, and floating tech cubes
  - a crimson haze with neon towers
- **World 7, The Final Machine** (space maze reference):
  - an obsidian monolith split by glowing lava veins, with broken teeth along its rim
  - a deep-space sky with a nebula
- **Floors:** each world has its own floor finish (gloss, metalness), and some have a glow showing through the gaps between tiles.
- **Camera-side hiding:** tall scenery on the camera's side (chamber walls, pillars, tanks, portals) is hidden so it never blocks the board. It updates as the view turns, in gameplay and in the dioramas.
- **Scenery cost:** static scenery is merged into one mesh per material and casts no shadows. Draw calls stay at 99–184 per frame.
- **`MeshKit`:** new cylinder, cone and torus primitives. **`Backdrop`:** distant silhouettes per style.

**Added: the seven-world campaign**
- The campaign pages through all seven worlds of docs/07. Worlds 3, 4 and 7 have no levels yet, so they show "Coming soon" with a live preview of their environment.
- The previews are display-only boards in `data/showcase/`. They are not in the catalog and never playable, and the export includes them. Decision P-027.

**Verified**
- 342 tests pass. 3 are new: every style builds; the ice chamber hides the right walls at two camera angles; equal material requests share one material. The navigation and catalog tests also gained checks for the seven pages, "Coming soon" and the showcase boards.
- The export completes with exit 0 and no errors or warnings. The APK holds 15 levels and 3 showcase boards, and no tests.
- On the emulator, with the real APK: splash with loading bar → Home → Campaign → paging through all seven worlds. No crash and no game errors in the log.

**Not verified**
- The frame rate on a real phone. The emulator renders in software.

**Known limitations**
- The environments are built from code. Sculpted, textured models from a 3D artist would add further detail.

### 2026-11-16 — Release build: app icon, startup screen, Compatibility renderer

Owner report: the APK showed a black screen on the Android emulator. Owner request: add an app icon and a startup screen, and build an APK without errors or crashes that plays smoothly.

**Fixed**
- **Black screen on the emulator.** The game was running, but the emulator's software Vulkan driver could not present frames ("Couldn't present to Vulkan queue"); real phones were not affected. Android now uses the Compatibility (OpenGL ES 3) renderer (D-036, owner-approved), and the real APK displays on the emulator.
- **Export error "No project icon specified"** is gone: the export now completes with no errors or warnings.

**Added**
- **App icon:** a glowing hexagon around an isometric cube (the energy core's chamber) on a dark teal gradient. Android launcher icons cover every density, including adaptive foreground/background layers and a monochrome layer for themed icons.
- **Startup screen:**
  - Android's boot splash shows the emblem and wordmark on the game's dark background.
  - An in-game reveal (`SplashOverlay`) then continues seamlessly from it: the emblem brightens, a halo widens and the tagline fades in, then it fades out over Home (about 1.6 s).
  - A tap skips it, and reduced motion shortens it to a quick fade. It is skipped when `instant_playback` is on (tests).
- **`BrandMark`:** one emblem drawing shared by the icon generator, the boot splash, the reveal and Home.
- **`tools/generate_brand_assets.gd`:** regenerates the icon and splash PNGs in `game/assets/brand/` from code. No external art.

**Changed**
- **Renderers:** Android uses the Compatibility renderer with 2x MSAA. Desktop development still uses the Mobile renderer.
- **The core no longer carries a point light.** In Compatibility every object a light reaches is drawn again. An additive glow pool on the floor gives the same look for free.
- **Draw calls** (desktop, same frame, Compatibility): The Awakening 160, Gravity Works 178. Before the first performance fix they were 510 and 636.
- `CLAUDE.md`: the renderer rule, the emulator notes and the brand-asset command are updated.

**Verified**
- 338 tests pass (1 new: the reveal appears over Home, a tap skips it, and tests skip it).
- The export completes with exit 0 and no errors or warnings. The APK holds 15 catalog levels and no retired levels, tests or tools.
- On the emulator, with a fresh install of the real APK:
  - The launcher icon appears in the app drawer.
  - Boot splash → reveal → Home.
  - Continue → level 1 → Run → Resume → seal complete (3 stars).
  - Next level → level 2 → Run → system Back → "Leave this puzzle?" dialog.
  - It all ran in one app process: no crash and no game errors in the log.

**Not verified**
- The frame rate on a real phone. The emulator renders in software, so its speed says nothing about a device.

### 2026-11-16 — M11: Art pass: themed worlds, floating islands and a new UI

Owner request: the worlds and screens looked too plain next to the product concept art, and should feel realistic and immersive. Everything is presentation only: no simulation, rule or level data changed.

**Added**
- **`WorldTheme`:** an art direction per world (docs/07 world bible): sky, stone, foliage, crystal, light and fog colours, plus an accent colour, a title and a one-line tagline. Meaningful energy colours (route cyan, seal mint, gate amber/pink) stay in `Palette`, so a mechanism looks the same in every world.
- **`MeshKit`:** procedural geometry (beveled blocks, floating rock islands, crystal clusters). Its variation comes from a hash of integer coordinates; nothing is random.
- **`IslandDecor`:** the board now stands on a floating rock island, with moss or crystals depending on the world, and drifting rock fragments around it. They are kept below and beside the board, never on a cell. The drift is idle decoration only.
- **`Backdrop`:** a painted sky (gradient, nebula, stars, a planet, distant floating islands, vignette). It is painted once into an off-screen texture, so it costs one draw call per frame. It sits behind the 3D board (canvas background) and every menu.
- **`DioramaView`:** a live, slowly turning miniature of a world's level and island. It is used on Home and on the campaign screen, and never runs a puzzle.
- **Home → Continue:** opens the first unlocked level not yet sealed (`AppRoot.next_level_to_play()`). Campaign and Settings stay. Decision P-026.

**Changed**
- **Board look:**
  - Beveled, textured stone tiles and walls, with per-tile shade variation and some mossy tiles in World 1. Each wall block has a thin glowing seam.
  - A thick plinth with a glowing edge line.
  - The route is now an inlay: diamond studs and glowing channels cut into the stone.
  - Checkpoints became medallions with a soft glow pool.
  - The seal became a hexagonal pad with a turning inner ring and a column of light.
  - The core became a translucent crystal with a bright heart and an orbit ring.
  - Blocks became beveled metal crates with lit corner edges, so a block that can move never reads as a wall stub. Pushable blocks keep a cyan top mark.
  - Gates became tinted metal doors (amber, or pink when inverted) with a glowing band.
  - Toggle levers became pedestals with an arm that tips over when switched.
- **Materials** (`MaterialLibrary`):
  - Surfaces use two shared procedural noise textures (albedo grain and a normal map) generated at run time. There are no texture files.
  - New material helpers: `surface`, `glow` (unshaded energy) and `crystal`.
- **Stage:**
  - Filmic tonemapping, stronger additive glow, height fog that fades the island into the sky, and a cool fill light.
  - Light, ambient and fog colours follow the world. Each gameplay scene themes its own copy of the environment.
- **UI design system** (`UiTheme`):
  - Glass panels with metallic borders and soft shadows.
  - Glowing primary buttons.
  - A bolder display face for titles (a variation of the built-in font; no new font files).
  - The completion card, mechanism panel and dialogs use the new panels.
- **Icons:** `IconButton` draws more vector icons (back, undo, restart, play, settings, lock, grid) and can show an icon next to text.
- **Gameplay HUD:**
  - A glass top bar: a Back arrow, the world name over the level title, and Undo and Restart icons.
  - A status card for the phase, actions and available mechanisms.
  - A full-width glowing Run/Resume button with a play icon.
  - The view controls are unchanged.
- **Campaign screen** (was a plain list):
  - One world at a time: a card with its live diorama, "WORLD n", title, tagline, and sealed and star progress. Arrows or a horizontal swipe change world.
  - Below the card, a 3-column grid of level tiles: number, title, and stars with the best result, or a lock with "Locked".
  - It opens on the world that holds the next level to play.
- **Home:** the World 1 sky and diorama, a hexagon-and-cube emblem and the wordmark, then Continue / Campaign / Settings.

**Performance** (desktop, same frame as the previous entry):
- The Awakening: 88 → 134 draw calls. Gravity Works: 123 → 161. Both are well below the 510 and 636 that caused the lag.
- Small glowing parts cast no shadows. The island and fragments cast none.
- The sky would have cost about 200 draw calls if drawn live, so it is painted once into a texture instead.

**Verified**
- Desktop screenshots of all 12 World 1–2 levels, Home and three campaign pages.
- The Android emulator, using a throwaway copy switched to the OpenGL Compatibility renderer, because the emulator cannot present Vulkan. The full flow worked with no game errors in the log: Home (live diorama) → Campaign → world arrow → World 2 card → back → level 1 → Run → Resume → seal complete (3 stars, "New best!") → Level select, which then showed 3/45 stars, 1/6 sealed and level 2 unlocked.

**Tests:** 3 new (Continue opens the next level; the campaign pages through worlds and clamps; the board is themed for its world and builds its island). 337 pass.

**Known limitations**
- This is procedural art, not modelled assets. It moves much closer to the concept boards, but the sculpted ruins, waterfalls and painted detail of the concept art need a 3D artist's meshes and textures.
- Worlds 3, 4 and 7 have themes but no levels yet.
- Fonts are still the built-in face. A licensed display font is a later decision (docs/06 §7).
- The frame rate on a real phone is unverified. The emulator check used the OpenGL Compatibility renderer.

### 2026-11-16 — Performance: static batching and cheaper shadows

Owner report: the game lags a little on a real phone.

**Changed**
- **Static batching:** `BoardRenderer3D` merges floor tiles, walls and route inlays into one mesh per parent and material (`Static_*` nodes). Turntable contents keep their own batches on the section pivot, so they still turn.
- **Shadows:**
  - The flat floor, route and base no longer cast shadows; walls, blocks, gates and the core still do.
  - The key light uses one orthogonal shadow split (was four), with a 60-unit maximum distance.
  - On mobile, the shadow map is 2048 px with low soft-shadow filtering.
- **Result** (measured on desktop, same frame):
  - The Awakening: 510 → 88 draw calls (327 → 112 nodes).
  - Gravity Works: 636 → 123 draw calls.
  - Screenshots look unchanged.
- `test_quarter_turn_scene` now checks the turntable's merged floor and track batches instead of counting separate tile nodes.

**Not verified**
- The frame rate on a real phone. The emulator cannot display Vulkan, so the gain on the device still needs the owner's check.

### 2026-11-15 — M10: Worlds 1–2 redesigned; inverted gates; gameplay Back button

**Added**
- **Inverted gates** (D-035): the optional `inverted` gate field in schema v3. An inverted gate is closed while all its switches are on, and open otherwise.
  - The simulator, solver and validator needed no change in shape; `SwitchGateResolver.is_gate_open` negates the result.
  - Inverted gates are pink and labelled with "¬" (e.g. "¬C"), and tapping one explains it.
  - 5 new unit tests.
- **Back button** in the gameplay HUD (P-025). It asks before leaving an unfinished level and leaves a finished one at once. 3 new tests.

**Changed**
- **World 1 "The Awakening" redesigned** (D-033, D-034, P-023). Six levels on boards from 7×9 to 11×11, 1–4 checkpoints each, teaching levers, two-lever gates and inverted gates. Proven minimums 0/0/2/3/5/8.
- **World 2 "Gravity Works" redesigned** (D-033, P-024). Six levels on boards from 8×8 to 11×13 with column, row and tilt-chamber zones, combined with levers and gates. Proven minimums 2/4/3/3/3/5.
- All twelve levels are validator-proven with 0 dead ends. `target_actions` is the minimum up to 2, +1 for 3–5 and +2 from 6.
  - Titles follow doc 09 where the content still fits ("The First Signal", "Dormant Path", "Downward Pull", "Shift the Weight", "Sideways Field", "Stable Position", "Gravity Works").
  - New titles: "Lever and Gate", "Two Keys", "Opposite Doors" and "Held by Gates".
- Tests updated for the new level data:
  - level 1 now has a checkpoint
  - the "worse replay" progress test moved to level 3, which has the old level 6's two levers and decoy
- README status updated.

**Removed**
- The previous World 1–2 drafts (P-020, P-021) were replaced in place. The level ids are unchanged, so saved progress still maps to the same slots, but saved best scores now refer to the new puzzles.

**Verified**
- 334 tests pass. `tools/validate_levels.sh`: 15 levels, 0 failed.
- The Android debug APK (`build/android/slide_and_seal_debug.apk`, Vulkan/Mobile) contains the 15 catalog levels and no retired levels or tests. It starts on the Pixel 8 emulator with no script errors; the emulator still cannot display Vulkan.
- With the Compatibility diagnostic build on the emulator:
  - The level list shows the new titles, with only level 1 open on a fresh profile.
  - In level 1, real taps on rotate and zoom in changed the view.
  - Back opened "Leave this puzzle?", and Leave returned to the level list.
  - Godot logged 0 errors.

**Known limitations**
- At the default 45° view, boards are limited by screen width, so there is unused space below the board. Zoom helps.
- Lever labels that list many gates (e.g. "A D ¬C ¬F") are small at the default zoom.
- Gravity blocks still look like fixed steel (art gap from P-021).

### 2026-11-15 — M9a: board view controls (rotate, zoom, pan)

**Added**
- **Free view rotation, zoom and pan** of the board (D-031, D-032, P-022). The view is presentation only and never changes the puzzle.
  - **Touch:** pinch zooms, two-finger twist rotates to any angle, two-finger drag pans.
  - **Buttons:** a right-edge column with rotate counter-clockwise/clockwise (animated 90°), zoom in/out and reset view. The icons are drawn in code (`IconButton`).
  - **Desktop:** the mouse wheel zooms, Q/E turn, R resets, and trackpad pinch and scroll work.
- `CameraRig`: `rotate_view`, `turn_view`, `zoom_by`, `pan_by_screen`, `reset_view` and a `view_changed` signal. Zoom is clamped to 1×–3×, and the pan keeps the board on screen.
- Swipe directions and the arrow pad follow the live view, and picking works at any angle and zoom.
- Tests: `test_camera_controls.gd` (12 tests) covers buttons, wheel, keys, pinch, twist direction, two-finger pan, clamping, reset, picking after a view change, and that a gesture never leaves a stray tap or push.

**Fixed (during development)**
- The twist and the turn buttons first rotated the board against the fingers and the icon. A test caught this before it shipped.

**Known limitations**
- Gestures were tested with synthetic touch events only. A real multi-touch check needs a device, since the emulator only offers a limited pinch.
- At high zoom the board can sit under the top labels and the button column.
- The view resets on each level and is not saved.

### 2026-11-15 — Campaign: World 2 "Gravity Works" drafted; Android emulator play test

**Added**
- **World 2 levels** `world_02_level_007` to `world_02_level_012`:
  - Downward Pull
  - Shift the Weight
  - Sideways Field
  - Gravity Chamber
  - Stable Position
  - Gravity Works
- All six are validator-proven (minimums 1/1/1/2/2/3, 0 dead ends) and recorded in `optimal_actions`. They are in the catalog after World 1 (P-021).

**Changed**
- The Android export now excludes `data/levels/retired/*`. Verified: the APK contains the 15 catalog levels and no retired ones.

**Verified on the Pixel 8 emulator** (Android 15, Compatibility-renderer diagnostic build; the emulator still cannot display Vulkan on this Mac)
- Home and Level select on a fresh profile: only level 1 open, Worlds 1 and 2 listed, scrolling, the header clear of the cutout.
- Level 1 played by touch (Run): the completion card with ★★★, "Target met" and "New best!".
- Next level opened level 2.
- **Persistence:** the save file was written on the device (`files/progress.json`). After a force-quit and relaunch, level 1 showed "Best 0 ★★★" and level 2 was unlocked.
- **Level 7 by real taps:** Run, tap the gravity zone, the panel with the current direction disabled, tap down, Resume, completed ★★★. Godot logged 0 errors.
- To reach level 7 without hand-playing levels 2–6, a test save marking World 1 complete was written to the emulator's diagnostic install only.

### 2026-11-15 — Campaign: World 1 "The Awakening" drafted; demo levels retired

**Added**
- **World 1 levels** `world_01_level_001` to `world_01_level_006`, following the doc 09 briefs:
  - The First Signal
  - Dormant Path
  - First Launch
  - Safe Stop
  - Resume Sequence (one lever)
  - The Awakening (two checkpoints and levers, plus a decoy lever)
- All six are validator-proven (minimums 0/0/0/0/1/2, 0 dead ends) and recorded in `optimal_actions`.

**Changed**
- **Catalog:** World 1 is now these six levels, then Reflector Logic (#28), Quarter Turn (#32) and Opposite Attraction (#34) (D-030).
- `world_01_level_001` was redesigned: it is now a straight route with no checkpoint, since doc 09 #1 covers route, core and destination only.
- **Retired** the vertical slice and the switches/portals showcase to `game/data/levels/retired/`. They are kept for tests and reference, outside the catalog and validator.
- The gameplay scene's default level is now Level 1. Scene tests that exercise rich mechanics load the retired slice explicitly.
- App-flow and progress tests use real campaign levels. The replay test now uses "The Awakening" with the decoy lever as the wasted move. A progress test helper that pressed Run twice (the second silently refused) now presses once and asserts it.
- README and dev-option examples point at `world_05_reflector_logic`.

**Verified**
- Screenshots of all six World 1 levels. Level 6's decoy gate C was moved off the route after the isometric view made it look on the path.
- All 9 catalog levels validate; 314 tests pass.

**Known limitations**
- Level select numbers follow catalog order (World 1 is 1–6, then the three later demo levels as 7–9) until the worlds in between exist.

### 2026-11-15 — Settings screen

**Added**
- **`SettingsScreen`** (Home → Settings):
  - **Reduced motion:** saved, and applied to every level as instant playback
  - **Reset progress:** behind a confirmation dialog, saved immediately; settings are kept
  - Back closes the dialog, then returns home
- **`SettingsStore`** (`user://settings.json`, schema 1).
- **`SafeJsonFile`:** the crash-safe versioned write (temp file, then `.bak`, then rename) and the recovering read (set aside as `.corrupt`, then backup, then fresh), extracted from `ProgressStore`, which now uses it. `ProgressStore.reset()`.
- **`ConfirmDialog`:** a general modal confirmation. `LeaveDialog` is now a thin subclass, and its API and tests are unchanged.
- **Tests:** 6 new, bringing the suite to 314. They cover:
  - settings round trip and recovery from a corrupt file
  - Home → Settings → Back
  - reduced motion persisting across restarts and switching gameplay's instant playback on and off
  - reset needing confirmation (cancel keeps progress)
  - a confirmed reset erasing and saving progress while keeping settings
  - Back unwinding the dialog first

**Changed**
- All app-level tests now use scratch settings paths too. `TestFiles.remove_progress` refuses both real player files.

**Fixed** (during review)
- The reduced-motion switch first used the default toggle icon, a tiny dot that did not show its state. It is now a toggle with an explicit coloured "On"/"Off".

**Not included (by design):** sound, haptics, UI scale and high contrast. They will be added together with those features, so no setting does nothing.

### 2026-11-15 — M8b: Magnets in 3D, plus "Opposite Attraction" — every mechanic playable

**Added**
- **Level** `game/data/levels/world_06_opposite_attraction.json`, "Opposite Attraction" (doc 09 #34), in "The Shifting Labyrinth":
  - block K (+) must reach a plate two cells away
  - each flip moves it one cell and one magnet only alternates attract/repel, so both magnets are needed
  - the validator proves a minimum of 2 with 0 dead ends
- **Visuals:**
  - magnets (body plus polarity-coloured cap plus large symbol)
  - polarised blocks (coloured band plus symbol)
  - colour is always paired with + / − (true minus sign U+2212)
- **Interaction:**
  - tap a magnet for "Magnet (±)" with "Switch to ∓" (hold to preview, release to flip); the hint states the effect
  - tapping a magnetic block explains it
  - HUD: "Magnetism" and "Tap a magnet"
- **Playback:** one pulse's moves play together.
- **Tests:** 5 Opposite Attraction scene tests, bringing the suite to 308. They cover:
  - symbol and colour on magnets and blocks
  - explanatory taps
  - the magnet panel with preview, committed through the real button signal, refreshing in place
  - solving through taps
  - one magnet alone only alternating

**Changed**
- **Navigation tests are now catalog-driven** (order, next-level chain, level-select listing, and the "last level" check playing the solver's own solution) instead of hard-coding the level list, which broke with every new level.
- Switch and portal labels moved above block height, after screenshots showed a block's polarity label colliding with the plate label beneath it.

**Verified**
- Windowed screenshots: the initial board, the flip preview, both magnets flipped with K on the plate and gate A open, and completion. Review led to the larger U+2212 minus and the label heights.
- All six levels validate.

**Known limitations**
- Placeholder art. There is no pulse effect beyond the block moves.

### 2026-11-15 — M8a: Magnetic Polarity (rules) — all eight mechanics now in the rules engine

**Added**
- **Magnets** (`mechanisms.magnetic_fields`, `MagnetDefinition`) and block `polarity` (`+` / `-`; neutral when omitted).
- **`PuzzleAction.flip_magnet`** (mechanism `magnetic_polarity`, D-026): switches polarity and fires one pulse (`MagnetResolver.pulse`), counted as one action. Afterwards gravity settles and the gate rules apply.
- **Pulse rules** (D-027 – D-029):
  - it reaches along the magnet's row and column until a wall, closed gate or solid fixture, passing over the core
  - only the first block per line reacts (neutral blocks shield)
  - a polarised block moves one cell toward (opposite) or away (like) if that cell is free
  - pulse only, never continuous
- **Solid fixtures:** magnets are solid and stop beams.
- **State key:** magnet polarity and block polarity.
- **Loader:** magnets validated like other solid fixtures; `magnetic_objects` rejected with a pointer to `polarity`; allowing `magnetic_polarity` requires a magnet.
- The solver includes magnet flips.
- **Tests:** 20 new, bringing the suite to 303. They cover:
  - attraction and repulsion, reversing by flipping back, blocks unable to enter the magnet, the board edge
  - neutral shielding, first-block-only, walls stopping the field, all four lines in one pulse
  - the field passing over the core, which blocks cannot move onto
  - pulse-only, magnets solid and stopping beams, rejections, undo/preview/key, the solver minimum
  - 5 loader rules

**Changed**
- The "unsupported mechanism" loader test now uses `push_devices`, the only collection still unimplemented.

**Verified**
- Mutation checks: removing shielding, swapping attract/repel, and dropping the free-cell check are each caught. The first run showed two shielding tests passing by coincidence (the shielded block could not have moved anyway); both were rebuilt so the shielded block *would* move if unshielded, and they now catch the mutation.
- All five shipped levels validate unchanged.

**Known limitations**
- Rules only: magnets and polarity are not drawn or interactive in 3D yet.
- Magnets inside rotating sections are not supported yet.

### 2026-11-15 — M7b: Energy routing in 3D, plus "Reflector Logic"

**Added**
- **Level** `game/data/levels/world_05_reflector_logic.json`, "Reflector Logic" (doc 09 #28), placed after the showcase in "The Sealed Chambers":
  - an emitter, two mirrors that both need flipping, and a receiver powering the gate on the core's corridor
  - the validator proves a minimum of 2 with 0 dead ends
- **`MechanismFixtures3D`:**
  - emitter (block plus nozzle), mirror (slab on a base, turned per orientation), receiver (pedestal plus crystal lamp)
  - beams drawn from `EnergyResolver.trace`, rebuilt after every committed state, with a stub to the obstacle that stopped them
  - `beam_signature` for preview comparison
- **Preview:** ghost beam paths (mint) whenever a previewed action changes the beams.
- **Playback:** mirrors swing to their new diagonal.
- **Interaction:**
  - tap a mirror for a "Flip mirror" panel (hold to preview, release to flip)
  - tapping a receiver or emitter explains it
  - HUD: "Energy" and "Tap a mirror"
- **Tests:** 5 scene tests, bringing the suite to 283. They cover:
  - mirrors, receiver lamp and beam drawing matching state, including after undo
  - the explanatory taps and "not before the checkpoint"
  - the flip panel with its beam preview, committed through the real button signal
  - solving the full level through taps

**Changed**
- Catalog: Reflector Logic inserted before Quarter Turn, and the navigation tests updated.
- The mirror panel title no longer shows `/` or `\`, since the isometric view would make it misleading.

**Verified**
- Windowed screenshots: the initial beam, the ghost preview of the new path, both mirrors flipped with receiver A lit and gate A open, and completion.
- All five levels validate.

**Known limitations**
- Placeholder art. Beams are plain glowing boxes, with no particles or animated flow.
- Beams redraw once a playback finishes rather than animating along their new path.

### 2026-11-15 — M7a: Energy Routing (rules)

**Added**
- **`EnergyResolver`:** traces beams from active emitters.
  - Beams stop at walls (including turned section walls), closed gates, blocks, emitters and the board edge.
  - They bend at reflectors (`ReflectorDefinition.reflect`) and end on the first receiver.
  - A loop guard and a step bound mean tracing can never hang.
- **Power:** powered receivers are computed bottom-up to a stable result (`update_power`), so chains work: a receiver can open a gate on another beam's path or start another emitter. Power is re-evaluated in every settle pass and in the initial state.
- **Switch kind `receiver`** (D-024): on while powered, so gates, portals and emitters can require it. All gate rules apply.
- **Emitters** (`mechanisms.energy_emitters`) with optional `requires` (D-025); **reflectors** (`mechanisms.reflectors`, `/` or `\`).
- **`PuzzleAction.flip_reflector`** (mechanism `energy_routing`, D-022), counted as one action. Mirror orientation is in the state key.
- **Solid fixtures:** emitters and reflectors block blocks and the core (`LevelDefinition.is_solid_fixture`, used by `is_wall_at` and gravity). Beams use the separate `is_terrain_wall_at`.
- **Loader:** energy fixtures validated (cells, routes, sharing, requires, blocks inside fixtures, sections). Allowing `energy_routing` requires a reflector, and allowing `rotating_sections` requires a section.
- The solver includes reflector flips.
- **Tests:** 20 new, bringing the suite to 278. They cover:
  - the reflection table, initial and flipped beams, flipping opening the gate and completing the level
  - blocks and closed gates stopping beams, switch-controlled emitters, power chains
  - solidity, never closing a gate on the core when a beam is cut
  - rejections, undo/preview/key, the solver minimum
  - 8 loader rules

**Changed**
- Two loader tests updated: the switch-kind message now lists `receiver`, and the "unsupported mechanism" example now uses `magnetic_fields`.

**Verified**
- Mutation checks: transparent blocks, single-pass power and no power refresh in settling are each caught.
- All four shipped levels validate unchanged.

**Known limitations**
- Rules only: beams, emitters, mirrors and receivers are not drawn or interactive in 3D yet.
- Energy fixtures inside rotating sections are not supported yet.

### 2026-11-15 — D-021: track pieces are entered only when passable

**Changed**
- **Rule:** at a junction the core enters a track piece only if it can pass straight through:
  - the piece's far end lines up with a corridor, and
  - every piece cell plus that corridor's first cell is free.

  Otherwise it waits outside the section, where it can still be turned (`PuzzleSimulator._can_pass_through`). The owner approved "enter only when both ends connect"; the free-passage condition extends it so a block cannot strand the core either.
- **Quarter Turn** now validates with **0 dead ends**. The overshoot trap is gone.
- **Tests:** the D-019 safeguard ("no turning with the core inside") is now tested with a hand-built state, since normal play can no longer put the core inside a section. The undo test no longer relies on a stranded core.

**Added**
- 3 tests: waiting outside when the exit corridor is blocked; waiting outside when a block sits on the piece; regression test for the Quarter Turn overshoot. Suite: 258. A mutation check confirmed that disabling the rule fails exactly these three.

### 2026-11-15 — M6b: Rotating sections in 3D, plus "Quarter Turn"

**Added**
- **Level** `game/data/levels/world_06_quarter_turn.json`, "Quarter Turn" (doc 09 #32), in the new catalog world "The Shifting Labyrinth":
  - a clockwise-only 3×3 turntable with an L-shaped track piece; two turns connect the corridor to the seal corridor
  - a fixed crate rides the turntable
  - the validator proves a minimum of 2
- **Renderer:**
  - section pivots carry the tiles, walls and track inlay inside each section, turned to the current orientation
  - fixed amber frame (cyan when selected) and an off-centre hub
  - preview ghosts show where track pieces and blocks would end up after a turn
- **Playback:** the platform turns smoothly, and blocks on it orbit the centre in step.
- **Interaction:**
  - tap a section to open a panel with one button per allowed direction (hold to preview, release to turn)
  - the panel explains when the core is on the section
  - HUD: "Rotation" and "Tap a rotating section"
- `MechanismPanel` action mode supports up to two buttons (`show_actions`), created once and reused.
- **Tests:** 5 Quarter Turn scene tests, bringing the suite to 255. They cover:
  - platform and crate visuals matching state, including after undo
  - the unavailable-section message
  - the clockwise-only panel and the track/crate preview, committed through the real button signal
  - solving the full level through taps

**Changed**
- Fixed (non-pushable) blocks are drawn grey steel instead of slate, to stand apart from walls.
- Navigation tests updated for four catalog levels; Quarter Turn is now the last level.

**Found by the validator during design**
- The first draft started the L already connected to the incoming corridor, so "run, run" stranded the core inside the turntable. The start orientation was changed.
- One recoverable trap remains by nature of L pieces: turning a third time and running. It is reported as 1 dead end; undo recovers. A rule alternative is raised in P-014.

**Known limitations**
- Placeholder art. The mid-turn screenshot was taken at the start of the turn, so the turning animation is covered by tests of the final platform angle rather than visual review.

### 2026-11-15 — M6a: Rotating Sections (rules)

**Added**
- **`RotatingSectionDefinition`:** square sections with quarter-turn `rotate_cell` / `authored_cell`, and per-section allowed directions (D-020).
- **`PuzzleAction.rotate_section(id, clockwise)`** (mechanism `rotating_sections`):
  - turns the section, moving the blocks inside it (one-to-one remap, `ObjectMove.Cause.ROTATION`)
  - then stabilises and applies the occupied-gate rule
  - rejected while the core is inside (D-019)
- **State:** `PuzzleState.section_turns` and `core_route_reversed`, both in the state key.
- **Track pieces** (D-017): route segments wholly inside a section turn with it.
  - The core leaves a fixed segment's open end into whichever end of a piece is currently adjacent (forwards or in reverse), then leaves the piece into the fixed segment starting beside its far end.
  - If nothing lines up, the core waits until the section is turned.
- **Rotation-aware rules:** `PuzzleSimulator.route_cell` / `is_wall_at` turn walls and route nodes inside sections (D-018). Pushes and core blocking use them.
- **Loader:**
  - parses `mechanisms.rotating_sections`
  - classifies track pieces
  - first-version limits: no switches, gates, portals, checkpoints, core start or destination inside a section
  - **validates every possible connection**: each fixed segment ends at the destination, a portal entry or beside exactly one section; no two fixed starts share a section cell; the possible-successor graph reaches the destination and every segment, with no loops
- The solver includes rotations.
- **Tests:** 23 new, bringing the suite to 250. They cover:
  - rotation geometry and its inverse
  - waiting when misaligned; clockwise (reverse travel) and counterclockwise (forward travel) connections
  - no turning with the core inside
  - walls and blocks turning, blocks outside untouched, pushes respecting turned walls
  - rejections, four turns returning to identity, undo, preview, the solver minimum
  - 9 loader rules

**Changed**
- Route linking is now validated as a graph of possible connections instead of a single fixed chain. Portal links are recorded as before. Error wording for segments that end nowhere changed accordingly, and 4 existing loader tests were updated.
- Core travel is bounded by `MAX_TRAVEL_STEPS` as a defensive guard, on top of the loader's no-loop guarantee.

**Verified**
- Mutation checks: allowing turns with the core inside, dropping reverse track travel, and ignoring turned walls are each caught.
- All three shipped levels validate with identical results.

**Known limitations**
- Rules only: sections are not yet drawn as turning platforms or interactive in 3D. The renderer would still draw track pieces at their authored orientation, and no shipped level uses sections yet.
- Switches, gates, portals and checkpoints inside sections are not supported yet.

### 2026-11-15 — Save data, progress and unlocking

**Added**
- **`ProgressStore`** (`user://progress.json`, versioned):
  - records per-level completion and best action count
  - crash-safe writes (temp file, then backup, then rename)
  - on load, unreadable or unsupported files are set aside as `.corrupt`, with fallback to the backup, then to a fresh start (P-013)
- **`Progression`:** sequential unlocking in catalog order (D-016) and stars per doc 01 §10. Three stars only when a solver-proven optimum exists.
- **Level select:** locked levels are disabled and marked "Locked"; completed levels show "Best N" and drawn stars (`StarRating`, no font-glyph dependency).
- **Completion card:** stars for this run and "New best!". `AppRoot` saves on each completion (`GameplayController.level_completed`) and passes the previous best to gameplay.
- `LevelCatalog.Entry` carries `target_actions` / `optimal_actions`.
- **Test infrastructure:**
  - `TestCase.after_each()` hook, called by the runner after every test
  - `TestFiles.remove_progress()`, which refuses to touch the real save file
- **Tests:** 13 new, bringing the suite to 227:
  - `ProgressStore`: best tracking, round trip, backup on save, recovery from a corrupt save via the backup, fresh start without a backup, unsupported schema
  - `Progression`: unlocking and stars
  - end-to-end: locks on a fresh profile, completion saving and unlocking the next level, persistence across app restarts, a worse replay keeping the record with no "New best!"

**Fixed** (during this milestone)
- The navigation tests briefly wrote to the real `user://progress.json`, once completions started saving. The files created by that run held only test completions and were removed. All app tests now use scratch save paths cleaned after each test.

**Verified**
- Windowed screenshots: a fresh level list with locks, the completion card with three stars and "New best!", and the level list afterwards (Best 0 ★★★, level 2 unlocked, level 3 locked).

**Known limitations**
- No "reset progress" option yet (a settings screen does not exist).
- Premium access (`access: "premium"`) is not enforced; all catalog levels follow the same unlock rule.
- No cloud sync (doc 17 post-launch).

### 2026-11-15 — Menu skeleton

**Added**
- **`AppRoot`** (`game/scenes/app/app_root.tscn`, now the main scene): Home → Level select → Gameplay, one screen at a time.
  - Leave and the completion card return to level select.
  - The dev `--level=<id>` option moved here.
- **`LevelCatalog`** with `game/data/catalog.json`: play order and world grouping. Each entry is loaded through `LevelLoader`, and duplicates or mismatched ids are reported.
- **Screens:** `HomeScreen` (title, tagline, Play) and `LevelSelectScreen` (levels numbered in play order under world headings; all open until save data exists).
- **`CompletionCard`** in the HUD: actions against target ("Target met" when achieved), Level select, and Next level (hidden on the last level). It appears after the completing playback, and Undo hides it.
- **Back / Escape:** level select → home, home → exit. Gameplay keeps its own Back handling.
- **`UiTheme`:** shared styling, extracted from the HUD, including `apply_safe_margins`, which level select now uses too.
- **Tests:** 10 navigation tests, bringing the suite to 214. They cover:
  - the catalog order, and every level file being listed
  - Home → Level select → Gameplay with the right level, and Leave → level select
  - the Back chain, and Back in gameplay being left to the gameplay controller
  - Next level, no Next on the last level, and Undo hiding the card

**Fixed** (during this milestone)
- The level-select resize listener was first connected through a static function, so it outlived the screen and collided on the second visit. Caught by the tests; it is now an instance method.

**Verified**
- Windowed screenshots of Home, Level select and the completion card.
- The Android export still builds, and `catalog.json` is packaged.

**Known limitations**
- No save data, progress, stars or unlocking yet.
- Placeholder screens. The doc 06 world dioramas, splash, settings and store are not built.

### 2026-11-15 — M5c: Switches, gates and portals in 3D, plus showcase level

**Added**
- **Showcase level** `game/data/levels/world_05_showcase.json`, "Sealed Passage — Showcase" (7×8). It has three beats: a lever opens gate A, block K pushed onto a plate opens gate B, and a lever powers portal 1 into a walled-off area with the seal. The validator proves a minimum of 3 actions with **0 dead ends**, and `optimal_actions` is 3.
- **`MechanismFixtures3D`:**
  - placeholder visuals for toggle levers, pressure plates, gates (closed standing / open sunk) and portals (entry swirl disc, active glow)
  - billboard link symbols (P-011)
  - state sync, and preview ghosts for gates a preview would change
- **`MaterialLibrary`:** shared material cache, extracted from the board renderer.
- **Gate animation:** gates that change rise or sink after the moves that caused them.
- **Interaction:**
  - tap a toggle switch to select it (cyan ring); the panel's new single-action mode gives a "Switch on/off" button with hold-to-preview / release-to-commit
  - tapping a pressure plate, gate or portal explains what powers it
  - the HUD availability line now separates "tap or swipe" targets from tap-only switches
- **Development level selection:** `godot --path game -- --level=<id>`.
- **Tests:** 7 showcase-scene tests, bringing the suite to 204. They cover:
  - link symbols and labels
  - fixture visuals matching state (initial, after toggle, after undo, at completion)
  - the lever panel with its gate preview, committed through the real button signal
  - explanatory taps, and the switch-availability message
  - solving the full showcase through taps and swipes

**Verified manually**
- Windowed screenshots through the whole showcase with real animation: the lever ring and panel, gate A opening, the plate pressed by K, the portal powering up, and completion.
- Review fixes: the gate-opening preview was invisible (a ghost inside the closed gate) and is now a glowing shell. The hint "Tap or swipe a switch" now reads "Tap a switch".

**Known limitations**
- Placeholder art. Gates and blocks are both cube-shaped, distinguished by colour, letter label and height.
- No portal transit effect beyond the instant jump.
- No level-select menu yet; other levels are opened with the `--level` argument.

### 2026-11-15 — M5b: Portal Network (rules)

**Added**
- **Multiple route segments linked by portals** (D-003 junctions):
  - `PortalDefinition` with optional `exit` and `requires`.
  - The loader follows the chain from the start segment and records `RouteDefinition.exit_portal_id` / `next_route_id`.
  - It rejects segments that end nowhere, unknown or self exits, exits where no segment starts, loops, unreachable segments, portals inside a segment, and cells shared across segments.
- **Teleport travel** (D-015, core only): stepping into an entry portal continues from the exit cell in the same step; the core never rests on the entry. The entry counts as blocked if it is occupied, the portal is inactive (its `requires` switches aren't all on) or the exit cell is blocked.
- `CoreTravelResult.portal_steps` marks teleport arrivals. `AnimationDirector` jumps the core there instead of sliding across the board (a placeholder until portals are rendered).
- `SwitchGateResolver.is_portal_active`; `LevelDefinition.portal_by_id` / `portal_at`.
- **Tests:** 19 new (10 rules, 9 loader), bringing the suite to 197. Mutation checks confirmed the occupied-exit and inactive-portal rules are each caught.

**Changed**
- Routes may now have several segments. The "exactly one segment" rule is replaced by chain validation, and the destination must end the final segment.
- `_run_core` advances via a single `_next_step` helper that handles normal steps and portal transits.

**Verified**
- Both shipped levels validate with identical results.

**Known limitations**
- Rules only: portals, switches and gates are not drawn or interactive in the 3D scene yet.
- `portal_network` has no player action (portals are fixed or switch-controlled), so levels cannot list it in `allowed_mechanisms`.

### 2026-11-15 — M5a: Switches & Seals (rules)

**Added**
- **Switches** (`SwitchDefinition`):
  - `pressure` switches are on while a block rests on them; the core never presses them (D-014).
  - `toggle` switches are flipped by the new `PuzzleAction.toggle_switch` (mechanism `switches_seals`), and their state is stored in `PuzzleState.toggle_states`, which is included in the state key.
- **Gates** (`GateDefinition`): open when all `requires` switches are on. A closed gate blocks the core, pushes and gravity.
- **`SwitchGateResolver`:** switch and gate state is always derived from positions and toggles, never stored.
- **`PuzzleSimulator.stabilize`:** gravity settles, gates are re-evaluated, and this repeats until nothing moves. It is used by every action, by core travel and by the loader's start-state check. Each object's move is merged into one start → rest move for animation.
- **D-013 rule:** any action whose result would leave a closed gate on a block or the core is rejected with the new failure `GATE_OCCUPIED`. This includes a Run, when gravity during travel would release a switch.
- **Loader** (schema v3, backward compatible): `mechanisms.switches` and `mechanisms.gates`, validated as described in `docs/LEVEL_SCHEMA.md`. `switches_seals` is now an implemented mechanism.
- The solver includes toggle actions.
- **Tests:** 26 new (17 rules, 9 loader), bringing the suite to 178. Mutation checks confirmed the travel gate check, iterative stabilisation and gate blocking are each caught by their tests.

**Verified**
- Both shipped levels still validate with identical results (slice: minimum 4, 536 dead ends, 17 unknown), so there is no behaviour change for existing content.

**Decisions:** D-013 (reject, never close an occupied gate), D-014 (blocks only press switches) and D-015 (portals carry the core only).

**Known limitations**
- Rules only: switches and gates are not yet rendered or interactive in the 3D scene, and no shipped level uses them.
- Portals are next (M5b).

### 2026-11-15 — Android Back handling and panel fixes

**Added**
- **Back / Escape handling** (P-009): `application/config/quit_on_go_back=false`. `GameplayController.handle_back()` responds to `NOTIFICATION_WM_GO_BACK_REQUEST` and `ui_cancel`. It closes the leave dialog, then the mechanism panel, then asks to leave.
- **`LeaveDialog`:** a modal "Leave this puzzle?" with Stay / Leave and a full-screen dimmer that blocks input to the board. Leave emits `leave_requested` and quits; `quit_on_leave` can be turned off for tests.
- **Tests:** 7 Back-navigation tests (including the dialog covering the whole screen) and a regression test that presses the real arrow button. Suite: 152.

**Fixed**
- **Crash-class bug when committing from a panel arrow:** the arrow's own `pressed` signal refreshed the panel, which freed the still-emitting button ("Attempted to free a locked object"). It was found in the Android emulator's log; the tests had emitted the panel's signal instead of the button's. `MechanismPanel` now creates its 9 slot buttons once and reconfigures them in place.
- **Leave dialog had zero size** (seen on the emulator: top-left corner, no dimming, board still touchable). The cause was `set_anchors_preset`, which keeps offsets. It now uses `set_anchors_and_offsets_preset`, and the HUD containers were switched too.
- The arrow buttons' theme text padding no longer inflates collapsed panel rows.

**Verified on the Android emulator** (Compatibility-renderer diagnostic build)
- A real arrow tap pushes with no errors.
- Back closes the panel, then shows the centred, dimmed dialog.
- A tap behind the dialog is blocked, Stay closes it, and Back then Leave exits the app.

**Decisions:** P-010, slice softlocks accepted for now.

### 2026-11-15 — M4: Production solver and level validator

**Added**
- **`PuzzleSolver`** (`game/scripts/solver/`): exhaustive search over `PuzzleSimulator`, so it always agrees with gameplay.
  - `solve()` uses a layered search: core runs are free and mechanism actions cost 1, so it returns a solution with the proven minimum. It reports `limit_hit` instead of claiming "unsolvable" when capped.
  - `analyze()` is the softlock scan. It classifies every state within a given action depth as completable, a proven dead end (its whole closure has no completion) or unknown. Results are shared between closures, and it gives the shortest example path into a dead end.
- **`LevelValidator`**: the release gate from doc 08 and doc 12, with errors and warnings per P-008, plus a readable report.
- **`tools/validate_levels.sh`** (with `game/tools/validate_levels.gd`): validates every level in `game/data/levels`. Exit code 1 on any error. `tools/` is excluded from the Android export.
- `PuzzleAction.describe()` gives readable action names for reports.
- **Tests:** 14 solver and validator tests, bringing the suite to 144. They cover the minimum with free runs, proven unsolvability, honest limits, determinism, dead-end detection with its example path, unknown reporting, and every validator error and warning.

**Changed**
- `optimal_actions` is now set from proven minima: Level 1 = 0, slice = 4.
- The shipped-level test uses `PuzzleSolver` and requires `optimal_actions` to equal the proven minimum.

**Removed**
- `tests/support/test_solver.gd`, the test-only precursor, now replaced by `PuzzleSolver`.

**Validator findings** (slice, current layout; not changed, awaiting a design decision)
- 536 proven dead-end states within 5 actions, and 17 unknown.
- The shortest is `run > push block_a down > push block_a down > run`. Block A drops into the upper gravity zone on top of B, the column is full, and the gravity checkpoint allows nothing else.
- On a scratch copy, a wall at (3,2) removes that trap (232 dead ends left). The next shortest is pushing B out of its zone onto the route at the push checkpoint, a consequence of D-009.

**Known limitations**
- The full softlock scan takes about 40 s for the slice, so it lives in the validator rather than the test suite.
- No daily-schedule validation yet (no daily data exists).
- The "editor workflow" from doc 13 is the command-line validator only.

### 2026-11-15 — Android build and emulator check

**Added**
- `game/export_presets.cfg`: an "Android" debug preset. It builds arm64-v8a only, uses package `com.slideandseal.game` (a placeholder, see below), excludes `tests/*`, includes `data/*.json`, and enables immersive mode. It contains no keystore paths or passwords.

**Verified** (Pixel 8 emulator, Android 15, 1080×2400, arm64)
- The debug APK (≈28 MB) exports, signs, installs and launches. Level JSON is packaged and tests are excluded.
- Godot starts with Vulkan 1.3 and the Mobile renderer.
- **Using a throwaway Compatibility-renderer build** (made outside the repo, because of the emulator issue below):
  - The layout fits the tall screen. The top margin clears the 132px camera cutout, so the safe-area code works.
  - A real tap on Run moves the core to the first checkpoint.
  - A real tap on block A selects it and opens the panel, with the invalid direction disabled.
  - A real swipe pushes the block, and the HUD and panel update.

**Found**
- **Emulator only:** Vulkan frames never reach the screen ("Couldn't present to Vulkan queue", black screen). This happens both with the host GPU (via MoltenVK) and with SwiftShader. It is an emulator limitation, not a game bug; the same build renders under OpenGL. A real device is needed to verify the Mobile renderer.
- The default 2 GB emulator RAM was too little with software rendering, and the app was killed. Use `-memory 4096`.
- **Risk:** on a fresh emulator boot, an asset-paths configuration change (`Config changes=80000000`) recreated the activity during startup, and Godot quit instead of recovering. Watch for this on real devices.
- **To do:** Android Back quits the game immediately, mid-puzzle (Godot default). It needs a pause or confirm flow before release.
- **To do:** there is no project icon (export warning).

### 2026-11-15 — M3b: Touch interaction

**Added**
- **Picking** (`BoardPicker`): screen → block or cell using plain ray math against block boxes and the floor plane. No physics engine. `BoardCoords.world_to_cell` provides the inverse mapping.
- **Gestures** (`BoardInput`, a new node in the gameplay scene): tap and swipe from mouse events, which Godot also emulates from touch.
  - HUD controls consume their own events, so they never reach the board. This was verified through the real input pipeline.
  - Swipe direction is classified against the camera's projection of each grid direction (`CameraRig.screen_vector`).
- **Selection:** tap a block or zone cell. Blocks take priority over the zone beneath. The selection shows an inverted-hull outline on the block or a highlighted zone plate.
  - The tap is refused with a message when the mechanism isn't available in the current context or the block isn't pushable.
- **Mechanism panel** (`MechanismPanel`, `ArrowButton`):
  - Arrows are self-drawn (no font glyphs) and placed by on-screen direction. Unused rows and columns collapse.
  - Zones offer only their allowed directions.
  - Each arrow is enabled only if `PuzzleSession.preview` accepts that action. The current gravity direction is disabled.
  - Hold an arrow to preview, release to commit (P-007).
- **Preview ghosts:** translucent blocks at the cells a push or gravity change would produce (`BoardRenderer3D.show_preview`). They are driven only by `PuzzleSession.preview`.
- **HUD:**
  - an "Available: …" line from `PuzzleSimulator.allowed_mechanisms`
  - the panel sits above the action buttons
  - safe-area margins on mobile (desktop keeps fixed margins)
- **Tests:** 14 interaction tests, bringing the suite to 130. They cover:
  - picking every block and empty zone cells
  - swipe classification and panel slot mapping
  - the unavailable-mechanism message, valid-direction enabling, and hold-to-preview without committing
  - swipe-to-push, swipe-to-gravity, swipe cancel and invalid swipes
  - dropping the selection when the context changes
  - solving the full slice through gestures

**Changed**
- `CameraRig` reserves more space at the bottom (30%) for the panel, so the board isn't covered.
- `GameplayController` now coordinates selection, preview and gestures. All actions still go through `PuzzleSession`.

**Fixed**
- `MechanismPanel` leaked replaced spacer controls. This was found from the engine's leak warnings at exit.

**Verified manually**
- Windowed run with the real input pipeline: a click on a block selects it, a click inside the panel doesn't reach the board, and a button click acts only as the button.
- Screenshots of the block and zone panels with previews. The outline was thickened and the panel compacted after review.

**Known limitations**
- Safe-area handling is untested on a physical Android device.
- No haptics, sound or preview of the core's next travel segment yet.
- Placeholder visuals (D-011).

### 2026-11-15 — M3a: 3D board and playback

**Added**
- **Gameplay scene** `game/scenes/gameplay/gameplay_root.tscn`, now the project's main scene. It has a world environment, a key light, the board, a camera rig, an animation director and the HUD.
- **`GameplayController`:** owns the `PuzzleSession` and routes every change through it. It locks input while a committed result plays back, snaps the board to the committed state afterwards, and asks the simulation (via preview) whether Run is available.
- **Presentation** (`game/scripts/presentation/`):
  - `BoardCoords`: the single grid ↔ world mapping
  - `Palette`: doc 06 colour tokens
  - `BoardRenderer3D`: builds placeholder primitive art (D-011) from level data: tiles, walls, emissive route inlay, checkpoint rings, seal, gravity zone plates with per-cell direction chevrons, blocks, and an octahedron core with glow. It snaps nodes to any `PuzzleState`.
  - `CameraRig`: orthographic isometric camera, fitted to the portrait band between the HUD areas, reframed on resize
  - `AnimationDirector`: plays committed results only. Zone arrows turn first, then the core moves cell by cell, with gravity slides following the step that triggered them. A push plays first, then gravity slides together. The `instant` mode doubles as reduced motion.
- **UI:** `HudController` shows the title, phase status, the action count against the target and rejection messages, and provides Undo / Restart / Run–Resume. It uses a palette-based theme. Non-interactive areas ignore input, ready for M3b board taps.
- `PuzzleSession.is_at_initial_state()`.
- **Tests:** 5 scene integration tests, bringing the suite to 116. The board mirrors the committed state after every step of the full slice solution, after a rejection, and after undo and restart. HUD availability is checked too.
- **Decisions:** D-011 (placeholder art first) and D-012 (tap and swipe input, built in M3b).

**Changed**
- The test runner now runs tests on the first frame instead of in `_initialize`. Before that, the root viewport isn't in the tree, so scenes added by tests never received `_ready`.

**Verified manually**
- Rendered in a window, playing the slice solution with real animation: the run, push, gravity turn and slides, travel and completion all render matching the committed state.
- A camera projection check confirmed the zone chevrons point in the simulated direction. The chevrons were then lengthened for clearer reading.

**Known limitations**
- No touch input yet; push and gravity can't be triggered in-game until M3b.
- Placeholder art. Walls can partly hide cells behind them at this camera angle (for example next to the seal). Revisit in polish.
- Safe-area insets are not yet applied (fixed 48px margins).

### 2026-11-15 — M2: Gravity Shift and Push Pulse

**Added**
- **Gravity Shift** (`GravityResolver`, `PuzzleAction.set_gravity`): local rectangular zones with a player-settable direction (D-006).
  - Gravity is persistent: every committed state is settled, including after each core step during travel.
  - Resolution order is deterministic: farthest along gravity first, then by id.
- **Push Pulse** (`PuzzleAction.push`): moves any pushable object one cell (D-007).
  - No chains. Pushes into walls, bounds, objects or the core are rejected.
  - Gravity settles after each push. A push with no net effect is rejected.
- **Mechanism availability** (`PuzzleSimulator.allowed_mechanisms`): setup, checkpoint and blocked contexts (D-008).
- **Model:**
  - `Grid.Direction`
  - `MechanismIds`
  - `GravityZoneDefinition`
  - `ObjectMove`: per-object moves with their cause and core step, for upcoming animation
  - object flags `pushable` and `gravity_affected`
  - `PuzzleState.gravity_directions`, included in the state key
- **Level schema v3 extensions:**
  - `setup.allowed_mechanisms`, object flags and `gravity_zones`
  - validation of zone bounds, overlap and directions
  - mechanism availability must make sense: something to act on, implemented mechanisms only
  - the authored start state must already be settled
- **Vertical slice level** `game/data/levels/world_01_slice.json` (D-010): three beats (push, gravity, combined) and a target of 4 actions. Its tests cover the intended solution, beat order, closed skips and the minimum of 4.
- **Test-only exhaustive search** `TestSolver`, in `tests/support`, the precursor of the M4 solver. Core runs are free and mechanism actions cost one, so it finds the true minimum.
- `PuzzleState.to_key(include_counters)`: lets search merge boards that differ only in their counters.
- **Tests:** 54 new, bringing the suite to 111, all passing. Covers gravity, push, mechanism context and the new loader rules. Mutation checks confirmed the ordering and in-travel settling tests fail when that logic is broken.
- **Docs:**
  - decisions D-006 to D-010
  - P-001 to P-006 marked approved
  - `docs/LEVEL_SCHEMA.md` updated

**Changed**
- New failure codes: `MECHANISM_NOT_ALLOWED`, `INVALID_TARGET`, `INVALID_DIRECTION`, `MOVE_BLOCKED`, `NO_EFFECT`.
- Core travel now reports gravity moves triggered by the cells it vacates.
- The shipped-level test now requires every level to be solvable within its `target_actions`, using `TestSolver`, and replays the solution through `PuzzleSession`. It previously only tried running the core.

**Known limitations**
- There is no push-until-blocked mode (`push_devices`). That is deferred per doc 03.
- `TestSolver` is test-only and bounded at 200k states. The production solver arrives in M4.

### 2026-11-15 — Repository README

**Added**
- Root `README.md`: a short overview covering the layout, requirements and test command. `CLAUDE.md` now says to update it only when its content becomes wrong.

### 2026-11-15 — M1: Headless simulation foundation

**Added**
- **Godot project** at `game/` (Godot 4.7.2, Mobile renderer, portrait 1080×1920, `canvas_items` stretch). Untyped GDScript declarations are configured as errors, which enforces typed GDScript.
- **Model** (`game/scripts/model/`):
  - level data: `LevelDefinition`, `RouteDefinition`, `CheckpointDefinition`
  - runtime state: `PuzzleState`, `MovableObject`
  - actions and results: `PuzzleAction`, `ActionResult`, `CoreTravelResult`
  - helpers: `Grid`

  `PuzzleState.to_key()` gives a canonical serialization of every field, used for equality, undo checks and the future solver.
- **Simulation** (`game/scripts/simulation/`):
  - `PuzzleSimulator`: pure, deterministic rules for core travel. One `RUN_CORE` action covers Run and Resume. It handles checkpoint auto-pause, blocking by movable objects (`BLOCKED_WAITING_FOR_ACTION`) and completion. `preview_action` uses the same rule path as `apply_action`.
  - `PuzzleSession`: committed state plus undo history. Undo covers core travel too. Restart is exact and undoable.
  - `LevelLoader`: strict level schema v3 loading and validation. A level with any error is rejected whole.
- **Level data:** `game/data/levels/world_01_level_001.json`, "The First Signal", converted from the package example to schema v3. The original file is unchanged.
- **Tests:**
  - custom headless runner `game/tests/run_tests.gd` plus `tools/run_tests.sh`. Engine or script errors raised during a test fail that test.
  - 57 tests across unit, integration and shipped-level suites
- **Docs:**
  - `docs/DECISIONS.md`: approved decisions D-001 to D-005 and provisional choices P-001 to P-006
  - `docs/LEVEL_SCHEMA.md`: schema v3, filling the missing `14_Level_Data_Schema.md`
- `.gitignore`: covers `.godot/`, `.DS_Store`, Android build output and signing material.

**Decisions**
- Approved:
  - slice level includes gravity and push (D-001)
  - `game/` layout (D-002)
  - authored route segments (D-003)
  - custom test runner (D-004)
  - portrait (D-005)
- Provisional, awaiting review: P-001 to P-006 in `docs/DECISIONS.md`. These cover atomic travel, a single run/resume action, rejecting a run into an immediately blocked cell, checkpoint-on-enter, undoable restart and schema v3.

**Known limitations**
- There are no mechanisms yet. The loader rejects non-empty mechanism collections until their resolvers exist, so `BLOCKED_WAITING_FOR_ACTION` can only be cleared by undo or restart.
- There is a single route segment per level, with no junctions yet.
- There are no scenes, rendering or UI yet.
- Undo history is unbounded.
- "Completable" in the shipped-level test means running the core reaches the seal. The BFS solver arrives in M4.

### 2026-11-15 — Project initialization audit

**Added**
- `CLAUDE.md`: permanent development instructions covering the Git/no-commit policy, the changelog policy, architecture rules (deterministic simulation as source of truth, separate presentation/UI, no physics-driven outcomes, no timers), the design-change policy, the working method and the verified toolchain.
- `CHANGELOG.md`: this file.

**Audit findings (no code changed)**
- The repository holds the Slide & Seal design/reference package v2.0 (`Slide_and_Seal_Interactive_Labyrinth_v2/`): 18 design docs, concept art, 8 SVG mechanic glyphs, an example level JSON and a daily schedule template.
- No Godot project exists yet (`godot_project/` holds only placeholder READMEs). There is no code and no executable test suite.
- The repository has no commits yet. All files are untracked.

**Known gaps**
- `docs/08` references `14_Level_Data_Schema.md`, which does not exist. The level schema is currently defined only by `data/levels/level_001_example.json`.
- The open design decisions in `docs/18` are unresolved.
