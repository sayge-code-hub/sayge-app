# Sayge App

Flutter mobile + web app using **BLoC** and **clean architecture**. Data comes from **Supabase** only (no demo/mock layer).

## Structure

```
lib/
├── core/                  # Shared theme, widgets, errors, config
│   ├── config/
│   ├── theme/
│   ├── widgets/
│   ├── error/
│   └── utils/
├── features/
│   ├── auth/
│   ├── employees/
│   ├── clients/
│   ├── documents/
│   └── settings/
├── injection_container.dart
└── main.dart
```

## Setup

1. Copy `.env.example` → `.env` and fill in values from Supabase → Project Settings → API:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   (`.env` is gitignored and bundled at runtime. Never commit keys, and never put
   the service-role key in the app.)
2. Apply the database setup: `./scripts/setup_supabase.sh`

   The script applies two files **in this order** — both are required:

   | Order | File | Purpose |
   | --- | --- | --- |
   | 1 | `supabase/schema.sql` | Tables, triggers, storage buckets. Enables RLS but defines **no** policies, so a half-finished setup is deny-all rather than open. |
   | 2 | `supabase/security_hardening.sql` | Authoritative grants + RLS policies. Revokes every `anon` privilege, drops all existing policies, and recreates them for `authenticated` only. Requires `users.is_active` for role helpers. |
   | 3 | Feature packs (as needed) | `ops_completeness_pack.sql` (invoice payment + payroll + expense receipts), `expense_categories.sql`, `pos.sql` + `pos_product_commerce.sql`, then **re-run** `security_hardening.sql`. |
   | 4 | `supabase/security_verification.sql` | Asserts anon is still locked down. |

   Without `SUPABASE_DB_URL`/`psql`, paste the files into Supabase → SQL Editor
   in the same order. The script then verifies the result.

   - Creates `roles` + `users` (profiles linked to Auth), HRMS/DMS tables
   - Employees link to clients via `client_id` (delete client sets `client_id` null)
   - `activity_log` records every insert/update/delete on app tables
   - **Do not** re-run `ops_completeness_pack.sql` or `fix_rbac_policies.sql` after
     hardening without applying `security_hardening.sql` again last — those packs
     can loosen payroll field guards.
3. **Existing project upgrade (gaps pack):** run `supabase/production_gaps_pack.sql`
   (adds `date_of_birth`, DMS `subtitle`, active-user guards, employee-readable
   expense categories). Then run any still-pending feature scripts
   (`invoices_payment_status_sent.sql`, `proposals_status_lifecycle.sql`,
   `expense_categories.sql`, `lock_signup_provisioning.sql`) and finish with
   `security_verification.sql`. `security_hardening.sql` remains safe to re-run
   on its own.
4. **Invite-only Auth:** Dashboard → Authentication → Providers → Email → turn
   **off** “Allow new users to sign up”. Provision via Settings → Invite
   employee (or `lock_signup_provisioning.sql` + invite edge function). Open
   self-signup no longer creates a `public.users` profile.
5. Bootstrap the first owner once (e.g. `aditya.rana@sayge.in` via Dashboard
   invite or schema backfill) so invites can be sent.

Only `@sayge.in` emails are accepted at login.

## Database access model

Anonymous (`anon`) has no privilege and appears in no policy on any table in
`public`. Everything below applies to signed-in users only.

| Data | Employee | Owner / Admin |
| --- | --- | --- |
| Clients, proposals + line items, invoices + line items, company details, payroll runs, POS | no access | full |
| Expense categories | read | full |
| Employees | own row only | full |
| Users | own row only | full |
| Documents | own employee documents | full |
| Employee purchase orders | read own | full |
| Expenses | own rows | full, incl. approval |
| Payslips | read own | full |
| Activity log | no access | read-only |
| Roles | read | full |

Read access is **row-level**. Where the table says "own row", the employee
reads that row *in full* — their own `employees` row includes their CTC, bank
details and PAN. This is deliberate: it is their own data, already shown on
their payslip. They cannot read any other employee's row. RLS cannot hide
individual columns; contact-only visibility would require a column-restricted
view and app query changes, which this migration does not do.

Write access is narrowed per column by `BEFORE UPDATE` guard triggers that use
an explicit **allowlist** — a column added to the table later is locked by
default:

| Table | Employee may change | Blocked |
| --- | --- | --- |
| `employees` | `contact_no`, `alternate_contact`, `personal_email`, `residential_address`, `pincode`, `nationality`, `gender`, `father_name`, `mother_name`, `photo_path` | everything else, incl. CTC, `monthly_rate`, `tds_amount`, `special_allowance`, `medical_insurance`, `retention_amount`, `pf_applicable`, `pt_applicable`, bank/PAN/UAN, `grade`, `designation`, `client_id`, `is_active`, `date_of_exit` |
| `users` | `full_name`, `avatar_path` | `role_id`, `email`, `employee_id`, `is_active` |
| `expenses` | own claim while `approval_status = 'pending'` | `approval_status`, `approved_by`, `approved_at` (staff only) |

Storage buckets:

- Public (intentional, branding/profile imagery only): `brand-logos`,
  `pos-product-images`, `user-avatars`, `employee-avatars`
- Private (HR / contractual / financial files): `documents`, `employee-pos` —
  read through short-lived signed URLs that still evaluate RLS

In the private `documents` bucket, staff may write anywhere. An employee may
write only into their own folder, `documents/employee/<their employee_id>/…`,
or an `expenses/<expense_id>/…` receipt for a claim they submitted; they cannot
upload into another employee's folder or into company/vendor/candidate paths.

Functions in `public` have `EXECUTE` revoked from `PUBLIC` (which `anon`
inherits) rather than from `anon` alone. Only `app_role_code()`,
`app_is_staff()` and `app_employee_id()` are granted back, to `authenticated`
and `service_role`. Extension-owned functions are left untouched.

## Verify security

```bash
./scripts/setup_supabase.sh   # exits non-zero if any table answers 200 to anon
```

Then run `supabase/security_verification.sql` in the SQL Editor. Checks 1, 2,
3, 7, 8, 9 and 14 must return zero rows; checks 4, 5, 6, 10–13 are inventories
with the expected result noted above each query. Check 11 reports each expected
table as `ok`, `missing (optional feature not installed)`, or `EXPOSED - …`, so
an uninstalled feature pack is never mistaken for a leak. Check 14 flags the
degraded mode where a skipped prerequisite migration has silently made expenses
staff-only. Do not paste keys into the editor or into tickets — read them from
your local `.env`.

## CI gates

GitHub Actions runs **analyze + tests** on every pull request and push to `main`
(`.github/workflows/ci.yml`). Production Netlify deploys also run the same
checks **before** version bump / build (`.github/workflows/deploy-netlify.yml`).

To block merging a red PR: GitHub → **Settings → Branches → Add rule** for
`main` → require status check **Analyze & test**.

## Run

```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # mobile / desktop
```

After login: **Modules → HRMS → Employees**, **DMS**, and **Settings → Manage clients**.
