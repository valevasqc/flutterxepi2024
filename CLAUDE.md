# CLAUDE.md — XEPI Client Catalog

Public no-login product catalog (Flutter web) for XEPI, a Guatemalan retail store. Customers browse categories → subcategories → products, keep a localStorage cart, and send the order to WhatsApp. The separate **admin app** (different repo) is the source of truth for products, pricing, stock, Firestore rules, and Cloud Functions.

## Read these before non-trivial work

1. [AGENTS.md](AGENTS.md) — business boundaries and working rules (binding).
2. [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) — prioritized defects with full context. **Start here: P0-3 (Q0 prices) is the main pre-launch blocker.**
3. [docs/ROADMAP.md](docs/ROADMAP.md) — decided architecture (publicCatalog mirror, bulk-pricing move, auth phases), Phase 0 status, and binding migration rules.
4. [XEPI_CLIENT_MASTER_DOCUMENTATION.md](XEPI_CLIENT_MASTER_DOCUMENTATION.md) — full product context.

## Critical facts (verified 2026-07-17)

- **The `publicCatalog` mirror is live and the client is repointed at it** — catalog reads work with no auth (`publicCatalog`, `categories` + `subcategories` subtree, `config/bulkPricing` are public; `products` stays auth-only). Remaining functional gaps: KNOWN_ISSUES P0-3 (products without a resolvable price → Q0 in cart) and P1-4.
- **Testing phase, and the repointed code is uncommitted**: last commit on `main` is 2025-12-01; the legacy site (separate repo) is still what customers use. Do not commit/push/deploy until the owner confirms client + admin work as a pair (ROADMAP Phase 0 step 5). Every push to `main` deploys hosting to the **live** channel.
- `firestore.rules` in this repo is a **read-only snapshot** of the live rules (currently stale — predates the mirror deploy, P2-4). Never edit it as if it were deployable, never wire it into `firebase.json`, never deploy rules from this repo.
- The legacy public site lives in a different repo (`valevasqc/xepi2024`); local copies under `tools/examples/` and `archive/` are historical references — do not delete or "modernize" them.
- No Realtime Database instance exists anymore; anything referencing RTDB is legacy.

## Code layout & conventions

- All app code is in `lib/main.dart` (monolith by choice for now; the planned split into `models/ services/ pages/` is still pending — KNOWN_ISSUES P2-3).
- Spanish UI text, English code/comments. Palette/fonts: `AppColors`, Montserrat + Quicksand — keep consistent.
- Cart: `CartService` singleton, persisted via `shared_preferences` (browser localStorage, key `xepi_cart`); prices re-resolve from the mirror when the cart opens.
- Bulk pricing for cuadros: loaded from Firestore `config/bulkPricing` at startup; the `BulkPricing` class holds the offline fallback and the banner text.
- Product prices resolve as `priceOverride ?? subcategory defaultPrice`; the mirror carries no resolved price (see P0-3 before touching pricing code).

## Commands

- `flutter pub get` · `flutter run -d chrome` · `flutter analyze` · `flutter build web --release`

## Environment quirks

- Repo lives in OneDrive (owner decision — limited disk space). Git is slow and `git status` shows mass phantom modifications; use targeted git commands with generous timeouts and don't be alarmed by the noise.
