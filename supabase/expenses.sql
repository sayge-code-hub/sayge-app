-- Expenses — run in Supabase SQL Editor if the table is missing.

create table if not exists public.expenses (
  id text primary key,
  made_for text not null default '',
  amount numeric(14, 2) not null default 0,
  paid_from text not null default '',
  category text not null default '',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expenses_category_chk check (
    category in (
      'Software Tools',
      'Commissions',
      'CA',
      'Accountant Consulting',
      'Misc'
    )
  )
);

create index if not exists expenses_created_at_idx
  on public.expenses (created_at desc);
create index if not exists expenses_category_idx
  on public.expenses (category);

drop trigger if exists expenses_set_updated_at on public.expenses;
create trigger expenses_set_updated_at
  before update on public.expenses
  for each row
  execute function public.set_updated_at();

alter table public.expenses enable row level security;

drop policy if exists "expenses_select_anon" on public.expenses;
drop policy if exists "expenses_insert_anon" on public.expenses;
drop policy if exists "expenses_update_anon" on public.expenses;
drop policy if exists "expenses_delete_anon" on public.expenses;

create policy "expenses_select_anon"
  on public.expenses for select
  to anon, authenticated
  using (true);

create policy "expenses_insert_anon"
  on public.expenses for insert
  to anon, authenticated
  with check (true);

create policy "expenses_update_anon"
  on public.expenses for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "expenses_delete_anon"
  on public.expenses for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.expenses to anon, authenticated;

do $$
begin
  drop trigger if exists expenses_activity_log on public.expenses;
  create trigger expenses_activity_log
    after insert or update or delete on public.expenses
    for each row execute function public.log_row_activity();
end $$;
