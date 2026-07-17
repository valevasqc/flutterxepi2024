# XEPI Client Catalog Copilot Instructions

Use this file for the public/client catalog project.
For full context, read `XEPI_MASTER_DOCUMENTATION.md`.

## What this project is
This is the public-facing catalog for browsing products, keeping a local cart, and sending the cart to WhatsApp.
It is not the operational source of truth.

## System boundary
Admin owns product control, stock truth, pricing rules, sales, delivery operations, cash, deposits, expenses, and reports.
Client owns browsing UI, search, cart persistence, product presentation, and WhatsApp handoff.

## Important rules
- Do not recreate admin logic in the client app.
- Keep the app lightweight and simple.
- Keep pricing display aligned with admin rules.
- Product visibility should align with the admin-side source of truth, not just historical client assumptions.
- WhatsApp handoff is not a completed sale.

## Style rules
- Spanish UI, English code.
- Keep the XEPI palette, typography, spacing, and overall visual style consistent.
- Do not introduce unnecessary complexity.

## Legacy note
This app comes from the older static catalog layer, but the protected no-delete rule still applies to legacy admin dashboard files in the wider project.
