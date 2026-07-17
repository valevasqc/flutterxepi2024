# AGENTS.md - XEPI Client Catalog

> Companion docs: [CLAUDE.md](CLAUDE.md) (quick orientation) · [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) (prioritized defects — P0-1 explains why the app is currently broken against live rules) · [docs/ROADMAP.md](docs/ROADMAP.md) (decided architecture + migration rules).

## What this project is
XEPI Client Catalog is the public-facing browsing app. Customers can:
- browse products by category and subcategory
- view product images and prices
- search products
- keep a local cart
- send the cart to WhatsApp

It is a lightweight catalog and order handoff experience, not the business-control system.

## Relationship to the rest of XEPI
This app descends from the older static catalog layer.
It is separate from the admin app.
The admin app is the operational source of truth.

## What this project is not
- not the source of truth for inventory
- not a payment checkout system
- not the place for complex order management
- not where stock, deposits, expenses, or operational finance logic should live

## Business boundary
Admin owns:
- product creation and editing
- category activation
- stock truth
- pricing source-of-truth rules
- sales and delivery operations
- pending cash, deposits, expenses, and reports

Client owns:
- browsing UI
- search UI
- cart persistence
- product presentation
- WhatsApp handoff

Do not move admin responsibilities into the client app.

## Important business rule
The intended business rule is:
- customers should only see products that are actually valid for sale

Current code may only filter `isActive`.
Do not assume that is the final correct rule just because it exists.
If you touch visibility logic, align it with the agreed admin-side source of truth instead of reinforcing the mismatch.

## Data expectations
Likely Firestore dependencies:
- `categories`
- nested `subcategories`
- `products`

Client should primarily read display-safe fields such as:
- `isActive`
- category and subcategory relationships
- images
- pricing fields
- warehouse or display codes when needed for WhatsApp formatting

## Bulk pricing
If client pricing logic mirrors admin pricing logic, keep it aligned with the category rules. Do not let client and admin drift into separate pricing behaviors.

## WhatsApp handoff
The checkout is a handoff to WhatsApp, not a completed sale.
Do not model client checkout as if it already created an admin-side sale unless a deliberate integration feature is added.

## Style and UI rules
- Spanish UI, English code.
- Keep the existing XEPI palette, typography, spacing, and general visual language consistent.
- Keep the app lightweight, fast, and simple.
- Do not turn this project into a second inventory system or back office.

## Protected legacy rule
- Do not delete protected legacy admin or dashboard references if they are present in the wider workspace.
- The old catalog context is historical, but the protected no-delete rule still applies to legacy admin dashboard files in the overall project.

## Commands
- `flutter pub get`
- `flutter run -d chrome`
- `flutter analyze`

## Default mindset
This app should stay simple.
Complexity belongs in admin, not in the public catalog.
