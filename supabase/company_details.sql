-- Company details (seller / bank info for invoices) — run in Supabase SQL Editor.

create table if not exists public.company_details (
  id text primary key,
  name text not null unique,
  display_name text not null default '',
  address text not null default '',
  gstin text not null default '',
  pan text not null default '',
  sac_code text not null default '',
  telephone text not null default '',
  email text not null default '',
  bank_name text not null default '',
  bank_account_no text not null default '',
  bank_branch text not null default '',
  bank_ifsc text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists company_details_name_idx
  on public.company_details (name);

drop trigger if exists company_details_set_updated_at on public.company_details;
create trigger company_details_set_updated_at
  before update on public.company_details
  for each row execute function public.set_updated_at();

alter table public.company_details enable row level security;

drop policy if exists "company_details_select_anon" on public.company_details;
drop policy if exists "company_details_insert_anon" on public.company_details;
drop policy if exists "company_details_update_anon" on public.company_details;
drop policy if exists "company_details_delete_anon" on public.company_details;

create policy "company_details_select_anon"
  on public.company_details for select
  to anon, authenticated
  using (true);

create policy "company_details_insert_anon"
  on public.company_details for insert
  to anon, authenticated
  with check (true);

create policy "company_details_update_anon"
  on public.company_details for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "company_details_delete_anon"
  on public.company_details for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.company_details to anon, authenticated;

insert into public.company_details (
  id,
  name,
  display_name,
  address,
  gstin,
  pan,
  sac_code,
  telephone,
  email,
  bank_name,
  bank_account_no,
  bank_branch,
  bank_ifsc
)
values (
  'company_sayge',
  'sayge',
  'Sayge',
  'Harsh Co-op society, Pandey Layout, Khamla Rd, Nagpur',
  '27AEAFS9363N1ZB',
  'AEAFS9363N',
  '998311',
  '8788681499',
  'humans@sayge.com',
  'The Maharashtra State Co. Op. Bank Ltd.',
  '0056107040000517',
  'Deonagar Branch',
  'MSCI0082051'
)
on conflict (name) do update set
  display_name = excluded.display_name,
  address = excluded.address,
  gstin = excluded.gstin,
  pan = excluded.pan,
  sac_code = excluded.sac_code,
  telephone = excluded.telephone,
  email = excluded.email,
  bank_name = excluded.bank_name,
  bank_account_no = excluded.bank_account_no,
  bank_branch = excluded.bank_branch,
  bank_ifsc = excluded.bank_ifsc,
  updated_at = now();

do $$
begin
  drop trigger if exists company_details_activity_log on public.company_details;
  create trigger company_details_activity_log
    after insert or update or delete on public.company_details
    for each row execute function public.log_row_activity();
exception
  when undefined_function then
    null;
end $$;
