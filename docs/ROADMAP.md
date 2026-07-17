# XEPI Client — Roadmap & Migration Rules

Last updated: 2026-07-17. Decisions in this file were made explicitly by the owner (2026-07-05); do not re-litigate them without asking.

Companion docs: [KNOWN_ISSUES.md](KNOWN_ISSUES.md) (current defects) · [../XEPI_CLIENT_MASTER_DOCUMENTATION.md](../XEPI_CLIENT_MASTER_DOCUMENTATION.md) (product context) · [../AGENTS.md](../AGENTS.md) (working rules).

---

## Where things stand (2026-07-17)

- **Testing/building phase.** Firestore holds test data only — no real inventory yet. The owner will not promote the new app until client + admin are verified working **as a pair**.
- **Legacy static catalog** is still the public site customers use. It lives in the separate `valevasqc/xepi2024` GitHub repo, not here. Reference copies only: `tools/examples/HTML_UI_TEMPLATE/`, `archive/`. **Do not modify or delete legacy** until Phase 0 completes and the new app is verified live.
- **The `publicCatalog` mirror is live** (admin deployed 2026-07-16/17, verified via unauthenticated REST): mirror docs + public read on `categories`, `categories/{id}/subcategories`, `config/bulkPricing`; `products` stays auth-only; composite index in place. Known deviation from the planned shape: mirror docs carry **no resolved `price` field** → KNOWN_ISSUES P0-3.
- **New Flutter client** (this repo) is repointed at the mirror and works against live data (builds + analyzes clean). **All of this is uncommitted** — the last commit on `main` is from 2025-12-01, and pushing deploys to the live channel, so nothing gets committed/pushed until the owner says the pair is verified.
- **Admin app** (separate repo) owns products, pricing, stock, rules deployment, and Cloud Functions. Its rules use JWT custom claims (`role`, `permissions`). The client-side `lib/main.dart` repoint was done by a session in that project and copied back here.

## Decided architecture (owner decisions, 2026-07-05)

1. **Catalog reads**: the client will read from a **public mirror collection** (`publicCatalog`), maintained by the admin side, containing only display-safe fields. `products` stays auth-only. (Chosen over field-splitting and over anonymous-auth.) — *Implemented 2026-07-16/17.*
2. **Bulk pricing**: tiers move to **Firestore under admin control**; the client's `BulkPricing` class becomes a fallback/cache, not the source of truth. — *Implemented 2026-07-16/17 via `config/bulkPricing`; see P1-4 for the remaining dual-source question.*
3. **Auth exposure**: email/password is enabled; self-signup must be closed or business collections must require a staff role before any customer-facing auth ships (KNOWN_ISSUES P0-2). — *Still open/unverified.*

---

## Phase 0 — Unbreak & harden (before promoting the new app)

Status as of 2026-07-17: steps 2–4 are essentially **done** (with the deviations noted); steps 1 and 5 remain.

1. **[ADMIN] — OPEN (status unverified).** Close the self-signup hole (P0-2): blocking function or staff-role read checks on business collections. Not confirmable from the client side; verify in the admin project.
2. **[ADMIN] — DONE, one deviation.** The `publicCatalog` mirror is deployed: display-safe fields, public read / no client write, `config/bulkPricing` doc for the tiers, composite index `(categoryCode, displayOrder)`, `displayOrder` guaranteed on every doc. Deviations from the planned shape:
   - Mirror docs carry `priceOverride` but **no resolved `price`** field → products without a subcategory `defaultPrice` (and all search results) resolve to no price and fall into the cart at Q0 (**KNOWN_ISSUES P0-3** — fix before launch, preferably by adding the resolved price during sync).
   - Category/subcategory data stays in the original `categories` tree (made publicly readable) instead of being mirrored — fine, but it means subcategory docs' own `bulkPricing` maps can drift from `config/bulkPricing` (**P1-4**).
   - Mirror contains only active products, so the client dropped its `isActive` filter — the sync must keep removing deactivated products.
3. **[ADMIN] — DONE for test data.** Mirror backfilled (1,067 docs at verification). Re-verify counts against active products once real inventory is loaded.
4. **[CLIENT] — DONE except the split.** All Firestore reads in `lib/main.dart` repointed to the mirror; product queries use `.orderBy('displayOrder')` (P1-2 fixed); bulk tiers read from `config/bulkPricing` with `BulkPricing` as fallback (P1-1 fixed); cart prices re-resolve on cart open (P1-3, small residual). The `main.dart` split into `models/ services/ pages/` (P2-3) did **not** happen — still pending.
5. **[CLIENT] — PENDING (current position).** Fix P0-3, verify end-to-end as a client+admin pair (browse, search, cart, WhatsApp — on the live URL once pushed), then point the public domain at the new app and freeze/retire legacy. Only after this may legacy references be archived. Nothing is committed/pushed until the owner green-lights this step.

**Exit criteria:** new app loads real data with zero auth, no permission-denied in console, order message correct **with no Q0 line items**, legacy no longer the primary site.

## Phase 1 — Customer accounts (cart, saved items)

Prereq: Phase 0 complete, especially the P0-2 fix.

**Migration rules (binding):**
- **Role separation**: customers get a distinct claim (e.g. `role: 'customer'` or no role). Staff checks in rules must never pass for customers. Audit every `isAuthenticated()` in the admin rules before enabling any public sign-in method.
- **Anonymous → account upgrade**: if guest browsing should keep carts across devices later, use Firebase anonymous auth + `linkWithCredential` upgrade, never a separate account that orphans the cart. (Anonymous auth may only be enabled after the role-separation audit.)
- **Cart migration**: on first sign-in, merge localStorage cart into `customers/{uid}/cart` (sum quantities on barcode collision), then treat Firestore as the source of truth and keep localStorage as offline cache. Never silently discard the local cart.
- **Customer data**: lives under `customers/{uid}/...` (cart, savedItems, profile) with rules `allow read, write: if request.auth.uid == uid`. Do NOT reuse the staff `users` collection.
- Client packages: add `firebase_auth`; keep Spanish UI / English code.

Features: email/password (and optionally Google) sign-in, persistent cart, saved/favorite items, order-request history (client-side record of WhatsApp handoffs).

## Phase 2 — Direct purchases on the website

Only after Phase 1 is stable and the business wants it (master doc §17 guardrail still applies).

- Payment provider for Guatemala (research needed: Recurrente, PayPal, card gateways — pick with the business).
- Orders become real records: client creates `orderRequests` via CF (never direct writes to admin `sales`); admin confirms/fulfills; stock reservation stays an admin-side decision (master doc §16).
- Legal/invoicing implications — out of client scope; coordinate with admin system.

## Parking lot (unscheduled)

- Search index (Algolia/Typesense or Firestore-native) if catalog outgrows client-side filtering (P2-1).
- Direct product/category URLs + shareability (needs router; currently `Navigator.push` only, no deep links).
- Image optimization: serve resized thumbnails instead of full-resolution originals in grids.
- PWA/installability polish; analytics events beyond the existing gtag pageview.

---

## Standing constraints

- This repo must never deploy Firestore rules (`firestore.rules` here is a read-only snapshot; keep it out of `firebase.json`).
- Every push to `main` deploys hosting to the live channel — treat `main` as production.
- The repo lives in OneDrive (disk-space constraint, owner decision): git commands can be slow and `git status` noisy. Prefer targeted git commands; never run bulk operations that touch thousands of files.
