-- Invoice status for bills that have been sent and are still unpaid.
-- Run in the Supabase SQL Editor (idempotent).

alter table public.invoices
  drop constraint if exists invoices_payment_status_check;

alter table public.invoices
  add constraint invoices_payment_status_check
  check (payment_status in ('unpaid', 'sent', 'partial', 'paid', 'overdue'));
