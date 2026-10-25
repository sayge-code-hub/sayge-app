-- Menu item add-ons (safe to re-run).
-- Optional extras guests/waiters can attach when ordering.

create table if not exists public.cafe_menu_addons (
  id text primary key,
  cafe_id text not null references public.cafes (id) on delete cascade,
  menu_item_id text not null references public.cafe_menu_items (id) on delete cascade,
  name text not null,
  price numeric(12, 2) not null default 0 check (price >= 0),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cafe_menu_addons_item_idx
  on public.cafe_menu_addons (menu_item_id, sort_order, name);

create index if not exists cafe_menu_addons_cafe_idx
  on public.cafe_menu_addons (cafe_id);

alter table public.cafe_menu_addons enable row level security;

revoke all on table public.cafe_menu_addons from anon, public;
grant select, insert, update, delete on table public.cafe_menu_addons to authenticated;

drop policy if exists cafe_menu_addons_select on public.cafe_menu_addons;
drop policy if exists cafe_menu_addons_insert on public.cafe_menu_addons;
drop policy if exists cafe_menu_addons_update on public.cafe_menu_addons;
drop policy if exists cafe_menu_addons_delete on public.cafe_menu_addons;

create policy cafe_menu_addons_select on public.cafe_menu_addons
  for select to authenticated
  using (public.app_can_access_cafe(cafe_id));

create policy cafe_menu_addons_insert on public.cafe_menu_addons
  for insert to authenticated
  with check (public.app_can_manage_cafe_menu(cafe_id));

create policy cafe_menu_addons_update on public.cafe_menu_addons
  for update to authenticated
  using (public.app_can_manage_cafe_menu(cafe_id))
  with check (public.app_can_manage_cafe_menu(cafe_id));

create policy cafe_menu_addons_delete on public.cafe_menu_addons
  for delete to authenticated
  using (public.app_can_manage_cafe_menu(cafe_id));

do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    drop trigger if exists cafe_menu_addons_set_updated_at on public.cafe_menu_addons;
    create trigger cafe_menu_addons_set_updated_at
      before update on public.cafe_menu_addons
      for each row execute function public.set_updated_at();
  end if;
end $$;
