-- Restore RLS for child line-item tables (no company_id of their own).
-- Broken by multi_tenant.sql which dropped *_rbac policies but did not recreate them.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- proposal_line_items — staff of the parent proposal's company
-- ---------------------------------------------------------------------------

alter table public.proposal_line_items enable row level security;

drop policy if exists proposal_line_items_select_tenant on public.proposal_line_items;
drop policy if exists proposal_line_items_insert_tenant on public.proposal_line_items;
drop policy if exists proposal_line_items_update_tenant on public.proposal_line_items;
drop policy if exists proposal_line_items_delete_tenant on public.proposal_line_items;
drop policy if exists "proposal_line_items_select_rbac" on public.proposal_line_items;
drop policy if exists "proposal_line_items_insert_rbac" on public.proposal_line_items;
drop policy if exists "proposal_line_items_update_rbac" on public.proposal_line_items;
drop policy if exists "proposal_line_items_delete_rbac" on public.proposal_line_items;

create policy proposal_line_items_select_tenant on public.proposal_line_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

create policy proposal_line_items_insert_tenant on public.proposal_line_items
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

create policy proposal_line_items_update_tenant on public.proposal_line_items
  for update to authenticated
  using (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  )
  with check (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

create policy proposal_line_items_delete_tenant on public.proposal_line_items
  for delete to authenticated
  using (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

grant select, insert, update, delete on public.proposal_line_items to authenticated;

-- ---------------------------------------------------------------------------
-- invoice_line_items — staff of the parent invoice's company
-- ---------------------------------------------------------------------------

alter table public.invoice_line_items enable row level security;

drop policy if exists invoice_line_items_select_tenant on public.invoice_line_items;
drop policy if exists invoice_line_items_insert_tenant on public.invoice_line_items;
drop policy if exists invoice_line_items_update_tenant on public.invoice_line_items;
drop policy if exists invoice_line_items_delete_tenant on public.invoice_line_items;
drop policy if exists "invoice_line_items_select_rbac" on public.invoice_line_items;
drop policy if exists "invoice_line_items_insert_rbac" on public.invoice_line_items;
drop policy if exists "invoice_line_items_update_rbac" on public.invoice_line_items;
drop policy if exists "invoice_line_items_delete_rbac" on public.invoice_line_items;

create policy invoice_line_items_select_tenant on public.invoice_line_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

create policy invoice_line_items_insert_tenant on public.invoice_line_items
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

create policy invoice_line_items_update_tenant on public.invoice_line_items
  for update to authenticated
  using (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  )
  with check (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

create policy invoice_line_items_delete_tenant on public.invoice_line_items
  for delete to authenticated
  using (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

grant select, insert, update, delete on public.invoice_line_items to authenticated;
