# XEPI Client — Known Issues

Last updated: 2026-07-17 (post-mirror verification; live Firebase state checked via unauthenticated REST).
Priorities: **P0** = blocks launch / security exposure · **P1** = must fix before promoting the new app · **P2** = quality/robustness.

Issues marked **[ADMIN]** must be fixed in the admin project — they are recorded here because they block or shape the client.

**Context:** the project is in the testing/building phase — Firestore contains test data only, no real inventory yet. Data-hygiene observations (test products in the mirror, placeholder subcategories, incomplete backfill for categories without products) are expected right now and are NOT tracked as issues; the structural problems they revealed are.

---

## P0-2 · Email/password sign-up grants read access to business data **[ADMIN]**

Email/password auth is enabled. Firebase allows client-side self-registration by default, and most collections (`sales`, `expenses`, `users`, `movements`, `shipments`, `orders`, `deposits`, `pendingCash`, `cierres`, `locations`, `expense_categories`) allow **read for any authenticated user** — no role required. So anyone who calls `createUserWithEmailAndPassword` against the project's public API key can read sales history, expenses, the staff user list, etc. `expenses` even allows `create` for any authenticated user.

Fix options (admin side): disable self-signup (Identity Platform setting or a `beforeCreate` blocking function that rejects non-invited emails), **or** change `allow read: if isAuthenticated()` to a staff-role check (e.g. `hasPermission(...)`/`isStaff()`) on all business collections. This also becomes a hard prerequisite for client user accounts (Phase 1): customer accounts must NOT satisfy the same `isAuthenticated()` checks as staff.

**Status 2026-07-17: unverified.** The 2026-07-16/17 admin-side work deployed the mirror rules; whether it also closed this hole is unknown from the client side (verifying would require creating a real account against production Auth). Confirm in the admin project.

## P0-3 · Products without a resolvable price go into the cart at Q0 **[ADMIN + CLIENT]**

The deployed `publicCatalog` mirror carries **no price field** — only `priceOverride` (null unless set). This deviates from the ROADMAP Phase 0 shape, which specified a resolved `price` (`priceOverride ?? subcategory defaultPrice`) on every mirror doc. The client resolves prices as `priceOverride ?? defaultPrice`, and `_addToCart` coerces null to 0, so any product whose price resolves to null is added to the cart — and to the WhatsApp order — at **Q0.00**. Two paths hit this:

1. **Search (always):** `SearchPage` reads `defaultPrice` off the mirror doc itself (`lib/main.dart` search result builder), but mirror docs have no such field. With overrides unset, every non-bulk product added from search is Q0. Bulk-eligible cuadros are masked because the cart reprices them from the tiers.
2. **Browse (when the subcategory has no `defaultPrice`):** `ProductsPage` gets `defaultPrice` from the subcategory doc; subcategories without one (in test data: LAT-C30, LAT-2020, LAT-3030, LAT-ESC, LAT-FLE, JUG, KIT) produce price-less thumbnails and Q0 adds.

Fix (decide with admin — preferred: **(a)**):
- **(a) [ADMIN]** Put the resolved `price` on every mirror doc during sync, per the original ROADMAP shape, and have the client read it directly. Also lets cart `refreshPrices()` update *all* items, closing the P1-3 residual below.
- **(b) [CLIENT]** Join subcategory `defaultPrice` into search results and guard `_addToCart` against null prices (refuse/alert instead of Q0).
- Either way **[ADMIN]**: enforce that every active subcategory has a `defaultPrice` (or that every mirrored product has a resolvable price) at sync time.

## P1-4 · Two bulk-pricing sources exist on the admin side **[ADMIN]**

The client reads tiers from `config/bulkPricing` (verified live: Q35 / 2+ → Q30 / 5+ → Q25, codes LAT-2030 + LAT-1530). But subcategory docs *also* carry their own `bulkPricing` map — and it disagrees: `{normal: 35, qty2: 30, qty3Plus: 25}` says **3+** units → Q25, while the config doc says **5+**. The client ignores the subcategory map, so whichever one the admin UI actually edits may silently drift from what customers are charged. Decide which is authoritative, sync or delete the other.

Related client nuance (by design, keep in mind): for bulk-eligible category codes the cart charges the tier price and ignores `priceOverride`, so an override below the tier would display on the thumbnail but not be charged. With admin controlling both the tiers and the eligible-codes list in `config/bulkPricing`, admin can keep these consistent.

## P1-3 (residual) · Cart price refresh cannot see default-priced items

`CartService.refreshPrices()` runs when the cart opens: it re-reads the mirror, updates items whose `priceOverride` changed, and removes items no longer in the catalog. But items priced via subcategory `defaultPrice` keep their add-time snapshot, because the mirror doc carries no price to compare against. Acceptable for a human-reviewed WhatsApp handoff; disappears automatically if P0-3 fix (a) puts the resolved price on mirror docs.

## P2-3 · Monolithic `lib/main.dart`

~2,600 lines, all UI + services in one file. The `publicCatalog` repointing (the planned natural moment to split) happened without the split. Still fine for now; split into `services/`, `models/`, `pages/` before the codebase grows further.

## P2-4 · Local `firestore.rules` snapshot is stale

The repo's read-only snapshot predates the 2026-07-16/17 admin deploy (public `publicCatalog`/`categories`/`subcategories`/`config` reads). Refresh it from the admin repo so this repo documents reality. It remains a snapshot only — never wire it into `firebase.json`.

## P2-5 · Minor UI leftovers

- `CategoryCard` has a `// TODO add padding without it overflowing` on the category-name padding.
- 14 `withOpacity` deprecation infos from `flutter analyze` (replace with `.withValues()` opportunistically).

---

## Resolved (2026-07-16/17) — mirror migration

- **P0-1 · Client broken against live rules** → **fixed on both sides and verified live** (unauthenticated REST, 2026-07-17). Admin deployed the `publicCatalog` mirror (display-safe fields only — no `costPrice` anywhere, checked across all docs), public read on `categories` + `categories/{id}/subcategories` + `config/bulkPricing`, while `products` stays auth-only. Client (`lib/main.dart`) repointed all reads accordingly. Builds and analyzes clean. **Not yet committed/deployed** — the live hosting channel still serves the old build, deliberately, until client+admin are verified as a pair (ROADMAP Phase 0 step 5).
- **P1-1 · Bulk pricing hardcoded** → tiers + eligible category codes now load from `config/bulkPricing` at startup; the `BulkPricing` class constants are the offline fallback; banner text derives from the loaded values. (See P1-4 for the remaining admin-side dual-source question.)
- **P1-2 · Approximate product ordering** → both product queries use `.orderBy('displayOrder')`; the composite index `(categoryCode, displayOrder)` exists on `publicCatalog` (verified by running the exact query); every mirror doc has `displayOrder` set, so none are silently dropped. The in-memory re-sort was removed.
- **P1-3 · Stale cart prices** → `refreshPrices()` on cart open (see residual above).
- **P2-1 · Search read amplification** → app-level catalog cache with a 10-minute TTL + 300 ms debounce; search now reads Firestore at most once per 10 minutes regardless of page visits.
- **P2-2 · "Sin nombre" for cuadros** → cart UI and WhatsApp message fall back to warehouse code, then barcode; the literal placeholder is gone.

## Resolved (2026-07-05)

- Search read-amplification: per-keystroke full-collection reads → cached fetch + 300 ms debounce.
- Bulk-pricing constants duplicated in logic + banner string → single `BulkPricing` class.
- `_navigateToSubcategoriesPage` ignored `isActive` → now routes on active subcategories only.
- Page 2+ of products appended unsorted → whole loaded list re-sorted by `displayOrder`.
- `firebase.json` pointed at a nonexistent `database.rules.json` (root) for a Realtime Database instance that no longer exists (verified 404) → `database` section removed. Historical RTDB rules kept at `firebase/database.rules.json` for reference.
- Stale local `firestore.rules` (old, insecure pre-claims version) → replaced with a clearly-marked read-only snapshot of the live rules; deliberately not wired into `firebase.json` so this repo can never overwrite admin's rules.
- rekubricks `CART_EXAMPLE` reference (borrowed from another project, no longer needed) → deleted.
- README claimed Realtime Database architecture → corrected to Firestore.

## Non-issues (checked, fine)

- WhatsApp message building: properly URL-encoded (`Uri.encodeComponent`).
- Cart persistence: `shared_preferences` → browser localStorage under `xepi_cart`; load/save/merge logic is sound. `refreshPrices()` also prunes items whose product left the catalog.
- Secrets: nothing sensitive tracked in git (`archive/client_secret_*.json` is gitignored and was never committed; consider deleting it from disk anyway).
- CI: GitHub Actions build + Firebase Hosting deploy workflows are correct. Note they deploy the **new** app to the live channel on every push to `main` — which is why nothing is committed yet.
