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
  name text not null unique,
  created_at timestamptz not null default now()
);

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
  bank_account text not null default '',
  ifsc text not null default '',
  pan text not null,
  uan text not null default '',
  is_active boolean not null default true,
  location text not null,
  grade text not null,
  client_id text not null references public.clients (id) on delete restrict,
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
    if exists (select 1 from public.employees where client_id is null) then
      raise exception
        'employees.client_id backfill failed: some rows have no matching client';
    end if;

    alter table public.employees
      alter column client_id set not null;

    if not exists (
      select 1
      from pg_constraint
      where conname = 'employees_client_id_fkey'
    ) then
      alter table public.employees
        add constraint employees_client_id_fkey
        foreign key (client_id)
        references public.clients (id)
        on delete restrict;
    end if;
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
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

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

create policy "activity_log_select_auth"
  on public.activity_log for select
  to authenticated
  using (true);

revoke insert, update, delete on public.activity_log from anon, authenticated;
grant select on public.activity_log to authenticated;

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
