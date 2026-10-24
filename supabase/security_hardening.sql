-- ===========================================================================
-- Sayge — authoritative database security migration.
--
-- Goal: no anonymous (anon / public) access to business or personal data.
--
-- Run order: see supabase/APPLY_ORDER.md
--   1. supabase/schema.sql            (tables, triggers, buckets)
--   2. supabase/<feature>.sql         (optional feature packs you use)
--   3. supabase/security_hardening.sql  <-- THIS FILE, always run last
--
-- This file is idempotent and safe to re-run. It is the single source of
-- truth for grants and RLS policies; every policy it manages is dropped and
-- recreated so that no stale permissive policy can survive.
--
-- Why both GRANT and RLS: PostgREST authenticates as the `anon` role for
-- unauthenticated requests. RLS alone is not enough — if `anon` still holds
-- table privileges, any future permissive policy (or a table created without
-- RLS) immediately leaks data. We remove the privilege AND the policy.
--
-- Why policies are dropped wholesale: PostgreSQL combines *permissive* RLS
-- policies with OR. A leftover `employees_select_anon ... USING (true)` would
-- defeat a correct `employees_select_rbac` policy. Dropping every existing
-- policy on the managed tables before recreating removes that risk.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0. Helper functions (role lookup). SECURITY DEFINER so they can read
--    public.users without recursing through that table's own RLS.
-- ---------------------------------------------------------------------------

create or replace function public.app_role_code()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select r.code
      from public.users u
      join public.roles r on r.id = u.role_id
      where u.id = auth.uid()
        and u.is_active is true
      limit 1
    ),
    'anonymous'
  );
$$;

create or replace function public.app_is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_role_code() in ('owner', 'admin');
$$;

create or replace function public.app_employee_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select employee_id
  from public.users
  where id = auth.uid()
    and is_active is true
  limit 1;
$$;

-- Execution privileges for these are set in section 3b, after every function
-- in this file exists.

-- ---------------------------------------------------------------------------
-- 1. Strip every privilege the `anon` role holds in the public schema.
--    Done before policies so there is no window where anon can read.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    raise notice 'Role "anon" not present (local Postgres?) — skipping revokes.';
    return;
  end if;

  execute 'revoke all on all tables in schema public from anon';
  execute 'revoke all on all sequences in schema public from anon';
  execute 'revoke all on all routines in schema public from anon';

  -- Future tables created by the schema owner must not grant anon either.
  execute 'alter default privileges in schema public revoke all on tables from anon';
  execute 'alter default privileges in schema public revoke all on sequences from anon';
  execute 'alter default privileges in schema public revoke all on routines from anon';

  -- `public` (PUBLIC pseudo-role) includes anon; strip it from app tables too.
  execute 'revoke all on all tables in schema public from public';
end $$;

-- ---------------------------------------------------------------------------
-- 2. Enable RLS on every table in the public schema, then drop ALL existing
--    policies on them. Deny-by-default until section 4 recreates policies.
-- ---------------------------------------------------------------------------

do $$
declare
  rec record;
begin
  for rec in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
  loop
    execute format('alter table public.%I enable row level security', rec.relname);
  end loop;

  for rec in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on public.%I', rec.policyname, rec.tablename);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Self-service guard triggers.
--    RLS decides *which rows* a user may touch; these triggers decide *which
--    columns*, so an employee cannot escalate their own role or rewrite their
--    identity while legitimately editing contact details.
--
--    Both guards use an explicit ALLOWLIST and reject any other changed
--    column by name. A column added to the table in future is therefore
--    protected by default — the failure mode is "employee cannot edit it",
--    not "employee can edit it unnoticed".
-- ---------------------------------------------------------------------------

create or replace function public.employee_self_update_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Contact / personal-detail columns an employee may maintain themselves.
  -- Everything else (compensation, tax, payroll flags, bank, identity,
  -- employment status, client assignment) is staff-only.
  allowed constant text[] := array[
    'contact_no',
    'alternate_contact',
    'personal_email',
    'residential_address',
    'pincode',
    'nationality',
    'gender',
    'father_name',
    'mother_name',
    'photo_path',
    'updated_at'
  ];
  changed text;
begin
  -- service_role (edge functions, admin tooling) and internal jobs bypass.
  if coalesce(auth.role(), '') = 'service_role' or auth.uid() is null then
    return new;
  end if;
  if public.app_is_staff() then
    return new;
  end if;
  if old.employee_id is distinct from public.app_employee_id() then
    raise exception 'Employees may only update their own profile';
  end if;

  for changed in
    select k.key
    from jsonb_each(to_jsonb(new)) k
    where k.value is distinct from (to_jsonb(old) -> k.key)
  loop
    if not (changed = any(allowed)) then
      raise exception
        'Employees may not change %. Editable fields: %',
        changed, array_to_string(allowed, ', ');
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists employees_self_update_guard on public.employees;
create trigger employees_self_update_guard
  before update on public.employees
  for each row execute function public.employee_self_update_guard();

create or replace function public.users_self_update_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  allowed constant text[] := array['full_name', 'avatar_path', 'updated_at'];
  changed text;
begin
  if coalesce(auth.role(), '') = 'service_role' or auth.uid() is null then
    return new;
  end if;
  if public.app_is_staff() then
    return new;
  end if;
  if old.id is distinct from auth.uid() then
    raise exception 'You may only update your own profile';
  end if;

  for changed in
    select k.key
    from jsonb_each(to_jsonb(new)) k
    where k.value is distinct from (to_jsonb(old) -> k.key)
  loop
    if not (changed = any(allowed)) then
      raise exception
        'You may not change %. Editable fields: %',
        changed, array_to_string(allowed, ', ');
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists users_self_update_guard on public.users;
create trigger users_self_update_guard
  before update on public.users
  for each row execute function public.users_self_update_guard();

-- Expense approval fields are staff-only, even on rows the creator owns.
do $$
begin
  if to_regclass('public.expenses') is null then
    return;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'expenses'
      and column_name = 'approval_status'
  ) then
    return;
  end if;

  execute $fn$
    create or replace function public.expenses_guard_approval()
    returns trigger
    language plpgsql
    security definer
    set search_path = public
    as $body$
    begin
      if coalesce(auth.role(), '') = 'service_role' then
        return new;
      end if;

      if tg_op = 'INSERT' then
        new.approval_status := 'pending';
        new.approved_by := null;
        new.approved_at := null;
        return new;
      end if;

      if new.approval_status is distinct from old.approval_status
         or new.approved_by is distinct from old.approved_by
         or new.approved_at is distinct from old.approved_at then
        if not public.app_is_staff() then
          raise exception 'Only owner or admin can change expense approval';
        end if;
        if new.approval_status = 'pending' then
          new.approved_by := null;
          new.approved_at := null;
        elsif new.approval_status in ('approved', 'rejected') then
          new.approved_by := coalesce(new.approved_by, auth.uid());
          new.approved_at := coalesce(new.approved_at, now());
        end if;
      end if;

      return new;
    end;
    $body$;
  $fn$;

  drop trigger if exists expenses_guard_approval on public.expenses;
  create trigger expenses_guard_approval
    before insert or update on public.expenses
    for each row execute function public.expenses_guard_approval();
end $$;

-- ---------------------------------------------------------------------------
-- 3b. Function execution privileges.
--
--     PostgreSQL grants EXECUTE on every new function to PUBLIC by default,
--     and `anon` inherits it. Revoking from `anon` alone leaves that inherited
--     path open, so we revoke from PUBLIC first and then grant back only what
--     the app actually calls.
--
--     Extension-owned functions (pgcrypto et al.) are skipped: their ACLs
--     belong to the extension and revoking breaks dependent features.
--     Trigger functions need no grant at all — the trigger runs them.
-- ---------------------------------------------------------------------------

do $$
declare
  rec record;
  has_anon boolean := exists (select 1 from pg_roles where rolname = 'anon');
begin
  for rec in
    select format(
             '%I.%I(%s)',
             n.nspname, p.proname,
             pg_get_function_identity_arguments(p.oid)
           ) as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_proc'::regclass
          and d.objid = p.oid
          and d.deptype = 'e'
      )
  loop
    execute format('revoke all on function %s from public', rec.sig);
    if has_anon then
      execute format('revoke all on function %s from anon', rec.sig);
    end if;
  end loop;
end $$;

alter default privileges in schema public revoke execute on functions from public;

-- Only the role-lookup helpers are callable, and only by signed-in callers.
grant execute on function public.app_role_code() to authenticated, service_role;
grant execute on function public.app_is_staff() to authenticated, service_role;
grant execute on function public.app_employee_id() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Policies + grants.
--    Every policy below targets `authenticated` only. `anon` is never named,
--    and holds no table privileges after section 1, so unauthenticated
--    PostgREST requests are rejected before RLS is even consulted.
-- ---------------------------------------------------------------------------

-- 4a. Staff-only business data (owner/admin manage; employees see nothing).
do $$
declare
  t text;
begin
  foreach t in array array[
    'clients',
    'dms_entities',
    'company_details',
    'invoices',
    'invoice_line_items',
    'proposals',
    'proposal_line_items',
    'payroll_runs',
    'pos_brands',
    'pos_products',
    'pos_product_images',
    'pos_product_attributes',
    'pos_product_variants',
    'pos_purchases',
    'pos_purchase_items',
    'pos_price_rules'
  ]
  loop
    -- Optional feature tables may not exist yet in a given project.
    if to_regclass('public.' || t) is null then
      continue;
    end if;

    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.app_is_staff())',
      t || '_select_rbac', t
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.app_is_staff())',
      t || '_insert_rbac', t
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.app_is_staff()) with check (public.app_is_staff())',
      t || '_update_rbac', t
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.app_is_staff())',
      t || '_delete_rbac', t
    );
    execute format(
      'grant select, insert, update, delete on public.%I to authenticated', t
    );
  end loop;
end $$;

-- Expense categories: any signed-in user can read (expense form dropdown);
-- only staff can add / rename / delete.
do $$
begin
  if to_regclass('public.expense_categories') is null then
    return;
  end if;

  alter table public.expense_categories enable row level security;
  drop policy if exists "expense_categories_select_rbac" on public.expense_categories;
  drop policy if exists "expense_categories_insert_rbac" on public.expense_categories;
  drop policy if exists "expense_categories_update_rbac" on public.expense_categories;
  drop policy if exists "expense_categories_delete_rbac" on public.expense_categories;

  create policy "expense_categories_select_rbac"
    on public.expense_categories for select
    to authenticated
    using (true);

  create policy "expense_categories_insert_rbac"
    on public.expense_categories for insert
    to authenticated
    with check (public.app_is_staff());

  create policy "expense_categories_update_rbac"
    on public.expense_categories for update
    to authenticated
    using (public.app_is_staff())
    with check (public.app_is_staff());

  create policy "expense_categories_delete_rbac"
    on public.expense_categories for delete
    to authenticated
    using (public.app_is_staff());

  grant select, insert, update, delete on public.expense_categories
    to authenticated;
end $$;

-- 4b. Roles catalog: readable by any signed-in user (the app renders role
--     labels and the invite picker); writable by staff only. Never anon.
create policy "roles_select_rbac"
  on public.roles for select
  to authenticated
  using (true);

create policy "roles_insert_rbac"
  on public.roles for insert
  to authenticated
  with check (public.app_is_staff());

create policy "roles_update_rbac"
  on public.roles for update
  to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());

create policy "roles_delete_rbac"
  on public.roles for delete
  to authenticated
  using (public.app_is_staff());

grant select, insert, update, delete on public.roles to authenticated;

-- 4c. Users: own profile or staff. Column-level safety via the guard trigger.
create policy "users_select_rbac"
  on public.users for select
  to authenticated
  using (public.app_is_staff() or id = auth.uid());

create policy "users_insert_rbac"
  on public.users for insert
  to authenticated
  with check (public.app_is_staff());

create policy "users_update_rbac"
  on public.users for update
  to authenticated
  using (public.app_is_staff() or id = auth.uid())
  with check (public.app_is_staff() or id = auth.uid());

create policy "users_delete_rbac"
  on public.users for delete
  to authenticated
  using (public.app_is_staff());

grant select, insert, update, delete on public.users to authenticated;

-- 4d. Employees.
--     READ is row-level, not column-level: an employee who is linked to an
--     employee record reads that row IN FULL, including their own CTC, bank
--     details and PAN. That is deliberate — it is their own data, and the
--     payslip feature already shows it. They can read no other employee's row.
--     WRITE is narrowed to the contact-field allowlist by the guard trigger in
--     section 3. If contact-only *visibility* is ever required, it needs a
--     column-restricted view plus app query changes; RLS cannot express it.
create policy "employees_select_rbac"
  on public.employees for select
  to authenticated
  using (public.app_is_staff() or employee_id = public.app_employee_id());

create policy "employees_insert_rbac"
  on public.employees for insert
  to authenticated
  with check (public.app_is_staff());

create policy "employees_update_rbac"
  on public.employees for update
  to authenticated
  using (public.app_is_staff() or employee_id = public.app_employee_id())
  with check (public.app_is_staff() or employee_id = public.app_employee_id());

create policy "employees_delete_rbac"
  on public.employees for delete
  to authenticated
  using (public.app_is_staff());

grant select, insert, update, delete on public.employees to authenticated;

-- 4e. Documents: staff manage all; employees manage only documents attached to
--     their own employee record.
do $$
begin
  if to_regclass('public.documents') is null then
    return;
  end if;

  create policy "documents_select_rbac"
    on public.documents for select
    to authenticated
    using (
      public.app_is_staff()
      or (entity_type = 'employee' and entity_id = public.app_employee_id())
    );

  create policy "documents_insert_rbac"
    on public.documents for insert
    to authenticated
    with check (
      public.app_is_staff()
      or (entity_type = 'employee' and entity_id = public.app_employee_id())
    );

  create policy "documents_update_rbac"
    on public.documents for update
    to authenticated
    using (
      public.app_is_staff()
      or (entity_type = 'employee' and entity_id = public.app_employee_id())
    )
    with check (
      public.app_is_staff()
      or (entity_type = 'employee' and entity_id = public.app_employee_id())
    );

  create policy "documents_delete_rbac"
    on public.documents for delete
    to authenticated
    using (
      public.app_is_staff()
      or (entity_type = 'employee' and entity_id = public.app_employee_id())
    );

  grant select, insert, update, delete on public.documents to authenticated;
end $$;

-- 4f. Employee purchase orders: staff write; employees read their own.
do $$
begin
  if to_regclass('public.employee_purchase_orders') is null then
    return;
  end if;

  create policy "employee_purchase_orders_select_rbac"
    on public.employee_purchase_orders for select
    to authenticated
    using (public.app_is_staff() or employee_id = public.app_employee_id());

  create policy "employee_purchase_orders_insert_rbac"
    on public.employee_purchase_orders for insert
    to authenticated
    with check (public.app_is_staff());

  create policy "employee_purchase_orders_update_rbac"
    on public.employee_purchase_orders for update
    to authenticated
    using (public.app_is_staff())
    with check (public.app_is_staff());

  create policy "employee_purchase_orders_delete_rbac"
    on public.employee_purchase_orders for delete
    to authenticated
    using (public.app_is_staff());

  grant select, insert, update, delete
    on public.employee_purchase_orders to authenticated;
end $$;

-- 4g. Expenses: staff see everything; a submitter sees and edits only their own
--     rows, and only while the claim is still pending.
do $$
declare
  has_created_by boolean;
  has_approval boolean;
  own_row text;
  own_editable text;
begin
  if to_regclass('public.expenses') is null then
    return;
  end if;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'expenses'
      and column_name = 'created_by'
  ) into has_created_by;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'expenses'
      and column_name = 'approval_status'
  ) into has_approval;

  if not has_created_by then
    -- Older projects without ownership tracking: staff-only, fail closed.
    own_row := 'false';
    own_editable := 'false';
    raise warning using message =
      'expenses.created_by missing: expenses are now STAFF-ONLY (employees cannot see or file their own claims). Apply fix_rbac_policies.sql, then re-run this file.';
  else
    own_row := 'created_by = auth.uid()';
    own_editable := case
      when has_approval then '(created_by = auth.uid() and approval_status = ''pending'')'
      else 'created_by = auth.uid()'
    end;
  end if;

  execute format(
    'create policy "expenses_select_rbac" on public.expenses for select to authenticated using (public.app_is_staff() or %s)',
    own_row
  );
  execute format(
    'create policy "expenses_insert_rbac" on public.expenses for insert to authenticated with check (public.app_is_staff() or %s)',
    own_row
  );
  execute format(
    'create policy "expenses_update_rbac" on public.expenses for update to authenticated using (public.app_is_staff() or %1$s) with check (public.app_is_staff() or %1$s)',
    own_editable
  );
  execute format(
    'create policy "expenses_delete_rbac" on public.expenses for delete to authenticated using (public.app_is_staff() or %s)',
    own_editable
  );

  execute 'grant select, insert, update, delete on public.expenses to authenticated';
end $$;

-- 4h. Payslips: staff manage; an employee may read only their own slips.
do $$
begin
  if to_regclass('public.payslip_records') is null then
    return;
  end if;

  create policy "payslip_records_select_rbac"
    on public.payslip_records for select
    to authenticated
    using (public.app_is_staff() or employee_id = public.app_employee_id());

  create policy "payslip_records_write_rbac"
    on public.payslip_records for all
    to authenticated
    using (public.app_is_staff())
    with check (public.app_is_staff());

  grant select, insert, update, delete on public.payslip_records to authenticated;
end $$;

-- 4i. Activity ledger: staff read-only. Rows are written by the SECURITY
--     DEFINER trigger public.log_row_activity(), which bypasses RLS, so no
--     client needs insert/update/delete here.
create policy "activity_log_select_rbac"
  on public.activity_log for select
  to authenticated
  using (public.app_is_staff());

revoke all on public.activity_log from authenticated;
grant select on public.activity_log to authenticated;

-- 4j. POS commerce audit: staff read + append, never mutate.
do $$
begin
  if to_regclass('public.pos_commerce_audit') is null then
    return;
  end if;

  create policy "pos_commerce_audit_select_rbac"
    on public.pos_commerce_audit for select
    to authenticated
    using (public.app_is_staff());

  create policy "pos_commerce_audit_insert_rbac"
    on public.pos_commerce_audit for insert
    to authenticated
    with check (public.app_is_staff());

  revoke all on public.pos_commerce_audit from authenticated;
  grant select, insert on public.pos_commerce_audit to authenticated;
end $$;

-- 4k. Sequences / identity columns still need usage for authenticated inserts.
grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Storage.
--
--    Public buckets  : brand-logos, pos-product-images, user-avatars,
--                      employee-avatars  — rendered directly by the app via
--                      public URLs; they must only ever hold branding and
--                      profile imagery.
--    Private buckets : documents, employee-pos — contractual / HR / financial
--                      files. The app already fetches these through
--                      short-lived signed URLs, which require the caller to
--                      pass the SELECT policy below.
-- ---------------------------------------------------------------------------

update storage.buckets set public = false where id in ('documents', 'employee-pos');
update storage.buckets set public = true
  where id in ('brand-logos', 'pos-product-images', 'user-avatars', 'employee-avatars');

-- Drop every existing storage.objects policy so no anon-era rule survives.
do $$
declare
  rec record;
begin
  for rec in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
  loop
    begin
      execute format('drop policy if exists %I on storage.objects', rec.policyname);
    exception when insufficient_privilege then
      raise notice 'Could not drop storage policy % (insufficient privilege)', rec.policyname;
    end;
  end loop;
end $$;

-- Branding assets: intentionally world-readable, staff-writable.
create policy "brand_logos_storage_select"
  on storage.objects for select to public
  using (bucket_id = 'brand-logos');
create policy "brand_logos_storage_write"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'brand-logos' and public.app_is_staff());
create policy "brand_logos_storage_update"
  on storage.objects for update to authenticated
  using (bucket_id = 'brand-logos' and public.app_is_staff())
  with check (bucket_id = 'brand-logos' and public.app_is_staff());
create policy "brand_logos_storage_delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'brand-logos' and public.app_is_staff());

-- Product catalogue imagery: public read, staff write.
create policy "pos_product_images_storage_select"
  on storage.objects for select to public
  using (bucket_id = 'pos-product-images');
create policy "pos_product_images_storage_insert"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'pos-product-images' and public.app_is_staff());
create policy "pos_product_images_storage_update"
  on storage.objects for update to authenticated
  using (bucket_id = 'pos-product-images' and public.app_is_staff())
  with check (bucket_id = 'pos-product-images' and public.app_is_staff());
create policy "pos_product_images_storage_delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'pos-product-images' and public.app_is_staff());

-- User avatars: public read (profile pictures); each user owns their folder.
create policy "user_avatars_storage_select"
  on storage.objects for select to public
  using (bucket_id = 'user-avatars');
create policy "user_avatars_storage_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'user-avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.app_is_staff())
  );
create policy "user_avatars_storage_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'user-avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.app_is_staff())
  )
  with check (
    bucket_id = 'user-avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.app_is_staff())
  );
create policy "user_avatars_storage_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'user-avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.app_is_staff())
  );

-- Employee avatars: public read (shown in staff directory), staff write.
create policy "employee_avatars_storage_select"
  on storage.objects for select to public
  using (bucket_id = 'employee-avatars');
create policy "employee_avatars_storage_insert"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'employee-avatars' and public.app_is_staff());
create policy "employee_avatars_storage_update"
  on storage.objects for update to authenticated
  using (bucket_id = 'employee-avatars' and public.app_is_staff())
  with check (bucket_id = 'employee-avatars' and public.app_is_staff());
create policy "employee_avatars_storage_delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'employee-avatars' and public.app_is_staff());

-- DMS binaries: private.
--   read   : staff, or the employee the document is attached to, or the
--            submitter of the expense a receipt belongs to
--   write  : staff anywhere; an employee only inside their own folder
--            `documents/employee/<their employee_id>/...` (the path the app
--            builds), or an `expenses/<id>/...` receipt for their own claim
do $$
declare
  own_receipt_read text := '';
  own_receipt_write text := '';
begin
  if to_regclass('public.documents') is null then
    return;
  end if;

  -- Expense receipt sharing only applies once the ownership columns exist.
  if to_regclass('public.expenses') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'expenses'
         and column_name = 'receipt_path'
     )
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'expenses'
         and column_name = 'created_by'
     )
  then
    own_receipt_read := $clause$
      or exists (
        select 1 from public.expenses e
        where e.receipt_path = storage.objects.name
          and e.created_by = auth.uid()
      )$clause$;
    own_receipt_write := $clause$
      or (
        (storage.foldername(name))[1] = 'expenses'
        and exists (
          select 1 from public.expenses e
          where e.id = (storage.foldername(name))[2]
            and e.created_by = auth.uid()
        )
      )$clause$;
  elsif to_regclass('public.expenses') is not null then
    raise warning using message =
      'expenses.receipt_path and/or expenses.created_by missing: expense receipts in the documents bucket are now STAFF-ONLY. Apply ops_completeness_pack.sql and fix_rbac_policies.sql, then re-run this file.';
  end if;

  execute format($pol$
    create policy "documents_storage_select"
      on storage.objects for select to authenticated
      using (
        bucket_id = 'documents'
        and (
          public.app_is_staff()
          or exists (
            select 1 from public.documents d
            where d.storage_path = storage.objects.name
              and d.entity_type = 'employee'
              and d.entity_id = public.app_employee_id()
          )
          %s
        )
      )$pol$, own_receipt_read);

  execute format($pol$
    create policy "documents_storage_insert"
      on storage.objects for insert to authenticated
      with check (
        bucket_id = 'documents'
        and (
          public.app_is_staff()
          or (
            public.app_employee_id() is not null
            and (storage.foldername(name))[1] = 'documents'
            and (storage.foldername(name))[2] = 'employee'
            and (storage.foldername(name))[3] = public.app_employee_id()
          )
          %s
        )
      )$pol$, own_receipt_write);

  create policy "documents_storage_update"
    on storage.objects for update to authenticated
    using (bucket_id = 'documents' and public.app_is_staff())
    with check (bucket_id = 'documents' and public.app_is_staff());

  create policy "documents_storage_delete"
    on storage.objects for delete to authenticated
    using (
      bucket_id = 'documents'
      and (
        public.app_is_staff()
        or (
          public.app_employee_id() is not null
          and (storage.foldername(name))[1] = 'documents'
          and (storage.foldername(name))[2] = 'employee'
          and (storage.foldername(name))[3] = public.app_employee_id()
        )
      )
    );
end $$;

-- Purchase-order PDFs: private. Staff write; employees read only their own.
do $$
begin
  if to_regclass('public.employee_purchase_orders') is null then
    return;
  end if;

  create policy "employee_pos_storage_select"
    on storage.objects for select to authenticated
    using (
      bucket_id = 'employee-pos'
      and (
        public.app_is_staff()
        or exists (
          select 1 from public.employee_purchase_orders po
          where po.storage_path = storage.objects.name
            and po.employee_id = public.app_employee_id()
        )
      )
    );
  create policy "employee_pos_storage_insert"
    on storage.objects for insert to authenticated
    with check (bucket_id = 'employee-pos' and public.app_is_staff());
  create policy "employee_pos_storage_update"
    on storage.objects for update to authenticated
    using (bucket_id = 'employee-pos' and public.app_is_staff())
    with check (bucket_id = 'employee-pos' and public.app_is_staff());
  create policy "employee_pos_storage_delete"
    on storage.objects for delete to authenticated
    using (bucket_id = 'employee-pos' and public.app_is_staff());
end $$;

-- ---------------------------------------------------------------------------
-- 5b. Cafe POS helpers (when cafe_pos.sql / cafes table was applied).
--     Nested CREATE FUNCTION must use $fn$ / $body$ — plain $$ conflicts with
--     the outer DO $$ delimiter.
-- ---------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.cafes') is null then
    return;
  end if;

  execute $fn$
    create or replace function public.app_cafe_id()
    returns text
    language sql
    stable
    security definer
    set search_path = public
    as $body$
      select cafe_id
      from public.users
      where id = auth.uid()
        and is_active is true
      limit 1;
    $body$;
  $fn$;

  execute $fn$
    create or replace function public.app_is_cafe_role()
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as $body$
      select public.app_role_code() in ('cafe_admin', 'cashier', 'kitchen');
    $body$;
  $fn$;

  execute $fn$
    create or replace function public.app_can_access_cafe(p_cafe_id text)
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as $body$
      select public.app_is_staff()
        or (
          public.app_is_cafe_role()
          and public.app_cafe_id() is not null
          and public.app_cafe_id() = p_cafe_id
        );
    $body$;
  $fn$;

  execute $fn$
    create or replace function public.app_can_manage_cafe_menu(p_cafe_id text)
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as $body$
      select public.app_is_staff()
        or (
          public.app_role_code() = 'cafe_admin'
          and public.app_cafe_id() = p_cafe_id
        );
    $body$;
  $fn$;

  execute $fn$
    create or replace function public.app_can_run_cafe_terminal(p_cafe_id text)
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as $body$
      select public.app_is_staff()
        or (
          public.app_role_code() in ('cafe_admin', 'cashier')
          and public.app_cafe_id() = p_cafe_id
        );
    $body$;
  $fn$;

  execute $fn$
    create or replace function public.app_can_run_cafe_kitchen(p_cafe_id text)
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as $body$
      select public.app_is_staff()
        or (
          public.app_role_code() in ('cafe_admin', 'kitchen')
          and public.app_cafe_id() = p_cafe_id
        );
    $body$;
  $fn$;

  grant execute on function public.app_cafe_id() to authenticated, service_role;
  grant execute on function public.app_is_cafe_role() to authenticated, service_role;
  grant execute on function public.app_can_access_cafe(text) to authenticated, service_role;
  grant execute on function public.app_can_manage_cafe_menu(text) to authenticated, service_role;
  grant execute on function public.app_can_run_cafe_terminal(text) to authenticated, service_role;
  grant execute on function public.app_can_run_cafe_kitchen(text) to authenticated, service_role;

  drop policy if exists clients_select_cafe_scoped on public.clients;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Fail loudly if anything was missed.
-- ---------------------------------------------------------------------------

do $$
declare
  leaked text;
begin
  select string_agg(distinct table_name, ', ')
  into leaked
  from information_schema.role_table_grants
  where grantee in ('anon', 'PUBLIC')
    and table_schema = 'public';

  if leaked is not null then
    raise exception 'anon still holds privileges on: %', leaked;
  end if;

  select string_agg(distinct p.proname, ', ')
  into leaked
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  where n.nspname = 'public'
    and acl.privilege_type = 'EXECUTE'
    and (acl.grantee = 0 or pg_get_userbyid(acl.grantee) = 'anon')
    and not exists (
      select 1 from pg_depend d
      where d.classid = 'pg_proc'::regclass
        and d.objid = p.oid
        and d.deptype = 'e'
    );

  if leaked is not null then
    raise exception 'PUBLIC/anon can still execute: %', leaked;
  end if;

  select string_agg(distinct tablename || '.' || policyname, ', ')
  into leaked
  from pg_policies
  where schemaname = 'public'
    and ('anon' = any(roles) or 'public' = any(roles));

  if leaked is not null then
    raise exception 'Anonymous-facing policies still present: %', leaked;
  end if;

  select string_agg(c.relname, ', ')
  into leaked
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

  if leaked is not null then
    raise exception 'RLS disabled on: %', leaked;
  end if;

  raise notice 'Security hardening applied: anon has no privileges or policies in schema public.';
end $$;
