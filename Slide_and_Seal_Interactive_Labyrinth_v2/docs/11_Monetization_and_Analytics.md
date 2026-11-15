# 11 — Monetization and Analytics Plan

## 1. Recommended launch model

- First 30 campaign levels free.
- Levels 31–50 unlocked by one-time full-game purchase.
- Daily Puzzle remains free.
- Optional rewarded ads for hints.
- No forced interstitials during active puzzle play.
- No subscriptions or consumable currency.

## 2. Premium offer

Prefer one clear full-game unlock that grants premium campaign content and removes ads. Avoid confusing overlapping purchases.

## 3. Price hypotheses

Initial India hypothesis only:
- Full-game unlock: ₹199.
- Future expansion packs: ₹79–₹149.
- Cosmetic themes: ₹49–₹99.

These are test hypotheses, not committed prices. Configure regional pricing in Google Play Console.

## 4. Rewarded hints

- Explicit opt-in.
- Explain reward before showing ad.
- Grant reward only after verified reward callback.
- Handle no-fill, cancellation and network failure.
- Never interrupt core travel or an active puzzle interaction.
- Consider a limited free hint path for accessibility.

## 5. Purchase implementation

- Use Google Play Billing through a maintained Godot-compatible plugin or native Android bridge.
- Verify purchase state.
- Support restore/reconciliation.
- Handle cancellation and pending transactions.
- Do not trust a local save flag as authoritative purchase proof.
- Keep billing behind a service interface.

## 6. Analytics

Suggested events:
- `level_started`
- `level_completed`
- `level_abandoned`
- `mechanism_action`
- `checkpoint_reached`
- `preview_requested`
- `hint_used`
- `daily_started`
- `daily_completed`
- `premium_store_opened`
- `purchase_completed`
- `purchase_failed`
- `crash_reported`

Collect minimal, non-sensitive data. Review current Play privacy and SDK disclosure requirements before release.
