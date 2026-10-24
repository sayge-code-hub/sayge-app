# Supabase apply order

Always finish with `security_hardening.sql`, then run `security_verification.sql`.

## Fresh project

1. `schema.sql`
2. Feature packs you use (any order):
   - `expenses_client_id.sql`, `fix_expense_approval.sql`
   - `ops_completeness_pack.sql` (invoice payment columns, receipts, payroll tables)
   - `expense_categories.sql`
   - `proposals_status_lifecycle.sql`
   - `invoices_payment_status_sent.sql` (only if payment_status existed without `sent`)
   - `employees_date_of_birth.sql`
   - `dms_entities_subtitle.sql`
   - `lock_signup_provisioning.sql`
   - `pos.sql`, then `pos_product_commerce.sql` (legacy retail catalog; optional)
   - `cafe_pos.sql` (Client-scoped Cafe POS MVP — preferred)
3. `security_hardening.sql` (**last**)
4. `security_verification.sql` — checks 1–3, 7–9, 14 must be empty
5. Deploy edge function: `supabase functions deploy invite-employee --no-verify-jwt`

## Existing production (incremental)

Run only the missing pieces, then **always** re-run `security_hardening.sql`.

Minimum for recent app features:

```text
employees_date_of_birth.sql
dms_entities_subtitle.sql
expense_categories.sql
proposals_status_lifecycle.sql
invoices_payment_status_sent.sql
lock_signup_provisioning.sql
cafe_pos.sql
security_hardening.sql
security_verification.sql
```

After `lock_signup_provisioning.sql`: Dashboard → **Authentication → Providers → Email** → turn **off** “Allow new users to sign up”.

## Do not run on production

- `clean_dms.sql`
- `fix_employees_client_fk_set_null.sql` (deletes clients)
- Hardcoded `UPDATE` sections in `employees_monthly_rate.sql` / `employees_special_allowance.sql` / `employees_tds_amount.sql`
- Superseded `fix_rbac_policies.sql` unless you immediately re-harden

## Why hardening is last

Feature packs may recreate weaker policies or guards. Hardening drops and recreates the authoritative RLS set.
