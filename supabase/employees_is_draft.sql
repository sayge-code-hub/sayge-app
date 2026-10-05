-- Allow incomplete employee records that can still be linked on invite.
alter table public.employees
  add column if not exists is_draft boolean not null default false;

create index if not exists employees_is_draft_idx
  on public.employees (is_draft);
