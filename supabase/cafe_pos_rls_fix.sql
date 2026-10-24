-- Restore Cafe POS RLS after security_hardening.sql wiped policies.
-- Safe to re-run. Does not touch data.
-- Run this NOW if POS shows "No cafes yet" but seed already succeeded.

grant select, insert, update, delete on table public.cafes to authenticated;
grant select, insert, update, delete on table public.cafe_categories to authenticated;
grant select, insert, update, delete on table public.cafe_menu_items to authenticated;
grant select, insert, update, delete on table public.cafe_orders to authenticated;
grant select, insert, update, delete on table public.cafe_order_items to authenticated;
grant select, insert, update, delete on table public.cafe_payments to authenticated;

-- Cafes
drop policy if exists cafes_select on public.cafes;
drop policy if exists cafes_insert on public.cafes;
drop policy if exists cafes_update on public.cafes;
drop policy if exists cafes_delete on public.cafes;

create policy cafes_select on public.cafes
  for select to authenticated
  using (public.app_can_access_cafe(id));

create policy cafes_insert on public.cafes
  for insert to authenticated
  with check (public.app_is_staff());

create policy cafes_update on public.cafes
  for update to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());

create policy cafes_delete on public.cafes
  for delete to authenticated
  using (public.app_is_staff());

-- Categories
drop policy if exists cafe_categories_select on public.cafe_categories;
drop policy if exists cafe_categories_insert on public.cafe_categories;
drop policy if exists cafe_categories_update on public.cafe_categories;
drop policy if exists cafe_categories_delete on public.cafe_categories;

create policy cafe_categories_select on public.cafe_categories
  for select to authenticated
  using (public.app_can_access_cafe(cafe_id));

create policy cafe_categories_insert on public.cafe_categories
  for insert to authenticated
  with check (public.app_can_manage_cafe_menu(cafe_id));

create policy cafe_categories_update on public.cafe_categories
  for update to authenticated
  using (public.app_can_manage_cafe_menu(cafe_id))
  with check (public.app_can_manage_cafe_menu(cafe_id));

create policy cafe_categories_delete on public.cafe_categories
  for delete to authenticated
  using (public.app_can_manage_cafe_menu(cafe_id));

-- Menu items
drop policy if exists cafe_menu_items_select on public.cafe_menu_items;
drop policy if exists cafe_menu_items_insert on public.cafe_menu_items;
drop policy if exists cafe_menu_items_update on public.cafe_menu_items;
drop policy if exists cafe_menu_items_delete on public.cafe_menu_items;

create policy cafe_menu_items_select on public.cafe_menu_items
  for select to authenticated
  using (public.app_can_access_cafe(cafe_id));

create policy cafe_menu_items_insert on public.cafe_menu_items
  for insert to authenticated
  with check (public.app_can_manage_cafe_menu(cafe_id));

create policy cafe_menu_items_update on public.cafe_menu_items
  for update to authenticated
  using (public.app_can_manage_cafe_menu(cafe_id))
  with check (public.app_can_manage_cafe_menu(cafe_id));

create policy cafe_menu_items_delete on public.cafe_menu_items
  for delete to authenticated
  using (public.app_can_manage_cafe_menu(cafe_id));

-- Orders
drop policy if exists cafe_orders_select on public.cafe_orders;
drop policy if exists cafe_orders_insert on public.cafe_orders;
drop policy if exists cafe_orders_update on public.cafe_orders;
drop policy if exists cafe_orders_delete on public.cafe_orders;

create policy cafe_orders_select on public.cafe_orders
  for select to authenticated
  using (public.app_can_access_cafe(cafe_id));

create policy cafe_orders_insert on public.cafe_orders
  for insert to authenticated
  with check (public.app_can_run_cafe_terminal(cafe_id));

create policy cafe_orders_update on public.cafe_orders
  for update to authenticated
  using (
    public.app_can_run_cafe_terminal(cafe_id)
    or public.app_can_run_cafe_kitchen(cafe_id)
  )
  with check (
    public.app_can_run_cafe_terminal(cafe_id)
    or public.app_can_run_cafe_kitchen(cafe_id)
  );

create policy cafe_orders_delete on public.cafe_orders
  for delete to authenticated
  using (public.app_is_staff());

-- Order items
drop policy if exists cafe_order_items_select on public.cafe_order_items;
drop policy if exists cafe_order_items_insert on public.cafe_order_items;
drop policy if exists cafe_order_items_update on public.cafe_order_items;
drop policy if exists cafe_order_items_delete on public.cafe_order_items;

create policy cafe_order_items_select on public.cafe_order_items
  for select to authenticated
  using (
    exists (
      select 1 from public.cafe_orders o
      where o.id = order_id
        and public.app_can_access_cafe(o.cafe_id)
    )
  );

create policy cafe_order_items_insert on public.cafe_order_items
  for insert to authenticated
  with check (
    exists (
      select 1 from public.cafe_orders o
      where o.id = order_id
        and public.app_can_run_cafe_terminal(o.cafe_id)
    )
  );

create policy cafe_order_items_update on public.cafe_order_items
  for update to authenticated
  using (
    exists (
      select 1 from public.cafe_orders o
      where o.id = order_id
        and public.app_can_run_cafe_terminal(o.cafe_id)
    )
  )
  with check (
    exists (
      select 1 from public.cafe_orders o
      where o.id = order_id
        and public.app_can_run_cafe_terminal(o.cafe_id)
    )
  );

create policy cafe_order_items_delete on public.cafe_order_items
  for delete to authenticated
  using (public.app_is_staff());

-- Payments
drop policy if exists cafe_payments_select on public.cafe_payments;
drop policy if exists cafe_payments_insert on public.cafe_payments;
drop policy if exists cafe_payments_update on public.cafe_payments;
drop policy if exists cafe_payments_delete on public.cafe_payments;

create policy cafe_payments_select on public.cafe_payments
  for select to authenticated
  using (public.app_can_access_cafe(cafe_id));

create policy cafe_payments_insert on public.cafe_payments
  for insert to authenticated
  with check (public.app_can_run_cafe_terminal(cafe_id));

create policy cafe_payments_update on public.cafe_payments
  for update to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());

create policy cafe_payments_delete on public.cafe_payments
  for delete to authenticated
  using (public.app_is_staff());

-- Coupons (if cafe_pos_coupons.sql already created the table)
do $$
begin
  if to_regclass('public.cafe_coupons') is not null then
    grant select, insert, update, delete on table public.cafe_coupons to authenticated;

    drop policy if exists cafe_coupons_select on public.cafe_coupons;
    drop policy if exists cafe_coupons_insert on public.cafe_coupons;
    drop policy if exists cafe_coupons_update on public.cafe_coupons;
    drop policy if exists cafe_coupons_delete on public.cafe_coupons;

    create policy cafe_coupons_select on public.cafe_coupons
      for select to authenticated
      using (public.app_can_access_cafe(cafe_id));

    create policy cafe_coupons_insert on public.cafe_coupons
      for insert to authenticated
      with check (public.app_can_manage_cafe_menu(cafe_id));

    create policy cafe_coupons_update on public.cafe_coupons
      for update to authenticated
      using (
        public.app_can_manage_cafe_menu(cafe_id)
        or public.app_can_run_cafe_terminal(cafe_id)
      )
      with check (
        public.app_can_manage_cafe_menu(cafe_id)
        or public.app_can_run_cafe_terminal(cafe_id)
      );

    create policy cafe_coupons_delete on public.cafe_coupons
      for delete to authenticated
      using (public.app_can_manage_cafe_menu(cafe_id));
  end if;
end $$;

select 'Cafe POS RLS restored' as status;
