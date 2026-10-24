-- Additive production-gap fixes. Safe on an already-migrated project.
-- Paste into the Supabase SQL editor (after security_hardening.sql).
--
-- Also ensure these have been applied when using the matching app features:
--   expense_categories.sql
--   invoices_payment_status_sent.sql
--   proposals_status_lifecycle.sql
--
-- Do NOT re-run ops_completeness_pack.sql or fix_rbac_policies.sql after
-- hardening without re-applying security_hardening.sql last.

alter table public.employees
  add column if not exists date_of_birth date;

alter table public.dms_entities
  add column if not exists subtitle text not null default '';

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

grant execute on function public.app_role_code() to authenticated, service_role;
grant execute on function public.app_is_staff() to authenticated, service_role;
grant execute on function public.app_employee_id() to authenticated, service_role;

-- Employees need to read category names when filing expenses; writes stay staff-only.
do $$
begin
  if to_regclass('public.expense_categories') is null then
    return;
  end if;

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

  grant select, insert, update, delete on public.expense_categories to authenticated;
end $$;
