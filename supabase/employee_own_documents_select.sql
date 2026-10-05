-- Allow linked employees to read their own DMS documents and purchase orders.
-- Staff retain full access; writes remain staff-only.

drop policy if exists "documents_select_rbac" on public.documents;
create policy "documents_select_rbac"
  on public.documents for select
  to authenticated
  using (
    public.app_is_staff()
    or (
      entity_type = 'employee'
      and entity_id = public.app_employee_id()
    )
  );

drop policy if exists "employee_purchase_orders_select_rbac" on public.employee_purchase_orders;
create policy "employee_purchase_orders_select_rbac"
  on public.employee_purchase_orders for select
  to authenticated
  using (
    public.app_is_staff()
    or employee_id = public.app_employee_id()
  );
