-- Link expenses to a client for profitability, or leave null for company / misc.

alter table public.expenses
  add column if not exists client_id text references public.clients (id) on delete set null;

create index if not exists expenses_client_id_idx
  on public.expenses (client_id);

comment on column public.expenses.client_id is
  'Linked client for profitability; null = Company / Miscellaneous expense.';
