-- Cafe POS MVP — Cafe-scoped menu, orders, kitchen, payments.
-- Tenant = public.cafes (created in POS), NOT Settings clients.
-- Apply after schema.sql. Always re-run security_hardening.sql after this file.

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
insert into public.roles (id, code, label, description, sort_order)
values
  ('role_cafe_admin', 'cafe_admin', 'Cafe admin', 'Manage one cafe menu, orders, and reports', 55),
  ('role_cashier', 'cashier', 'Cashier', 'Create orders and record payments for one cafe', 56),
  ('role_kitchen', 'kitchen', 'Kitchen', 'View and update kitchen prep status for one cafe', 57)
on conflict (id) do update
set
  label = excluded.label,
  description = excluded.description,
  sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Cafes (POS tenants)
-- ---------------------------------------------------------------------------
create table if not exists public.cafes (
  id text primary key,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cafes_active_name_idx
  on public.cafes (is_active, name);

-- ---------------------------------------------------------------------------
-- users.cafe_id — scopes cafe_admin / cashier / kitchen to one Cafe
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists cafe_id text references public.cafes (id) on delete set null;

create index if not exists users_cafe_id_idx on public.users (cafe_id);

-- Drop legacy POS binding to Settings clients (if present from earlier pack).
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'client_id'
  ) then
    -- Only drop if nothing meaningful depends on it for POS; employees use employees.client_id.
    alter table public.users drop column if exists client_id;
  end if;
exception
  when others then
    raise notice 'users.client_id drop skipped: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- Helpers (SECURITY DEFINER)
-- ---------------------------------------------------------------------------
create or replace function public.app_cafe_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select cafe_id
  from public.users
  where id = auth.uid()
    and is_active is true
  limit 1;
$$;

create or replace function public.app_is_cafe_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_role_code() in ('cafe_admin', 'cashier', 'kitchen');
$$;

create or replace function public.app_can_access_cafe(p_cafe_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.app_is_staff()
    or (
      public.app_is_cafe_role()
      and public.app_cafe_id() is not null
      and public.app_cafe_id() = p_cafe_id
    );
$$;

create or replace function public.app_can_manage_cafe_menu(p_cafe_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.app_is_staff()
    or (
      public.app_role_code() = 'cafe_admin'
      and public.app_cafe_id() = p_cafe_id
    );
$$;

create or replace function public.app_can_run_cafe_terminal(p_cafe_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.app_is_staff()
    or (
      public.app_role_code() in ('cafe_admin', 'cashier')
      and public.app_cafe_id() = p_cafe_id
    );
$$;

create or replace function public.app_can_run_cafe_kitchen(p_cafe_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.app_is_staff()
    or (
      public.app_role_code() in ('cafe_admin', 'kitchen')
      and public.app_cafe_id() = p_cafe_id
    );
$$;

grant execute on function public.app_cafe_id() to authenticated, service_role;
grant execute on function public.app_is_cafe_role() to authenticated, service_role;
grant execute on function public.app_can_access_cafe(text) to authenticated, service_role;
grant execute on function public.app_can_manage_cafe_menu(text) to authenticated, service_role;
grant execute on function public.app_can_run_cafe_terminal(text) to authenticated, service_role;
grant execute on function public.app_can_run_cafe_kitchen(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Operational tables (cafe_id)
-- ---------------------------------------------------------------------------
create table if not exists public.cafe_categories (
  id text primary key,
  cafe_id text not null references public.cafes (id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cafe_categories_cafe_idx
  on public.cafe_categories (cafe_id, sort_order);

create table if not exists public.cafe_menu_items (
  id text primary key,
  cafe_id text not null references public.cafes (id) on delete cascade,
  category_id text not null references public.cafe_categories (id) on delete restrict,
  name text not null,
  price numeric(12, 2) not null check (price >= 0),
  tax_rate numeric(5, 2) not null default 0 check (tax_rate >= 0),
  is_available boolean not null default true,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cafe_menu_items_cafe_idx
  on public.cafe_menu_items (cafe_id, category_id, sort_order);

create table if not exists public.cafe_orders (
  id text primary key,
  cafe_id text not null references public.cafes (id) on delete cascade,
  order_no text not null,
  order_type text not null check (order_type in ('dine_in', 'takeaway')),
  prep_status text not null default 'new'
    check (prep_status in ('new', 'preparing', 'ready', 'completed', 'cancelled')),
  payment_status text not null default 'pending'
    check (payment_status in ('pending', 'paid', 'refunded')),
  subtotal numeric(12, 2) not null default 0,
  tax_amount numeric(12, 2) not null default 0,
  discount_amount numeric(12, 2) not null default 0,
  total_amount numeric(12, 2) not null default 0,
  cancel_reason text not null default '',
  cancelled_by uuid references auth.users (id) on delete set null,
  cancelled_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cafe_id, order_no)
);

create index if not exists cafe_orders_cafe_created_idx
  on public.cafe_orders (cafe_id, created_at desc);
create index if not exists cafe_orders_prep_idx
  on public.cafe_orders (cafe_id, prep_status);

create table if not exists public.cafe_order_items (
  id text primary key,
  order_id text not null references public.cafe_orders (id) on delete cascade,
  menu_item_id text references public.cafe_menu_items (id) on delete set null,
  item_name text not null,
  unit_price numeric(12, 2) not null,
  tax_rate numeric(5, 2) not null default 0,
  quantity numeric(12, 2) not null check (quantity > 0),
  line_total numeric(12, 2) not null,
  notes text not null default '',
  sort_order int not null default 0
);

create index if not exists cafe_order_items_order_idx
  on public.cafe_order_items (order_id, sort_order);

create table if not exists public.cafe_payments (
  id text primary key,
  order_id text not null references public.cafe_orders (id) on delete cascade,
  cafe_id text not null references public.cafes (id) on delete cascade,
  method text not null check (method in ('cash', 'upi', 'card')),
  amount numeric(12, 2) not null check (amount >= 0),
  recorded_by uuid references auth.users (id) on delete set null,
  recorded_at timestamptz not null default now()
);

create index if not exists cafe_payments_cafe_idx
  on public.cafe_payments (cafe_id, recorded_at desc);
create index if not exists cafe_payments_order_idx
  on public.cafe_payments (order_id);

-- updated_at triggers
do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    drop trigger if exists cafes_set_updated_at on public.cafes;
    create trigger cafes_set_updated_at
      before update on public.cafes
      for each row execute function public.set_updated_at();

    drop trigger if exists cafe_categories_set_updated_at on public.cafe_categories;
    create trigger cafe_categories_set_updated_at
      before update on public.cafe_categories
      for each row execute function public.set_updated_at();

    drop trigger if exists cafe_menu_items_set_updated_at on public.cafe_menu_items;
    create trigger cafe_menu_items_set_updated_at
      before update on public.cafe_menu_items
      for each row execute function public.set_updated_at();

    drop trigger if exists cafe_orders_set_updated_at on public.cafe_orders;
    create trigger cafe_orders_set_updated_at
      before update on public.cafe_orders
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Grants + RLS
-- ---------------------------------------------------------------------------
alter table public.cafes enable row level security;
alter table public.cafe_categories enable row level security;
alter table public.cafe_menu_items enable row level security;
alter table public.cafe_orders enable row level security;
alter table public.cafe_order_items enable row level security;
alter table public.cafe_payments enable row level security;

revoke all on table public.cafes from anon, public;
revoke all on table public.cafe_categories from anon, public;
revoke all on table public.cafe_menu_items from anon, public;
revoke all on table public.cafe_orders from anon, public;
revoke all on table public.cafe_order_items from anon, public;
revoke all on table public.cafe_payments from anon, public;

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

-- Remove legacy clients_select_cafe_scoped if present
drop policy if exists clients_select_cafe_scoped on public.clients;
