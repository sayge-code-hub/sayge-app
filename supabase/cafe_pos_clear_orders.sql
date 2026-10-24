-- Wipe all Cafe POS orders / payments (reports are derived from these).
-- Safe to re-run. Does NOT touch menu, categories, coupons, or cafes.

delete from public.cafe_payments;
delete from public.cafe_order_items;
delete from public.cafe_orders;
