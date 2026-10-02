-- Tax Invoices — run in Supabase SQL Editor if tables are missing.

create table if not exists public.invoices (
  id text primary key,
  invoice_no text not null unique,
  invoice_date date not null,
  po_number text not null default '',
  place_of_supply text not null default '',
  buyer_name text not null default '',
  buyer_company text not null default '',
  buyer_address text not null default '',
  buyer_gstin text not null default '',
  buyer_contact text not null default '',
  intra_state boolean not null default true,
  taxable_amount numeric(14, 2) not null default 0,
  cgst_amount numeric(14, 2) not null default 0,
  sgst_amount numeric(14, 2) not null default 0,
  igst_amount numeric(14, 2) not null default 0,
  total_amount numeric(14, 2) not null default 0,
  amount_in_words text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists invoices_invoice_date_idx
  on public.invoices (invoice_date desc);

drop trigger if exists invoices_set_updated_at on public.invoices;
create trigger invoices_set_updated_at
  before update on public.invoices
  for each row execute function public.set_updated_at();

alter table public.invoices enable row level security;

drop policy if exists "invoices_select_anon" on public.invoices;
drop policy if exists "invoices_insert_anon" on public.invoices;
drop policy if exists "invoices_update_anon" on public.invoices;
drop policy if exists "invoices_delete_anon" on public.invoices;

create policy "invoices_select_anon" on public.invoices for select to anon, authenticated using (true);
create policy "invoices_insert_anon" on public.invoices for insert to anon, authenticated with check (true);
create policy "invoices_update_anon" on public.invoices for update to anon, authenticated using (true) with check (true);
create policy "invoices_delete_anon" on public.invoices for delete to anon, authenticated using (true);

grant select, insert, update, delete on public.invoices to anon, authenticated;

create table if not exists public.invoice_line_items (
  id text primary key,
  invoice_id text not null references public.invoices (id) on delete cascade,
  sort_order int not null default 0,
  particulars text not null default '',
  amount numeric(14, 2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists invoice_line_items_invoice_idx
  on public.invoice_line_items (invoice_id, sort_order);

alter table public.invoice_line_items enable row level security;

drop policy if exists "invoice_line_items_select_anon" on public.invoice_line_items;
drop policy if exists "invoice_line_items_insert_anon" on public.invoice_line_items;
drop policy if exists "invoice_line_items_update_anon" on public.invoice_line_items;
drop policy if exists "invoice_line_items_delete_anon" on public.invoice_line_items;

create policy "invoice_line_items_select_anon" on public.invoice_line_items for select to anon, authenticated using (true);
create policy "invoice_line_items_insert_anon" on public.invoice_line_items for insert to anon, authenticated with check (true);
create policy "invoice_line_items_update_anon" on public.invoice_line_items for update to anon, authenticated using (true) with check (true);
create policy "invoice_line_items_delete_anon" on public.invoice_line_items for delete to anon, authenticated using (true);

grant select, insert, update, delete on public.invoice_line_items to anon, authenticated;

do $$
begin
  drop trigger if exists invoices_activity_log on public.invoices;
  create trigger invoices_activity_log
    after insert or update or delete on public.invoices
    for each row execute function public.log_row_activity();
  drop trigger if exists invoice_line_items_activity_log on public.invoice_line_items;
  create trigger invoice_line_items_activity_log
    after insert or update or delete on public.invoice_line_items
    for each row execute function public.log_row_activity();
end $$;
