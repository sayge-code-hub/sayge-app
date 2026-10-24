-- Cafe POS coupons — run on existing projects (safe to re-run).
-- Also mirrored into cafe_pos.sql for fresh installs.

create table if not exists public.cafe_coupons (
  id text primary key,
  cafe_id text not null references public.cafes (id) on delete cascade,
  code text not null,
  name text not null default '',
  discount_type text not null check (discount_type in ('percent', 'fixed')),
  discount_value numeric(12, 2) not null check (discount_value > 0),
  min_order_amount numeric(12, 2) not null default 0 check (min_order_amount >= 0),
  max_discount_amount numeric(12, 2),
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  max_uses int,
  usage_count int not null default 0 check (usage_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cafe_id, code)
);

create index if not exists cafe_coupons_cafe_idx
  on public.cafe_coupons (cafe_id, is_active);

-- Snapshot of applied coupon on orders (optional columns).
alter table public.cafe_orders
  add column if not exists coupon_id text references public.cafe_coupons (id) on delete set null;
alter table public.cafe_orders
  add column if not exists coupon_code text not null default '';

do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    drop trigger if exists cafe_coupons_set_updated_at on public.cafe_coupons;
    create trigger cafe_coupons_set_updated_at
      before update on public.cafe_coupons
      for each row execute function public.set_updated_at();
  end if;
end $$;

alter table public.cafe_coupons enable row level security;

revoke all on table public.cafe_coupons from anon, public;
grant select, insert, update, delete on table public.cafe_coupons to authenticated;

drop policy if exists cafe_coupons_select on public.cafe_coupons;
drop policy if exists cafe_coupons_insert on public.cafe_coupons;
drop policy if exists cafe_coupons_update on public.cafe_coupons;
drop policy if exists cafe_coupons_delete on public.cafe_coupons;

-- Terminal/kitchen need to read active coupons to apply codes.
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
