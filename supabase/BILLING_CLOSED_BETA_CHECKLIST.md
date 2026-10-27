# Closed-beta billing — ops checklist

Apply after `security_hardening.sql`:

```text
billing_closed_beta.sql
```

Seed: Growth plan, POS enabled, current period marked **paid**.

## Manual scenarios

1. Settings → Billing loads plan, seats, period status.
2. Switch Free → add employees until 5th succeeds, 6th blocked (UI + DB).
3. Exit one employee → add succeeds again.
4. Save draft beyond cap → OK; activate draft at cap → blocked.
5. Rehire at cap → blocked; Growth at 30 → “Contact us”.
6. Mark current period unpaid → banner past due; writes still work in grace.
7. Set grace_days=0 and unpaid → read-only dialog on invoice/expense/proposal save; Billing still editable; mark paid restores writes.
8. Create offer (50% or fixed) → apply → amount due updates; clear offer restores list price.
9. Toggle Cafe POS access off → POS nav hidden for staff; cafes page shows disabled; people modules unaffected.

No payment gateway. Mark paid after bank/UPI transfer.
