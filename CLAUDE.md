# Slide & Seal — Permanent Development Instructions

Read this file at the start of every session and follow it.

**Slide & Seal** — "Reconfigure reality. Control the maze. Complete the seal."
A premium interactive mechanical labyrinth puzzle for Android, built with **Godot 4.x and typed GDScript**.
The player manipulates environmental mechanisms to guide a geometric energy core through a deterministic maze. It is **not** a character-movement game.

## Source of truth

The design package in `Slide_and_Seal_Interactive_Labyrinth_v2/` is the primary source of truth:
- `docs/` — design, mechanics, architecture, roadmap (start with `README.md`, then docs 01–04, 14, 18).
- `assets/` — **art-direction references only** (generated concept images). Not production assets. Never crop them into final UI or ship them.
- `assets/concept_boards/previous_visual_direction_reference.png` shows the **superseded** "seeker auto-steps per move" concept. Do not use it for gameplay.
- Text inside concept images (file names, level titles, world names) is not authoritative. The Markdown specs win.
- Treat the package as read-only reference. Do not move, rename, delete or overwrite its files without explicit approval.

## Git and commit policy (absolute)

- **NEVER create a Git commit.** Never run `git commit`, `git commit --amend`, or create commits via scripts, extensions, APIs or other tools.
- **Never push** to any remote. No merges, rebases or PRs.
- **Do not stage** (`git add`) unless the user explicitly asks.
- Inspecting `git status` / `git diff` / `git log` is fine.
- The user reviews, stages and commits everything personally.
- When a meaningful milestone is complete, provide a **Suggested commit message** in conventional-commit style (`type(scope): description`, e.g. `feat(simulation): add gravity resolver`), plus a short summary and the affected files. Do not commit.

## Changelog policy

Maintain root-level `CHANGELOG.md` (Keep a Changelog style: `Unreleased` section, then dated releases).
- Update it after each meaningful task or milestone, **before** reporting the milestone complete.
- Record the date, summary, affected systems, notable implementation decisions, bug fixes, removals and known limitations.
- Skip trivial formatting changes.
- Never silently rewrite or erase historical entries.

## Architecture rules

- **One deterministic 2D simulation, one 3D board renderer, one 2D UI layer.** Keep their responsibilities separate.
- The simulation is the source of truth. The 3D renderer and animations never decide gameplay rules or mutate puzzle state.
- Integer grid coordinates (`Vector2i`; x → right, y → down) and predictable state transitions.
- Simulation code must run headless, with no scene tree, nodes or physics.
- Validate actions before applying them. Invalid actions do not mutate state.
- Simulation functions do not mutate the caller's state. They return a new state or result.
- **One set of resolver functions** powers gameplay, preview, hints, solver and validation. Preview must equal the committed result.
- Undo, restart and preview stay consistent with the real simulation. Undo restores *all* puzzle-relevant state.
- Never use Godot's real-time physics to determine puzzle outcomes.
- **No timers, countdowns, reflex challenges or arbitrary movement pauses.**
- Grid ↔ world coordinate mapping lives in one service only.
- Deterministic ordering everywhere: stable IDs, documented resolution order, no unordered Dictionary iteration in rule code, no randomness.
- Avoid unnecessary dependencies and plugins. Prefer reusable, modular systems.
- Mobile renderer, Android-first. Never commit keystores, signing passwords or secrets.

## Design-change rules

- Do not replace the core concept or introduce a different puzzle mechanic.
- Do not resurrect the old "one automatic step per player move" gameplay.
- When a rule is ambiguous (see `docs/18_Open_Design_Decisions.md`), **ask** rather than invent. Record approved decisions in a project decision log before implementing them.
- Explain and get approval for any change that alters the agreed design.

## Working method (every task)

1. Briefly explain the intent.
2. Inspect relevant existing code before editing.
3. Identify dependencies and risks.
4. Implement only the requested scope, in small reviewable milestones. No unrelated batch changes.
5. Run appropriate tests or validation (headless Godot where possible).
6. Self-review the diff for errors and unnecessary complexity.
7. Update `CHANGELOG.md` for meaningful changes.
8. Report what changed, what was tested (with real results), and what is incomplete.
9. Provide a suggested commit message at milestones.

Never claim something works unless it was actually tested or verified. Priority: a polished, stable, premium-quality game, not lots of code.

## Project layout and commands

- `game/`: Godot project root (`res://`). `scripts/model` holds pure data, `scripts/simulation` holds the rules, `data/levels` holds level JSON, and `tests/` holds the test suites.
- `docs/DECISIONS.md`: approved and provisional decisions. Read it before changing any rule. Add new decisions there.
- `docs/LEVEL_SCHEMA.md`: the current level JSON schema. Keep it in sync with `LevelLoader`.
- **Run tests:** `tools/run_tests.sh` (an import pass, then the headless runner; exit code 0 means all tests passed). Run it after every change to simulation, model, data or tests.
- Commit the `*.uid` and `*.import` files Godot generates. Never commit `.godot/`.

## Environment (verified 2026-11-15)

- Godot `4.7.2.stable` at `/opt/homebrew/bin/godot` (export templates 4.7.2 installed).
- Android SDK at `$ANDROID_HOME` (`~/Library/Android/sdk`), JDK 17 (Zulu).
- Note: `/Users/apple/Github/CLAUDE.md` (parent folder) belongs to an unrelated workspace ("Gallerials") and does not apply to this project, except that its no-commit rule agrees with this one.
