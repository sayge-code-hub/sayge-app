-- One-time reset: switch Cafe POS from Settings clients → public.cafes.
-- DESTRUCTIVE for cafe_* operational data (menu/orders/payments).
-- Safe when POS was just installed with no real cafe data.
--
-- After this file, run:
--   1. cafe_pos.sql
--   2. security_hardening.sql

drop policy if exists clients_select_cafe_scoped on public.clients;

drop table if exists public.cafe_payments cascade;
drop table if exists public.cafe_order_items cascade;
drop table if exists public.cafe_orders cascade;
drop table if exists public.cafe_menu_items cascade;
drop table if exists public.cafe_categories cascade;

-- Old helpers (client-scoped)
drop function if exists public.app_client_id() cascade;
drop function if exists public.app_can_access_cafe_client(text) cascade;
-- Signatures that will be recreated; drop so recreate is clean
drop function if exists public.app_can_manage_cafe_menu(text) cascade;
drop function if exists public.app_can_run_cafe_terminal(text) cascade;
drop function if exists public.app_can_run_cafe_kitchen(text) cascade;
drop function if exists public.app_is_cafe_role() cascade;
drop function if exists public.app_cafe_id() cascade;
drop function if exists public.app_can_access_cafe(text) cascade;

-- users.client_id was POS-only; cafe_id replaces it
alter table public.users drop column if exists client_id;
