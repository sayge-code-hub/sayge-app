-- Expense approval status (pending | approved | rejected).
-- Only owner/admin (app_is_staff) may change approval fields.

alter table public.expenses
  add column if not exists approval_status text not null default 'pending',
  add column if not exists approved_by uuid references auth.users (id) on delete set null,
  add column if not exists approved_at timestamptz;

update public.expenses
set approval_status = 'pending'
where approval_status is null or approval_status = '';

alter table public.expenses
  drop constraint if exists expenses_approval_status_chk;

alter table public.expenses
  add constraint expenses_approval_status_chk
  check (approval_status in ('pending', 'approved', 'rejected'));

create index if not exists expenses_approval_status_idx
  on public.expenses (approval_status);

create or replace function public.expenses_guard_approval()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
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
$$;

drop trigger if exists expenses_guard_approval on public.expenses;
create trigger expenses_guard_approval
  before insert or update on public.expenses
  for each row
  execute function public.expenses_guard_approval();

drop policy if exists "expenses_update_rbac" on public.expenses;
create policy "expenses_update_rbac"
  on public.expenses for update
  to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());
