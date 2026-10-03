# Sayge Constitution

Binding product and UI principles for the Sayge Flutter HRMS app.
All features, specs, and UI changes MUST comply.

## Core Principles

### I. No subtitles under titles (NON-NEGOTIABLE)

**Never** place a subtitle, secondary line, caption, or helper sentence
directly under a page title, section title, hub tile title, dialog title,
or list-card title.

- Page headers show the title only (plus actions / back / version as needed).
- Hub tiles (Settings, DMS, etc.) show **icon + title** only — no descriptive
  line under the title.
- Empty states and form field labels are allowed; they are not “subtitles
  under a title.”
- If explanation is required, use placeholder text, empty-state copy, or an
  inline form hint — not a subtitle beneath the heading.

### II. Button placements (NON-NEGOTIABLE)

Breakpoint: desktop = width ≥ 1024px; below that is mobile.

**Create / add buttons** (“New expense”, “New invoice”, “New proposal”, etc.)

| Viewport | Placement |
| --- | --- |
| Desktop | **Top-right** of the content toolbar (e.g. beside the search field). Never in a bottom sticky bar. |
| Mobile | Full-width **sticky bottom bar** (equal-width if paired). |

**Confirmation buttons** (Save, Cancel/Back, Preview, Update, Download, Send invite, etc.)

| Viewport | Placement |
| --- | --- |
| Desktop | **Bottom-right** of the screen/form footer. Right-aligned; intrinsic width — not stretched equal-width across the row. |
| Mobile | Full-width **sticky bottom bar**; 1–2 actions share the row equally. |

Rules:

- Do not use the mobile sticky full-bleed bar layout on desktop.
- Do not put Save/Cancel at the top on any viewport.
- Do not put “New …” at the bottom on desktop.
- Prefer `AppStickyActions` for confirm footers (it already right-aligns on desktop).

**Full main-panel width (desktop)**

- The content column (title/header at top **and** sticky action bar at bottom)
  MUST span the **entire width** of the main panel beside the sidebar — not a
  centered inset card, and not capped to a narrow max-width that leaves empty
  gutters on the right.
- Top chrome (page title, version, toolbar create buttons) and bottom chrome
  (Save / Cancel) share the same left/right edges as the form/list body.
- Horizontal page padding (e.g. 32px) is fine; a floating card that shrinks the
  action bar away from the panel edge is not.

### III. Navigation completeness

- Every Finances leaf (Payroll, Proposals, Invoices, Expense) MUST remain
  reachable from the sidebar / drawer without hunting.
- Sections with children default to expanded so icons and labels stay visible
  on short viewports (including mobile web).

### IV. Version display

- App version is three-part semver only (`vMAJOR.MINOR.PATCH`).
- Never show a `+build` suffix in the UI.

### V. Auth & invites

- Employee passwords are never set by admins in the UI.
- Invite via email link; invitee sets their own password on `/set-password`.
- Web MUST use **path** URL strategy so Supabase auth hash fragments are never
  routed by go_router (e.g. `#sb…` must not become location `/sb`).
- Invite redirect URL: `https://saaaasify.netlify.app/set-password`
  (also allowlisted in Supabase → Authentication → URL Configuration).

### VI. Role-based access (NON-NEGOTIABLE)

**Staff** = role code `owner` or `admin` — full access to every module.

**Employee** = any other role — only:

- Single sidebar item: **Dashboard** (not My details / Finances trees)
- On Dashboard (one scrollable page): own profile/details, compensation
  breakdown, salary slip download, and expenses (list + add)
- Own compensation deep-link (view) from Dashboard

Employees MUST NOT access: all-employees list, add/edit others, DMS, proposals,
invoices, settings (invite, clients, company, roles, ledger), or other people’s
payroll/data.

Enforce in UI (nav + route guards) **and** data layer / RLS
(`supabase/fix_rbac_policies.sql`). Hiding nav alone is not enough.

### VII. Logout (NON-NEGOTIABLE)

- Sidebar / drawer MUST expose **Log out**.
- Logout MUST wipe: Supabase session (`signOut`), in-memory `AuthSession`,
  all SharedPreferences, then navigate to `/login` with empty credentials.
- No flash of prior name/role/email after logout.

## Governance

- This constitution overrides ad-hoc UI habits when they conflict.
- Amendments require an explicit product decision and a version bump below.

**Version:** 1.4.0  
**Last updated:** 2026-10-03
