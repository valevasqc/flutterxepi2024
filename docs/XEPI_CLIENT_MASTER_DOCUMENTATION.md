# XEPI Client Master Documentation

Version 1.0  
Date: April 8, 2026  
Status: Client-side source-of-truth document

---

## 1. Purpose of this document

This document is the main source of truth for understanding the **XEPI Client App / Product Catalog**.

It is written so that someone with no prior knowledge of the project should be able to read it and understand:

- what XEPI is and what the client app is for
- how the client project fits into the larger XEPI system
- how the public shopping flow is supposed to work
- what the client app should and should not do
- what data the client app depends on
- what is in scope for the client MVP and what is not
- what the current implementation status is
- what the main gaps, risks, and open questions are

This document is intentionally **client-focused**. It includes only the admin-side context that is necessary to understand how the client app works. It does not try to document the full internal operations system.

When older client-side notes, AI-generated docs, or instruction files conflict with this document, this document should be treated as the canonical reference for the client project.

---

## 2. Executive summary

XEPI is a Guatemalan retail business that sells decorative and gift-oriented products such as cuadros de latón, accessories, toys, miniature houses, music boxes, puzzles, and airplanes.

The **XEPI Client App** is the public-facing product catalog. Its role is to let customers:

- browse products visually
- navigate categories and subcategories
- search products
- add products to a cart
- keep that cart locally
- send the cart to WhatsApp as an order request or checkout handoff

The client app is intentionally **lightweight**. It is not meant to be a full e-commerce checkout platform, not a full order-management system, and not the operational source of truth.

The **admin system** remains the source of truth for products, pricing, product activation, category structure, and inventory availability. The client app reads from that source and presents a customer-friendly browsing experience.

So the client project should be understood as:

**a public catalog and order-handoff layer that depends on reliable admin-side data**.

---

## 3. Historical context

Understanding the client project is easier if its evolution is made explicit.

### 3.1 Stage 1: Original manual business workflow

Before the newer systems, XEPI operated with fragmented manual tools:

- Excel for inventory counting and stock tracking
- WhatsApp chats for customer orders and inquiries
- manual handling of product information and customer communication

At this stage, there was no strong unified system connecting products, stock, and customer-facing visibility.

### 3.2 Stage 2: Legacy public catalog / static catalog approach

Before the current client-app direction, XEPI also had an older catalog-style approach that was more static and more manually maintained.

That older approach included patterns such as:

- manually managed category references
- older image-management flows
- a deprecated GitHub-based image workflow kept only for historical reference

This legacy catalog approach should be treated as a previous stage, not as the target architecture.

### 3.3 Stage 3: New database-connected client app

The current client project is the newer direction.

It is meant to be:

- connected to live catalog data in Firebase / Firestore
- driven by categories, subcategories, and product records
- visually polished enough for customers to browse comfortably
- simple in checkout behavior, using WhatsApp handoff rather than full payment processing

This is the model that should guide future work.

---

## 4. Business context relevant to the client project

### 4.1 What XEPI sells

XEPI is a retail business in Guatemala focused on decorative and gift-style products.

Known product groups include:

- cuadros de latón
- decorative accessories
- educational toys
- miniature houses
- music boxes
- puzzles
- airplanes

A large portion of the catalog is visual and image-driven, which makes the quality of the client browsing experience especially important.

### 4.2 How customers buy from XEPI

XEPI does not currently need a heavy traditional e-commerce flow with payment gateway, customer accounts, and order-management backend.

The intended public buying behavior is lighter:

1. customer browses the catalog
2. customer adds products to cart
3. customer sends the cart through WhatsApp
4. the business continues the human sales process from there

The client app therefore supports product discovery and purchase intent, not full transactional automation.

### 4.3 Why the client app matters

The client app matters because it gives XEPI a cleaner and more scalable public product experience than relying only on chat, memory, or social-post browsing.

It should help customers:

- discover products faster
- browse by visual groups
- avoid sending incomplete order requests
- send clearer WhatsApp orders

It should also help the business by reducing friction between interest and contact.

---

## 5. What the client project is

The XEPI Client App is a **public product-catalog web application**.

Its job is to present sellable products in a way that is:

- visually clear
- easy to navigate
- consistent with XEPI’s style
- simple enough for customers to use without instruction
- lightweight enough to maintain without turning into a full commerce platform

The app is not the business-control system. It is a customer-facing layer built on top of business-controlled catalog data.

---

## 6. What the client project is not

For planning and implementation, the client app should **not** be treated as:

- the source of truth for inventory
- the source of truth for product creation or editing
- the source of truth for sales ledgers
- a deposits or finance system
- an internal admin dashboard
- a full ERP or accounting tool
- a fully automated checkout/payment platform
- a customer-account platform unless explicitly added later

The client app should remain focused on catalog browsing and WhatsApp handoff unless there is a deliberate future decision to broaden scope.

---

## 7. Relationship to the admin system

The client and admin projects are related, but they are separate projects with different responsibilities.

### 7.1 Admin-side responsibilities relevant to the client app

The admin side owns the data and business rules that the client app depends on, especially:

- product records
- category and subcategory structure
- product images
- pricing values
- activation/deactivation state
- stock truth and sellable availability rules

### 7.2 Client-side responsibilities

The client side is responsible for:

- presenting that data to customers
- organizing it into a simple browsing flow
- letting customers build a cart
- turning the cart into a WhatsApp message

### 7.3 Practical dependency rule

The client app can only be as trustworthy as the admin-side data it reads.

That means:

- if product activation is wrong, customers may see the wrong products
- if prices are wrong, customers may see the wrong prices
- if stock visibility rules are weak, customers may see unavailable products
- if images are incomplete, the catalog experience degrades quickly

For this reason, the client app should always be documented and planned as **dependent on admin-side truth**, even though it remains a separate project.

---

## 8. Product vision for the client app

The ideal client app should feel like a clean, modern, low-friction catalog for XEPI’s products.

### 8.1 What success looks like

The client app is successful when:

- customers can understand the catalog quickly
- category navigation feels intuitive
- product images load well and look good
- the cart is easy to use
- WhatsApp handoff is clear and useful
- the app reflects real sellable products instead of stale catalog data
- the design feels consistent with XEPI’s visual language

### 8.2 Design philosophy

The client experience should prioritize:

- simplicity over feature overload
- visual clarity over dense data
- fast browsing over complicated workflows
- a polished web experience over unnecessary platform expansion
- consistency with existing XEPI colors and styling

---

## 9. Core client-side user journey

### 9.1 Home / category browsing

The customer lands on the catalog and sees primary categories.

This screen should immediately communicate:

- that XEPI has a varied catalog
- that categories are visually distinct
- that browsing is easy
- that the app is customer-facing, not operational

### 9.2 Subcategory navigation

Inside a primary category, the customer chooses among subcategories.

This allows the catalog to stay organized without overwhelming the customer with too many products at once.

### 9.3 Product browsing

Inside a subcategory, the customer sees products in a grid.

The product view should emphasize:

- image quality
- readable pricing
- simple add-to-cart behavior
- clear quantity adjustment

### 9.4 Search

Customers should be able to search globally across products.

Search is especially useful because XEPI has a broad catalog and many product variations.

### 9.5 Cart

The cart should be persistent and easy to edit.

Customers should be able to:

- review selected items
- change quantities
- understand pricing
- keep the cart even if the page reloads

### 9.6 WhatsApp handoff

The client app does not complete payment or create a formal internal order record on its own.

Instead, it hands off the cart through WhatsApp so the business can continue the order conversation.

This is a deliberate business choice, not a missing feature.

---

## 10. Core client features

The intended core feature set for the client app includes:

1. public product browsing
2. primary category navigation
3. subcategory navigation
4. product detail / product image viewing
5. global search
6. local cart persistence
7. quantity management in cart
8. WhatsApp checkout / handoff
9. direct product or page links where useful
10. responsive web layout

These are the core features the client app should be planned around.

---

## 11. Current known implementation shape

The current client project is not starting from zero.

It is already partly built and appears to be functional as a browsing, cart, and WhatsApp catalog experience. The current implementation is a Flutter web application with the main UI concentrated in `lib/main.dart`.

### 11.1 Current implemented behavior known from existing project notes

Known implemented or documented behaviors include:

- home page with category gallery
- subcategory navigation
- product grids
- global search
- cart with quantity controls
- local cart persistence using shared preferences
- WhatsApp message generation
- image display with caching
- responsive grid behavior for web
- public reads from Firestore collections

### 11.2 Current implementation style

The current client implementation appears to be relatively monolithic, with much of the app living in a single main UI file.

That is important context for future work because:

- it may be practical in the short term
- it may become harder to maintain as the app grows
- architecture decisions should not assume the current code layout is ideal

---

## 12. Technology context

### 12.1 Platform

The client app is currently a **Flutter web** application.

It should be treated as a web-first experience. Mobile apps are not the current target unless that decision changes later.

### 12.2 Backend services

The client app relies on Firebase services, especially:

- Firestore for public catalog reads
- Firebase Storage for product/category images
- Firebase Hosting for deployment

### 12.3 Relevant client-side packages and responsibilities

The current known stack includes patterns such as:

- `cloud_firestore` for reading catalog data
- `shared_preferences` for local cart persistence
- `cached_network_image` for image performance
- `url_launcher` for WhatsApp handoff

### 12.4 Authentication model

The intended public client app does not require customer authentication for browsing.

This is important because the app should feel immediately accessible to public users.

---

## 13. Client-side data model and dependencies

The client app depends on a relatively small set of read-side concepts.

### 13.1 Primary categories

Primary categories are top-level browsing groups.

Relevant category fields include:

- display name
- code / primary code
- cover image
- active state
- display order

### 13.2 Subcategories

Subcategories organize products within each primary category.

Relevant subcategory fields include:

- code
- subcategory name
- default price
- cover image
- active state
- display order

### 13.3 Products

Products are the main customer-visible items.

Relevant product fields for client behavior include:

- barcode or product identifier
- name
- category code
- primary category
- subcategory
- images / primary image
- price override
- active state
- display order
- warehouse code
- optional descriptive attributes such as size, color, or temas

### 13.4 Pricing dependency

The client display logic depends on category and product pricing rules.

The intended pricing pattern is:

- use product `priceOverride` when present
- otherwise inherit from the subcategory or category default price

This is an important rule because the client should not invent prices independently.

### 13.5 Image dependency

The client experience is heavily image-dependent.

That means product completeness is not just about text fields. The quality and availability of:

- category cover images
- subcategory cover images
- product images

are all part of the actual product experience.

---

## 14. Visibility rules

This is one of the most important sections of the client documentation.

### 14.1 Desired business rule

From a business perspective, the client app should show only products that are genuinely available for sale.

At a minimum, that should mean:

- the product is active
- the category/subcategory is active
- the product is actually sellable according to the chosen stock visibility rule

### 14.2 Current known implementation reality

The current implementation notes indicate that client visibility is still not fully aligned with the ideal business rule.

The currently known query pattern emphasizes:

- category/subcategory activation
- product `isActive`

and does **not yet clearly enforce stock-based hiding** in the client flow.

### 14.3 Why this matters

If visibility rules are weak, the client app can create one of the worst customer-facing failures:

- customers see products that the business does not really have available

For this reason, visibility logic should be treated as a core business rule, not a small UI detail.

---

## 15. Pricing and merchandising rules

### 15.1 General pricing rule

Products should not maintain a separate independent client-only pricing system.

The client should display prices from the business-controlled catalog model.

### 15.2 Special merchandising behavior

Existing notes indicate some category-specific behavior, especially for cuadros de latón, where presentation may differ from other categories.

Known or intended patterns include:

- cuadros de latón may show price prominently and omit product name in some views
- other categories may show both product name and price
- special bulk pricing rules may apply for some related category codes

### 15.3 Bulk pricing

The client app already appears to account for certain bulk-pricing behaviors in the cart and pricing display.

That means merchandising is not purely static display. Some pricing logic affects:

- line-item prices
- discount badges
- cart totals
- WhatsApp message clarity

---

## 16. WhatsApp handoff model

The client app’s checkout logic is intentionally centered on WhatsApp.

### 16.1 What the app should do

The app should:

- turn the cart into a human-readable message
- include product identifiers that help the business recognize the items
- preserve quantities and pricing context
- hand the user off smoothly to WhatsApp

### 16.2 What the app should not assume

The app should not assume that WhatsApp handoff is the same as:

- completed payment
- finalized internal sale
- reserved stock
- formally accepted order

Those are business-side or admin-side decisions.

### 16.3 Practical meaning

In practice, the client app creates **structured order intent**, not final order truth.

That distinction is important and should remain explicit in future planning.

---

## 17. Scope and non-goals

### 17.1 In scope for the client MVP

The client MVP should reliably provide:

- public catalog browsing
- category and subcategory navigation
- product display with images and pricing
- search
- persistent cart
- quantity editing
- WhatsApp handoff
- basic responsive web usability
- consistent visual styling
- dependable reading of active catalog data

### 17.2 Explicitly out of scope or lower priority

The following should be treated as lower priority or out of scope unless deliberately added later:

- payment gateway integration
- customer accounts and login
- order history for customers
- fully automated backend checkout
- complex shipping calculation
- discount-code system
- loyalty program
- legal invoicing
- client-side inventory mutations
- client-side finance logic

### 17.3 Scope guardrail

A useful rule for this project is:

**Do not let the client app slowly turn into the admin system.**

Its purpose is discovery, selection, and handoff.

---

## 18. Design system and UX expectations

The client app should stay visually consistent with XEPI’s current style language.

### 18.1 Palette

Known current palette references include:

- blue for action buttons and controls
- orange for prices and totals
- yellow for highlights and discount indicators
- dark gray for text or darker UI surfaces

This palette should remain consistent unless there is a deliberate design refresh.

### 18.2 Typography and assets

Known current design references include:

- Montserrat for stronger heading use
- Quicksand for body text
- XEPI logo asset usage

### 18.3 Layout behavior

The app should remain responsive across common web sizes.

Grid behavior and spacing should be treated as part of the product experience, not just implementation detail.

### 18.4 Image behavior

The product experience is visual, so image behavior matters.

Important expectations include:

- square-friendly product presentation where appropriate
- sensible fallback behavior when images are missing
- fast cached loading where possible
- fullscreen or enlarged image viewing where useful

---

## 19. Repository and codebase context

### 19.1 Current code organization

Existing notes indicate that:

- the client UI is primarily concentrated in `lib/main.dart`
- Firebase configuration is handled separately
- some admin-side reference code may exist in the broader repository context

### 19.2 Legacy and reference code

If legacy admin dashboard code or reference admin files are present in the same repository context, they should not be confused with the client runtime.

They may exist for historical or practical reasons and should not be casually deleted unless there is an explicit decision to retire them.

### 19.3 Planning implication

The client documentation should describe the **intended client product**, not simply mirror the current file layout.

---

## 20. Current status of the client project

The client project should currently be described as:

- **partly built**
- **functional in core browsing/cart/WhatsApp behavior**
- **not yet fully hardened**
- **still dependent on better alignment with admin-side stock truth**

### 20.1 What appears to already exist

The current client side appears to already support or partially support:

- category browsing
- subcategory browsing
- product listing
- search
- cart management
- local persistence
- WhatsApp handoff
- responsive display behavior
- image-heavy catalog presentation

### 20.2 What still appears to need work

The main remaining needs are likely around:

- stronger visibility rules
- alignment between client visibility and true sellable stock
- cleanup of legacy assumptions
- maintainability improvements
- production hardening and debugging confidence

### 20.3 How to talk about current status

The right description is not “we need to build the client app from zero.”

The better description is:

**the client app exists in meaningful form, but still needs integration hardening and rule clarification to be fully trustworthy.**

---

## 21. Known risks and ambiguities

### 21.1 Visibility mismatch risk

The biggest current risk is that the intended business rule and current client filtering behavior are not yet fully the same.

### 21.2 Catalog-quality dependency risk

The client app depends heavily on the quality of product records.

If records are incomplete or inconsistent, customer experience degrades even if the UI is functioning correctly.

### 21.3 Price-source ambiguity risk

If pricing inheritance is not cleanly maintained in admin-side data, the client can end up showing confusing or missing prices.

### 21.4 Monolithic code risk

A single-file or tightly coupled client codebase may work in the short term but can become harder to modify safely as the app grows.

### 21.5 Scope creep risk

Because the client app touches products, cart behavior, and WhatsApp handoff, there is a natural temptation to keep adding internal-business logic into it.

That should be resisted unless scope is explicitly changed.

---

## 22. Release readiness for the client app

A reasonable definition of client-side readiness should focus on trust and usability.

The client app is ready when:

- customers can browse without confusion
- prices display consistently
- images load reliably
- cart behavior is stable
- WhatsApp handoff is clean
- only intended products are visible
- the design feels coherent and polished
- the client app reflects the sellable catalog instead of stale catalog leftovers

---

## 23. Recommended future direction after the client MVP

Once the basic client experience is fully trustworthy, future enhancements could include:

1. stronger stock-aware visibility
2. cleaner direct product URLs and shareability
3. improved search quality
4. richer product details where useful
5. footer and business-information enhancements
6. performance and architecture cleanup
7. optional future commerce features only if the business actually needs them

These should come after the core browse-cart-WhatsApp experience is dependable.

---

## 24. Glossary

**Client app**: the public XEPI catalog used by customers.

**Admin system**: the internal XEPI business-control system.

**Primary category**: top-level customer browsing group.

**Subcategory**: second-level grouping within a primary category.

**Product visibility**: the rule that decides whether a product should appear publicly.

**Price override**: a product-specific price that replaces inherited category pricing.

**WhatsApp handoff**: sending the selected cart through WhatsApp instead of completing a full in-app checkout.

**Sellable availability**: whether a product should truly be shown to customers as available for sale.

---

## 25. Final summary

The XEPI Client App is a separate public-facing project whose purpose is to help customers browse products and send order intent through WhatsApp.

It is not the internal business system and should not try to become one.

Its success depends on three things:

1. a clean and attractive customer browsing experience
2. a simple and reliable cart-to-WhatsApp flow
3. dependable admin-side product, pricing, and visibility data

The client project already appears to exist in meaningful form, but it still needs stronger alignment with the business rules that determine what should be shown publicly.

This document should be used as the main baseline for future planning, implementation decisions, cleanup, and client-side documentation.
