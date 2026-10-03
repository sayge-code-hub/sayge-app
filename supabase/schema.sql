-- Sayge HRMS / DMS schema (no seed data — live data only)
-- Run via: ./scripts/setup_supabase.sh
-- Or paste into Supabase Dashboard → SQL Editor → Run

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Roles (editable catalog — add/rename without app code changes)
-- ---------------------------------------------------------------------------

create table if not exists public.roles (
  id text primary key,
  code text not null unique,
  label text not null,
  description text not null default '',
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists roles_sort_order_idx on public.roles (sort_order);
create index if not exists roles_is_active_idx on public.roles (is_active);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists roles_set_updated_at on public.roles;
create trigger roles_set_updated_at
  before update on public.roles
  for each row
  execute function public.set_updated_at();

alter table public.roles enable row level security;

drop policy if exists "roles_select_anon" on public.roles;
drop policy if exists "roles_insert_anon" on public.roles;
drop policy if exists "roles_update_anon" on public.roles;
drop policy if exists "roles_delete_anon" on public.roles;

create policy "roles_select_anon"
  on public.roles for select
  to anon, authenticated
  using (true);

create policy "roles_insert_anon"
  on public.roles for insert
  to anon, authenticated
  with check (true);

create policy "roles_update_anon"
  on public.roles for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "roles_delete_anon"
  on public.roles for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.roles to anon, authenticated;

-- System role rows (reference catalog, not demo business data).
-- ON CONFLICT DO NOTHING preserves labels/descriptions edited in the dashboard.
insert into public.roles (id, code, label, description, sort_order)
values
  ('role_owner', 'owner', 'Owner', 'Full access; company owner', 10),
  ('role_admin', 'admin', 'Admin', 'Administrative access', 20),
  ('role_hr', 'hr', 'HR', 'Human resources', 30),
  ('role_team_lead', 'team_lead', 'Team Lead', 'Team leadership', 40),
  ('role_employee', 'employee', 'Employee', 'Standard employee access', 50)
on conflict (id) do nothing;

create table if not exists public.clients (
  id text primary key,
  name text not null,
  vendor_code text not null default '',
  entity_code text not null default '',
  contact_name text not null default '',
  address text not null default '',
  gstin text not null default '',
  created_at timestamptz not null default now()
);

-- Existing projects that already have clients (id, name only)
alter table public.clients
  add column if not exists vendor_code text not null default '';
alter table public.clients
  add column if not exists entity_code text not null default '';
alter table public.clients
  add column if not exists contact_name text not null default '';
alter table public.clients
  add column if not exists address text not null default '';
alter table public.clients
  add column if not exists gstin text not null default '';

-- Allow multiple contacts per company (e.g. Ketan Jain + Jaspreet Lamba).
alter table public.clients drop constraint if exists clients_name_key;

create index if not exists clients_name_idx on public.clients (name);

alter table public.clients enable row level security;

drop policy if exists "clients_select_anon" on public.clients;
drop policy if exists "clients_insert_anon" on public.clients;
drop policy if exists "clients_update_anon" on public.clients;
drop policy if exists "clients_delete_anon" on public.clients;

create policy "clients_select_anon"
  on public.clients for select
  to anon, authenticated
  using (true);

create policy "clients_insert_anon"
  on public.clients for insert
  to anon, authenticated
  with check (true);

create policy "clients_update_anon"
  on public.clients for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "clients_delete_anon"
  on public.clients for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.clients to anon, authenticated;

create table if not exists public.employees (
  employee_id text primary key,
  employee_name text not null,
  date_of_joining date not null,
  designation text not null,
  department text not null,
  annual_ctc numeric(14, 2) not null,
  monthly_ctc numeric(14, 2) not null,
  pf_applicable boolean not null default true,
  pt_applicable boolean not null default true,
  medical_insurance numeric(14, 2) not null default 650,
  retention_amount numeric(14, 2) not null default 2000,
  tds_amount numeric(14, 2) not null default 0,
  special_allowance numeric(14, 2) not null default 0,
  bank_account text not null default '',
  ifsc text not null default '',
  pan text not null,
  uan text not null default '',
  is_active boolean not null default true,
  location text not null,
  grade text not null,
  client_id text references public.clients (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Upgrade path: legacy free-text `client` → linked `client_id`
alter table public.employees add column if not exists client_id text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'employees'
      and column_name = 'client'
  ) then
    insert into public.clients (id, name)
    select
      coalesce(
        nullif(
          trim(both '-' from lower(regexp_replace(trim(e.client), '[^a-z0-9]+', '-', 'g'))),
          ''
        ),
        'client'
      ),
      trim(e.client)
    from public.employees e
    where coalesce(trim(e.client), '') <> ''
      and not exists (
        select 1 from public.clients c where c.name = trim(e.client)
      )
    on conflict (id) do nothing;

    update public.employees e
    set client_id = c.id
    from public.clients c
    where e.client_id is null
      and trim(e.client) = c.name;

    alter table public.employees drop column client;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'employees'
      and column_name = 'client_id'
  ) then
    -- Allow client deletes without removing employees (FK SET NULL).
    alter table public.employees
      alter column client_id drop not null;

    alter table public.employees
      drop constraint if exists employees_client_id_fkey;

    alter table public.employees
      add constraint employees_client_id_fkey
      foreign key (client_id)
      references public.clients (id)
      on delete set null;
  end if;
end $$;

drop index if exists employees_client_idx;
create index if not exists employees_is_active_idx on public.employees (is_active);
create index if not exists employees_client_id_idx on public.employees (client_id);
create index if not exists employees_name_idx on public.employees (employee_name);

drop trigger if exists employees_set_updated_at on public.employees;
create trigger employees_set_updated_at
  before update on public.employees
  for each row
  execute function public.set_updated_at();

alter table public.employees enable row level security;

drop policy if exists "employees_select_anon" on public.employees;
drop policy if exists "employees_insert_anon" on public.employees;
drop policy if exists "employees_update_anon" on public.employees;
drop policy if exists "employees_delete_anon" on public.employees;

-- Open policies for prototype. Tighten once role-based Auth is finalized.
create policy "employees_select_anon"
  on public.employees for select
  to anon, authenticated
  using (true);

create policy "employees_insert_anon"
  on public.employees for insert
  to anon, authenticated
  with check (true);

create policy "employees_update_anon"
  on public.employees for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "employees_delete_anon"
  on public.employees for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.employees to anon, authenticated;

-- ---------------------------------------------------------------------------
-- DMS (Document Management System)
-- Metadata only; binary files belong in a Storage bucket (e.g. "documents").
-- ---------------------------------------------------------------------------

create table if not exists public.dms_entities (
  id text primary key,
  name text not null,
  entity_type text not null check (
    entity_type in ('company', 'vendor', 'employee', 'candidate')
  ),
  created_at timestamptz not null default now()
);

create index if not exists dms_entities_type_idx
  on public.dms_entities (entity_type);
create index if not exists dms_entities_name_idx
  on public.dms_entities (name);

alter table public.dms_entities enable row level security;

drop policy if exists "dms_entities_select_anon" on public.dms_entities;
drop policy if exists "dms_entities_insert_anon" on public.dms_entities;
drop policy if exists "dms_entities_update_anon" on public.dms_entities;
drop policy if exists "dms_entities_delete_anon" on public.dms_entities;

create policy "dms_entities_select_anon"
  on public.dms_entities for select
  to anon, authenticated
  using (true);

create policy "dms_entities_insert_anon"
  on public.dms_entities for insert
  to anon, authenticated
  with check (true);

create policy "dms_entities_update_anon"
  on public.dms_entities for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "dms_entities_delete_anon"
  on public.dms_entities for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.dms_entities to anon, authenticated;

create table if not exists public.documents (
  id text primary key,
  entity_type text not null check (
    entity_type in ('company', 'vendor', 'employee', 'candidate')
  ),
  entity_id text not null,
  entity_name text not null,
  title text not null,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  file_size_bytes bigint not null default 0,
  storage_path text not null default '',
  notes text not null default '',
  category text not null default 'General',
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.documents
  add column if not exists category text not null default 'General';

create index if not exists documents_entity_idx
  on public.documents (entity_type, entity_id);
create index if not exists documents_uploaded_at_idx
  on public.documents (uploaded_at desc);

alter table public.documents enable row level security;

drop policy if exists "documents_select_anon" on public.documents;
drop policy if exists "documents_insert_anon" on public.documents;
drop policy if exists "documents_update_anon" on public.documents;
drop policy if exists "documents_delete_anon" on public.documents;

create policy "documents_select_anon"
  on public.documents for select
  to anon, authenticated
  using (true);

create policy "documents_insert_anon"
  on public.documents for insert
  to anon, authenticated
  with check (true);

create policy "documents_update_anon"
  on public.documents for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "documents_delete_anon"
  on public.documents for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.documents to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Users (app profiles). Credentials live in auth.users; this table is the
-- editable profile + role assignment used by the app.
-- ---------------------------------------------------------------------------

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text not null default '',
  role_id text not null references public.roles (id),
  employee_id text references public.employees (employee_id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists users_role_id_idx on public.users (role_id);
create index if not exists users_employee_id_idx on public.users (employee_id);
create index if not exists users_is_active_idx on public.users (is_active);

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
  before update on public.users
  for each row
  execute function public.set_updated_at();

alter table public.users enable row level security;

drop policy if exists "users_select_anon" on public.users;
drop policy if exists "users_insert_anon" on public.users;
drop policy if exists "users_update_anon" on public.users;
drop policy if exists "users_delete_anon" on public.users;

create policy "users_select_anon"
  on public.users for select
  to anon, authenticated
  using (true);

create policy "users_insert_anon"
  on public.users for insert
  to anon, authenticated
  with check (true);

create policy "users_update_anon"
  on public.users for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "users_delete_anon"
  on public.users for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.users to anon, authenticated;

-- Auto-create a public.users row when someone signs up in Auth.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  default_role_id text;
  preferred_name text;
begin
  select id into default_role_id
  from public.roles
  where code = 'employee' and is_active
  order by sort_order
  limit 1;

  if default_role_id is null then
    select id into default_role_id from public.roles order by sort_order limit 1;
  end if;

  preferred_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  insert into public.users (id, email, full_name, role_id)
  values (new.id, new.email, preferred_name, default_role_id)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();

-- Backfill profiles for Auth users that already exist.
insert into public.users (id, email, full_name, role_id)
select
  au.id,
  au.email,
  coalesce(
    nullif(trim(au.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(au.raw_user_meta_data ->> 'full_name'), ''),
    split_part(au.email, '@', 1)
  ),
  coalesce(
    (select id from public.roles where code = 'employee' and is_active limit 1),
    (select id from public.roles order by sort_order limit 1)
  )
from auth.users au
where au.email is not null
on conflict (id) do nothing;

-- Promote known owner account(s) when present in Auth.
update public.users u
set role_id = r.id
from public.roles r
where r.code = 'owner'
  and lower(u.email) in ('aditya.rana@sayge.in');

-- ---------------------------------------------------------------------------
-- Activity ledger — every insert / update / delete on app tables
-- ---------------------------------------------------------------------------

create table if not exists public.activity_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid references auth.users (id) on delete set null,
  actor_email text,
  schema_name text not null default 'public',
  table_name text not null,
  record_id text not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb
);

create index if not exists activity_log_occurred_at_idx
  on public.activity_log (occurred_at desc);
create index if not exists activity_log_table_idx
  on public.activity_log (table_name, occurred_at desc);
create index if not exists activity_log_actor_idx
  on public.activity_log (actor_id, occurred_at desc);
create index if not exists activity_log_record_idx
  on public.activity_log (table_name, record_id);

alter table public.activity_log enable row level security;

drop policy if exists "activity_log_select_auth" on public.activity_log;
drop policy if exists "activity_log_select_anon" on public.activity_log;

create policy "activity_log_select_anon"
  on public.activity_log for select
  to anon, authenticated
  using (true);

revoke insert, update, delete on public.activity_log from anon, authenticated;
grant select on public.activity_log to anon, authenticated;

create or replace function public.log_row_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  payload jsonb;
  rid text;
  actor uuid;
  email text;
begin
  actor := auth.uid();
  begin
    email := auth.jwt() ->> 'email';
  exception
    when others then
      email := null;
  end;

  if tg_op = 'DELETE' then
    payload := to_jsonb(old);
  else
    payload := to_jsonb(new);
  end if;

  rid := coalesce(
    payload ->> 'id',
    payload ->> 'employee_id',
    payload ->> 'code'
  );

  if rid is null or rid = '' then
    rid := left(coalesce(payload::text, tg_op), 200);
  end if;

  insert into public.activity_log (
    actor_id,
    actor_email,
    schema_name,
    table_name,
    record_id,
    action,
    old_data,
    new_data
  )
  values (
    actor,
    email,
    tg_table_schema,
    tg_table_name,
    rid,
    tg_op,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'roles',
    'clients',
    'employees',
    'dms_entities',
    'documents',
    'users'
  ]
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      t || '_activity_log',
      t
    );
    execute format(
      'create trigger %I
         after insert or update or delete on public.%I
         for each row execute function public.log_row_activity()',
      t || '_activity_log',
      t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Proposals
-- ---------------------------------------------------------------------------

create table if not exists public.proposals (
  id text primary key,
  reference_no text not null unique,
  quote_date date not null,
  expiry_date date not null,
  place_of_supply text not null default '',
  vendor_code text not null default '',
  entity_code text not null default '',
  bill_to_name text not null default '',
  bill_to_company text not null default '',
  bill_to_address text not null default '',
  bill_to_gstin text not null default '',
  ship_to_name text not null default '',
  ship_to_company text not null default '',
  ship_to_address text not null default '',
  ship_to_gstin text not null default '',
  notes text not null default '',
  subtotal numeric(14, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists proposals_quote_date_idx
  on public.proposals (quote_date desc);
create index if not exists proposals_reference_no_idx
  on public.proposals (reference_no);

drop trigger if exists proposals_set_updated_at on public.proposals;
create trigger proposals_set_updated_at
  before update on public.proposals
  for each row
  execute function public.set_updated_at();

alter table public.proposals enable row level security;

drop policy if exists "proposals_select_anon" on public.proposals;
drop policy if exists "proposals_insert_anon" on public.proposals;
drop policy if exists "proposals_update_anon" on public.proposals;
drop policy if exists "proposals_delete_anon" on public.proposals;

create policy "proposals_select_anon"
  on public.proposals for select
  to anon, authenticated
  using (true);

create policy "proposals_insert_anon"
  on public.proposals for insert
  to anon, authenticated
  with check (true);

create policy "proposals_update_anon"
  on public.proposals for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "proposals_delete_anon"
  on public.proposals for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete on public.proposals to anon, authenticated;

create table if not exists public.proposal_line_items (
  id text primary key,
  proposal_id text not null references public.proposals (id) on delete cascade,
  sort_order int not null default 0,
  description text not null,
  monthly_rate numeric(14, 2) not null default 0,
  months int not null default 0,
  days int not null default 0,
  total_rate numeric(14, 2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists proposal_line_items_proposal_idx
  on public.proposal_line_items (proposal_id, sort_order);

alter table public.proposal_line_items enable row level security;

drop policy if exists "proposal_line_items_select_anon" on public.proposal_line_items;
drop policy if exists "proposal_line_items_insert_anon" on public.proposal_line_items;
drop policy if exists "proposal_line_items_update_anon" on public.proposal_line_items;
drop policy if exists "proposal_line_items_delete_anon" on public.proposal_line_items;

create policy "proposal_line_items_select_anon"
  on public.proposal_line_items for select
  to anon, authenticated
  using (true);

create policy "proposal_line_items_insert_anon"
  on public.proposal_line_items for insert
  to anon, authenticated
  with check (true);

create policy "proposal_line_items_update_anon"
  on public.proposal_line_items for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "proposal_line_items_delete_anon"
  on public.proposal_line_items for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete
  on public.proposal_line_items to anon, authenticated;

-- Ledger triggers for proposals
do $$
begin
  drop trigger if exists proposals_activity_log on public.proposals;
  create trigger proposals_activity_log
    after insert or update or delete on public.proposals
    for each row execute function public.log_row_activity();

  drop trigger if exists proposal_line_items_activity_log
    on public.proposal_line_items;
  create trigger proposal_line_items_activity_log
    after insert or update or delete on public.proposal_line_items
    for each row execute function public.log_row_activity();
end $$;

-- ---------------------------------------------------------------------------
-- Employee Purchase Orders (PO PDF + dates)
-- ---------------------------------------------------------------------------

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

create policy "employee_purchase_orders_select_anon"
  on public.employee_purchase_orders for select
  to anon, authenticated
  using (true);

create policy "employee_purchase_orders_insert_anon"
  on public.employee_purchase_orders for insert
  to anon, authenticated
  with check (true);

create policy "employee_purchase_orders_update_anon"
  on public.employee_purchase_orders for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "employee_purchase_orders_delete_anon"
  on public.employee_purchase_orders for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete
  on public.employee_purchase_orders to anon, authenticated;

do $$
begin
  drop trigger if exists employee_purchase_orders_activity_log
    on public.employee_purchase_orders;
  create trigger employee_purchase_orders_activity_log
    after insert or update or delete on public.employee_purchase_orders
    for each row execute function public.log_row_activity();
end $$;

-- Storage bucket for PO PDFs (public read for simple download URLs)
insert into storage.buckets (id, name, public)
values ('employee-pos', 'employee-pos', true)
on conflict (id) do nothing;

drop policy if exists "employee_pos_storage_select" on storage.objects;
drop policy if exists "employee_pos_storage_insert" on storage.objects;
drop policy if exists "employee_pos_storage_update" on storage.objects;
drop policy if exists "employee_pos_storage_delete" on storage.objects;

create policy "employee_pos_storage_select"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'employee-pos');

create policy "employee_pos_storage_insert"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'employee-pos');

create policy "employee_pos_storage_update"
  on storage.objects for update
  to anon, authenticated
  using (bucket_id = 'employee-pos')
  with check (bucket_id = 'employee-pos');

create policy "employee_pos_storage_delete"
  on storage.objects for delete
  to anon, authenticated
  using (bucket_id = 'employee-pos');

-- ---------------------------------------------------------------------------
-- Tax Invoices
-- ---------------------------------------------------------------------------

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
create index if not exists invoices_po_number_idx
  on public.invoices (po_number);

drop trigger if exists invoices_set_updated_at on public.invoices;
create trigger invoices_set_updated_at
  before update on public.invoices
  for each row
  execute function public.set_updated_at();

alter table public.invoices enable row level security;

drop policy if exists "invoices_select_anon" on public.invoices;
drop policy if exists "invoices_insert_anon" on public.invoices;
drop policy if exists "invoices_update_anon" on public.invoices;
drop policy if exists "invoices_delete_anon" on public.invoices;

create policy "invoices_select_anon"
  on public.invoices for select
  to anon, authenticated
  using (true);

create policy "invoices_insert_anon"
  on public.invoices for insert
  to anon, authenticated
  with check (true);

create policy "invoices_update_anon"
  on public.invoices for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "invoices_delete_anon"
  on public.invoices for delete
  to anon, authenticated
  using (true);

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

create policy "invoice_line_items_select_anon"
  on public.invoice_line_items for select
  to anon, authenticated
  using (true);

create policy "invoice_line_items_insert_anon"
  on public.invoice_line_items for insert
  to anon, authenticated
  with check (true);

create policy "invoice_line_items_update_anon"
  on public.invoice_line_items for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "invoice_line_items_delete_anon"
  on public.invoice_line_items for delete
  to anon, authenticated
  using (true);

grant select, insert, update, delete
  on public.invoice_line_items to anon, authenticated;

do $$
begin
  drop trigger if exists invoices_activity_log on public.invoices;
  create trigger invoices_activity_log
    after insert or update or delete on public.invoices
    for each row execute function public.log_row_activity();

  drop trigger if exists invoice_line_items_activity_log
    on public.invoice_line_items;
  create trigger invoice_line_items_activity_log
    after insert or update or delete on public.invoice_line_items
    for each row execute function public.log_row_activity();
end $$;

-- ---------------------------------------------------------------------------
-- Company details (seller / bank info for invoices)
-- ---------------------------------------------------------------------------

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
  for each row
  execute function public.set_updated_at();

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
end $$;
-- Expenses — run in Supabase SQL Editor if the table is missing.

create table if not exists public.expenses (
  id text primary key,
  made_for text not null default '',
  amount numeric(14, 2) not null default 0,
  paid_from text not null default '',
  category text not null default '',
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

