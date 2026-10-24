-- Demo cafe for client walkthroughs. Idempotent — safe to re-run.
-- Requires cafe_pos.sql already applied.

-- ---------------------------------------------------------------------------
-- Cafe
-- ---------------------------------------------------------------------------
insert into public.cafes (id, name, is_active)
values ('cafe_demo_sayge', 'Sayge Demo Cafe', true)
on conflict (id) do update
set name = excluded.name, is_active = true, updated_at = now();

-- Wipe prior demo menu/orders so re-seed is clean
delete from public.cafe_payments where cafe_id = 'cafe_demo_sayge';
delete from public.cafe_order_items
where order_id in (select id from public.cafe_orders where cafe_id = 'cafe_demo_sayge');
delete from public.cafe_orders where cafe_id = 'cafe_demo_sayge';
delete from public.cafe_menu_items where cafe_id = 'cafe_demo_sayge';
delete from public.cafe_categories where cafe_id = 'cafe_demo_sayge';

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------
insert into public.cafe_categories (id, cafe_id, name, sort_order, is_active) values
  ('ccat_demo_coffee', 'cafe_demo_sayge', 'Coffee', 0, true),
  ('ccat_demo_tea', 'cafe_demo_sayge', 'Tea', 1, true),
  ('ccat_demo_snacks', 'cafe_demo_sayge', 'Snacks', 2, true),
  ('ccat_demo_beverages', 'cafe_demo_sayge', 'Cold drinks', 3, true);

-- ---------------------------------------------------------------------------
-- Menu items (INR prices, light tax for bill demo)
-- ---------------------------------------------------------------------------
insert into public.cafe_menu_items (
  id, cafe_id, category_id, name, price, tax_rate, is_available, is_active, sort_order
) values
  ('citem_demo_espresso', 'cafe_demo_sayge', 'ccat_demo_coffee', 'Espresso', 80, 5, true, true, 0),
  ('citem_demo_americano', 'cafe_demo_sayge', 'ccat_demo_coffee', 'Americano', 120, 5, true, true, 1),
  ('citem_demo_latte', 'cafe_demo_sayge', 'ccat_demo_coffee', 'Caffe Latte', 160, 5, true, true, 2),
  ('citem_demo_cappuccino', 'cafe_demo_sayge', 'ccat_demo_coffee', 'Cappuccino', 150, 5, true, true, 3),
  ('citem_demo_flatwhite', 'cafe_demo_sayge', 'ccat_demo_coffee', 'Flat White', 170, 5, true, true, 4),
  ('citem_demo_masala', 'cafe_demo_sayge', 'ccat_demo_tea', 'Masala Chai', 60, 5, true, true, 0),
  ('citem_demo_ginger', 'cafe_demo_sayge', 'ccat_demo_tea', 'Ginger Tea', 70, 5, true, true, 1),
  ('citem_demo_green', 'cafe_demo_sayge', 'ccat_demo_tea', 'Green Tea', 90, 5, true, true, 2),
  ('citem_demo_samosa', 'cafe_demo_sayge', 'ccat_demo_snacks', 'Samosa (2 pcs)', 50, 5, true, true, 0),
  ('citem_demo_sandwich', 'cafe_demo_sayge', 'ccat_demo_snacks', 'Veg Sandwich', 120, 5, true, true, 1),
  ('citem_demo_croissant', 'cafe_demo_sayge', 'ccat_demo_snacks', 'Butter Croissant', 110, 5, true, true, 2),
  ('citem_demo_cookie', 'cafe_demo_sayge', 'ccat_demo_snacks', 'Chocolate Cookie', 80, 5, true, true, 3),
  ('citem_demo_lemonade', 'cafe_demo_sayge', 'ccat_demo_beverages', 'Fresh Lemonade', 100, 5, true, true, 0),
  ('citem_demo_coldbrew', 'cafe_demo_sayge', 'ccat_demo_beverages', 'Cold Brew', 180, 5, true, true, 1),
  ('citem_demo_water', 'cafe_demo_sayge', 'ccat_demo_beverages', 'Mineral Water', 30, 0, true, true, 2);

-- ---------------------------------------------------------------------------
-- Sample open kitchen tickets (unpaid prep board demo)
-- ---------------------------------------------------------------------------
insert into public.cafe_orders (
  id, cafe_id, order_no, order_type, prep_status, payment_status,
  subtotal, tax_amount, discount_amount, total_amount
) values
  (
    'cord_demo_new_1', 'cafe_demo_sayge', 'DEMO-001', 'dine_in', 'new', 'paid',
    280, 14, 0, 294
  ),
  (
    'cord_demo_prep_1', 'cafe_demo_sayge', 'DEMO-002', 'takeaway', 'preparing', 'paid',
    230, 11.5, 0, 241.5
  ),
  (
    'cord_demo_ready_1', 'cafe_demo_sayge', 'DEMO-003', 'dine_in', 'ready', 'paid',
    170, 8.5, 0, 178.5
  );

insert into public.cafe_order_items (
  id, order_id, menu_item_id, item_name, unit_price, tax_rate, quantity, line_total, notes, sort_order
) values
  ('coli_demo_1a', 'cord_demo_new_1', 'citem_demo_latte', 'Caffe Latte', 160, 5, 1, 160, 'Oat milk', 0),
  ('coli_demo_1b', 'cord_demo_new_1', 'citem_demo_sandwich', 'Veg Sandwich', 120, 5, 1, 120, '', 1),
  ('coli_demo_2a', 'cord_demo_prep_1', 'citem_demo_cappuccino', 'Cappuccino', 150, 5, 1, 150, '', 0),
  ('coli_demo_2b', 'cord_demo_prep_1', 'citem_demo_cookie', 'Chocolate Cookie', 80, 5, 1, 80, '', 1),
  ('coli_demo_3a', 'cord_demo_ready_1', 'citem_demo_americano', 'Americano', 120, 5, 1, 120, '', 0),
  ('coli_demo_3b', 'cord_demo_ready_1', 'citem_demo_samosa', 'Samosa (2 pcs)', 50, 5, 1, 50, '', 1);

select 'Demo cafe ready: Sayge Demo Cafe (cafe_demo_sayge)' as status;
