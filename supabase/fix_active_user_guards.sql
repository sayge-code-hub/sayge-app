-- Require users.is_active for role helpers so exited / revoked users
-- lose PostgREST access even with a leftover JWT.
-- Re-run after security_hardening.sql if that file was applied earlier.
-- Idempotent.

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
