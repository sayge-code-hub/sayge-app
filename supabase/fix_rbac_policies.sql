-- Role-based access: staff (owner/admin) vs employee.
-- Run in Supabase SQL Editor (or via SUPABASE_DB_URL / psql).

-- ---------------------------------------------------------------------------
-- Helpers
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
  select employee_id from public.users where id = auth.uid() limit 1;
$$;

grant execute on function public.app_role_code() to anon, authenticated;
grant execute on function public.app_is_staff() to anon, authenticated;
grant execute on function public.app_employee_id() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Expenses: ownership column
-- ---------------------------------------------------------------------------
alter table public.expenses
  add column if not exists created_by uuid references auth.users (id) on delete set null;

create index if not exists expenses_created_by_idx on public.expenses (created_by);

drop policy if exists "expenses_select_anon" on public.expenses;
drop policy if exists "expenses_insert_anon" on public.expenses;
drop policy if exists "expenses_update_anon" on public.expenses;
drop policy if exists "expenses_delete_anon" on public.expenses;
drop policy if exists "expenses_select_rbac" on public.expenses;
drop policy if exists "expenses_insert_rbac" on public.expenses;
drop policy if exists "expenses_update_rbac" on public.expenses;
drop policy if exists "expenses_delete_rbac" on public.expenses;

create policy "expenses_select_rbac"
  on public.expenses for select
  to authenticated
  using (public.app_is_staff() or created_by = auth.uid());

create policy "expenses_insert_rbac"
  on public.expenses for insert
  to authenticated
  with check (
    public.app_is_staff()
    or created_by = auth.uid()
  );

create policy "expenses_update_rbac"
  on public.expenses for update
  to authenticated
  using (public.app_is_staff() or created_by = auth.uid())
  with check (public.app_is_staff() or created_by = auth.uid());

create policy "expenses_delete_rbac"
  on public.expenses for delete
  to authenticated
  using (public.app_is_staff() or created_by = auth.uid());

-- ---------------------------------------------------------------------------
-- Employees: self-read for employees; staff full access
-- ---------------------------------------------------------------------------
drop policy if exists "employees_select_anon" on public.employees;
drop policy if exists "employees_insert_anon" on public.employees;
drop policy if exists "employees_update_anon" on public.employees;
drop policy if exists "employees_delete_anon" on public.employees;
drop policy if exists "employees_select_rbac" on public.employees;
drop policy if exists "employees_insert_rbac" on public.employees;
drop policy if exists "employees_update_rbac" on public.employees;
drop policy if exists "employees_delete_rbac" on public.employees;

create policy "employees_select_rbac"
  on public.employees for select
  to authenticated
  using (
    public.app_is_staff()
    or employee_id = public.app_employee_id()
  );

create policy "employees_insert_rbac"
  on public.employees for insert
  to authenticated
  with check (public.app_is_staff());

create policy "employees_update_rbac"
  on public.employees for update
  to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());

create policy "employees_delete_rbac"
  on public.employees for delete
  to authenticated
  using (public.app_is_staff());

-- ---------------------------------------------------------------------------
-- Staff-only modules (proposals, invoices, clients, dms, settings tables)
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'clients',
    'dms_entities',
    'documents',
    'company_details',
    'activity_log',
    'invoices',
    'proposals',
    'employee_purchase_orders'
  ]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;

    execute format('drop policy if exists %I on public.%I', t || '_select_anon', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_anon', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_anon', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_anon', t);
    execute format('drop policy if exists %I on public.%I', t || '_select_rbac', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_rbac', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_rbac', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_rbac', t);

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
  end loop;
end $$;

-- Users: everyone can read own profile; staff can read all.
drop policy if exists "users_select_anon" on public.users;
drop policy if exists "users_select_rbac" on public.users;
create policy "users_select_rbac"
  on public.users for select
  to authenticated
  using (public.app_is_staff() or id = auth.uid());

-- Roles remain readable (needed for invite / labels).
-- Keep existing roles select for authenticated if present.
