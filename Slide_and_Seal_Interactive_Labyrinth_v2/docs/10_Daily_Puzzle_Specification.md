# 10 — Daily Puzzle Specification

## 1. Product role

Daily Puzzle creates a reason to return without forcing daily play. It is available to free and premium players.

## 2. Content

Target 90 handcrafted and validated puzzles before launch. Use a pre-authored schedule. Do not generate random puzzles at runtime.

## 3. Daily structure

- One featured puzzle per UTC date key.
- Puzzle includes title, difficulty, mechanic focus and estimated solve time.
- Same simulation and solver as campaign.
- Previously downloaded puzzle remains available offline.
- Replay policy should be simple and clearly presented.
- No punishment for missed days.

## 4. Streaks

- Streak counts consecutive UTC daily completions or another explicitly selected calendar policy.
- Choose one date policy and document it.
- Offline completion is recorded locally and reconciled safely.
- Device clock changes must not grant duplicate daily rewards.
- Streaks are cosmetic/progression feedback, not a source of pressure.

## 5. Difficulty rotation

Suggested weekly cadence:
- Day 1: accessible warm-up.
- Day 2: gravity or push.
- Day 3: portal.
- Day 4: switch/gate.
- Day 5: energy routing.
- Day 6: rotating or polarity.
- Day 7: combination challenge.

## 6. Daily schedule schema

See `data/daily/daily_schedule_template.json`.

## 7. Metrics

Track daily starts, completions, hint usage and return rate with minimal anonymous analytics.
