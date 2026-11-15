# 12 — QA and Acceptance Plan

## Simulation tests
- Valid/invalid grid actions.
- Gravity direction and settling.
- Deterministic ordering for multiple objects.
- Push collision and bounds.
- Portal pair and blocked exit.
- Switch and gate dependencies.
- Rotation bounds and occupancy.
- Energy beam reflection and loop detection.
- Magnetic attraction/repulsion.
- Core route and checkpoint pause/resume.
- Win condition and objective completion.

## State tests
- Preview equals committed result.
- Undo restores complete state.
- Restart restores initial state.
- Save/load round trip.
- State hash changes when any gameplay-relevant field changes.

## Solver tests
- Every released level is solvable.
- Search limits reported honestly.
- Optimality only claimed when proven.
- Solver and gameplay use the same resolver.
- No duplicate or invalid states.

## Presentation tests
- Grid alignment remains accurate in 3D.
- Camera transitions do not obscure objectives.
- Reduced-motion mode works.
- Effects do not hide interactive tiles.
- Input locked during non-interruptible animations.

## Android tests
- Screen sizes and aspect ratios.
- Safe areas and navigation bars.
- Touch gesture accuracy.
- Pause/resume.
- Process termination and save recovery.
- Low/mid-range device performance.
- Offline campaign behavior.

## Monetization tests
- Purchase success/cancel/failure.
- Restore purchases.
- Pending transaction handling.
- Reward callback verification.
- No ads during active puzzle play.

## Release gates
Do not release with:
- Any unsolvable level.
- Preview/simulation disagreement.
- State corruption after undo.
- Critical Android crashes.
- Broken purchase restoration.
- Daily date duplication.
- Ads interrupting active gameplay.
