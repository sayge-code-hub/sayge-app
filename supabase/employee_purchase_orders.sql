-- Employee Purchase Orders — run in Supabase SQL Editor if table is missing.
-- Also creates Storage bucket `employee-pos` for PDF files.

create table if not exists public.employee_purchase_orders (
  id text primary key,
  employee_id text not null references public.employees (employee_id) on delete cascade,
  po_number text not null,
  start_date date not null,
  end_date date not null,
  file_name text not null default '',
  mime_type text not null default 'application/pdf',
  file_size_bytes bigint not null default 0,
  storage_path text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint employee_purchase_orders_dates_chk check (end_date >= start_date)
);

create index if not exists employee_purchase_orders_employee_idx
  on public.employee_purchase_orders (employee_id, start_date desc);

drop trigger if exists employee_purchase_orders_set_updated_at
  on public.employee_purchase_orders;
create trigger employee_purchase_orders_set_updated_at
  before update on public.employee_purchase_orders
  for each row
  execute function public.set_updated_at();

alter table public.employee_purchase_orders enable row level security;

drop policy if exists "employee_purchase_orders_select_anon"
  on public.employee_purchase_orders;
drop policy if exists "employee_purchase_orders_insert_anon"
  on public.employee_purchase_orders;
drop policy if exists "employee_purchase_orders_update_anon"
  on public.employee_purchase_orders;
drop policy if exists "employee_purchase_orders_delete_anon"
  on public.employee_purchase_orders;
-- Access rules: supabase/security_hardening.sql (run after this file).

do $$
begin
  drop trigger if exists employee_purchase_orders_activity_log
    on public.employee_purchase_orders;
  create trigger employee_purchase_orders_activity_log
    after insert or update or delete on public.employee_purchase_orders
    for each row execute function public.log_row_activity();
end $$;

insert into storage.buckets (id, name, public)
values ('employee-pos', 'employee-pos', false)
on conflict (id) do update set public = false;

drop policy if exists "employee_pos_storage_select" on storage.objects;
drop policy if exists "employee_pos_storage_insert" on storage.objects;
drop policy if exists "employee_pos_storage_update" on storage.objects;
drop policy if exists "employee_pos_storage_delete" on storage.objects;
-- Storage policies: supabase/security_hardening.sql (run after this file).
