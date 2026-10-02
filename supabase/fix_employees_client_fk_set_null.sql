-- Allow deleting clients without blocking on employee references.
-- employees.client_id becomes nullable and clears (SET NULL) when a client is deleted.
--
-- Also removes stub clients `bottleworks` and `mahindra-finance` after re-pointing
-- any employees on `mahindra-finance` to the Ketan Jain contact row.
--
-- Run in Supabase SQL Editor.

-- 1) Prefer keeping employees linked to a real Mahindra contact row.
update public.employees
set client_id = 'mahindra-finance-ketan-jain'
where client_id = 'mahindra-finance'
  and exists (
    select 1
    from public.clients
    where id = 'mahindra-finance-ketan-jain'
  );

-- 2) Switch FK: restrict → set null (requires nullable column).
alter table public.employees
  alter column client_id drop not null;

alter table public.employees
  drop constraint if exists employees_client_id_fkey;

alter table public.employees
  add constraint employees_client_id_fkey
  foreign key (client_id)
  references public.clients (id)
  on delete set null;

-- 3) Delete the selected stub clients.
delete from public.clients
where id in ('bottleworks', 'mahindra-finance');
