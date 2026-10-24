-- Expense categories managed from Settings.
-- Run once in the Supabase SQL editor.

create table if not exists public.expense_categories (
  id text primary key,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists expense_categories_name_lower_idx
  on public.expense_categories (lower(name));

insert into public.expense_categories (id, name, sort_order)
values
  ('cat_software_tools', 'Software Tools', 0),
  ('cat_commissions', 'Commissions', 1),
  ('cat_ca', 'CA', 2),
  ('cat_accountant', 'Accountant Consulting', 3),
  ('cat_misc', 'Misc', 4)
on conflict (id) do nothing;

alter table public.expenses
  drop constraint if exists expenses_category_chk;

alter table public.expense_categories enable row level security;

drop policy if exists "expense_categories_select" on public.expense_categories;
drop policy if exists "expense_categories_insert" on public.expense_categories;
drop policy if exists "expense_categories_update" on public.expense_categories;
drop policy if exists "expense_categories_delete" on public.expense_categories;
-- Access rules: supabase/security_hardening.sql (run after this file).
-- Employees may SELECT categories; only staff may write.
