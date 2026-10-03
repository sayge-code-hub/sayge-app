-- POS product commerce: generic product master, attributes, purchases,
-- price rules, field-level audit. Preserves existing rows.

-- ---------------------------------------------------------------------------
-- Evolve pos_products (niche fields → generic commerce fields)
-- ---------------------------------------------------------------------------
alter table public.pos_products
  add column if not exists product_type text not null default 'product',
  add column if not exists label_brand text not null default '',
  add column if not exists current_purchase_cost numeric(14, 2) not null default 0,
  add column if not exists selling_price numeric(14, 2),
  add column if not exists mrp numeric(14, 2) not null default 0,
  add column if not exists tax_rate numeric(8, 4) not null default 0,
  add column if not exists price_includes_tax boolean not null default true,
  add column if not exists track_inventory boolean not null default true,
  add column if not exists unit_of_measure text not null default 'Piece',
  add column if not exists opening_stock numeric(14, 3) not null default 0,
  add column if not exists reorder_level numeric(14, 3) not null default 0,
  add column if not exists units_per_pack numeric(14, 3) not null default 1,
  add column if not exists stock_on_hand numeric(14, 3),
  add column if not exists barcode text not null default '';

-- Migrate legacy pricing / stock into new columns (idempotent).
update public.pos_products
set selling_price = coalesce(selling_price, price, 0),
    mrp = case when mrp = 0 then coalesce(compare_at_price, 0) else mrp end,
    stock_on_hand = coalesce(stock_on_hand, stock_qty::numeric, 0),
    opening_stock = case
      when opening_stock = 0 then coalesce(stock_qty::numeric, 0)
      else opening_stock
    end
where true;

alter table public.pos_products
  alter column selling_price set default 0,
  alter column selling_price set not null,
  alter column stock_on_hand set default 0,
  alter column stock_on_hand set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pos_products_product_type_check'
  ) then
    alter table public.pos_products
      add constraint pos_products_product_type_check
      check (product_type in ('product', 'service'));
  end if;
end $$;

-- Drop niche-specific columns (no longer used; attributes replace them).
alter table public.pos_products drop column if exists color;
alter table public.pos_products drop column if exists material;
alter table public.pos_products drop column if exists dimensions;
alter table public.pos_products drop column if exists care_instructions;
alter table public.pos_products drop column if exists price;
alter table public.pos_products drop column if exists compare_at_price;
alter table public.pos_products drop column if exists stock_qty;

create unique index if not exists pos_products_brand_sku_uidx
  on public.pos_products (brand_id, lower(sku))
  where sku is not null and btrim(sku) <> '';

-- ---------------------------------------------------------------------------
-- Attributes (generic key/value)
-- ---------------------------------------------------------------------------
create table if not exists public.pos_product_attributes (
  id text primary key,
  product_id text not null references public.pos_products (id) on delete cascade,
  name text not null,
  value text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pos_product_attributes_product_id_idx
  on public.pos_product_attributes (product_id, sort_order);

-- ---------------------------------------------------------------------------
-- Variants (future-ready; optional, not forced in UI)
-- ---------------------------------------------------------------------------
create table if not exists public.pos_product_variants (
  id text primary key,
  product_id text not null references public.pos_products (id) on delete cascade,
  sku text not null default '',
  barcode text not null default '',
  selling_price numeric(14, 2),
  current_purchase_cost numeric(14, 2),
  stock_on_hand numeric(14, 3) not null default 0,
  attributes jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pos_product_variants_product_id_idx
  on public.pos_product_variants (product_id);

-- ---------------------------------------------------------------------------
-- Procurement: purchases + line items (historical unit costs immutable)
-- ---------------------------------------------------------------------------
create table if not exists public.pos_purchases (
  id text primary key,
  brand_id text not null references public.pos_brands (id) on delete cascade,
  supplier_name text not null default '',
  purchase_date date not null default (timezone('utc', now()))::date,
  invoice_number text not null default '',
  notes text not null default '',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pos_purchase_items (
  id text primary key,
  purchase_id text not null references public.pos_purchases (id) on delete cascade,
  product_id text not null references public.pos_products (id) on delete restrict,
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_cost numeric(14, 4) not null check (unit_cost >= 0),
  discount numeric(14, 2) not null default 0,
  tax numeric(14, 2) not null default 0,
  additional_cost numeric(14, 2) not null default 0,
  total_cost numeric(14, 2) not null default 0,
  batch_number text not null default '',
  expiry_date date,
  created_at timestamptz not null default now()
);

create index if not exists pos_purchases_brand_id_idx
  on public.pos_purchases (brand_id, purchase_date desc);
create index if not exists pos_purchase_items_product_id_idx
  on public.pos_purchase_items (product_id, created_at desc);
create index if not exists pos_purchase_items_purchase_id_idx
  on public.pos_purchase_items (purchase_id);

-- ---------------------------------------------------------------------------
-- Price rules / promotions (do not overwrite base selling_price)
-- ---------------------------------------------------------------------------
create table if not exists public.pos_price_rules (
  id text primary key,
  brand_id text not null references public.pos_brands (id) on delete cascade,
  product_id text not null references public.pos_products (id) on delete cascade,
  name text not null,
  discount_type text not null,
  discount_value numeric(14, 4) not null default 0,
  final_price numeric(14, 2),
  start_at timestamptz not null,
  end_at timestamptz not null,
  minimum_quantity numeric(14, 3),
  maximum_quantity numeric(14, 3),
  priority integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pos_price_rules_discount_type_check
    check (discount_type in ('percentage', 'fixed_amount', 'fixed_price')),
  constraint pos_price_rules_dates_check check (end_at >= start_at)
);

create index if not exists pos_price_rules_product_id_idx
  on public.pos_price_rules (product_id, start_at, end_at);
create index if not exists pos_price_rules_brand_id_idx
  on public.pos_price_rules (brand_id);

-- ---------------------------------------------------------------------------
-- Field-level commerce audit (immutable via RLS; app inserts only)
-- ---------------------------------------------------------------------------
create table if not exists public.pos_commerce_audit (
  id text primary key,
  entity_type text not null,
  entity_id text not null,
  brand_id text references public.pos_brands (id) on delete set null,
  action text not null,
  field_name text not null default '',
  old_value text not null default '',
  new_value text not null default '',
  reason text not null default '',
  performed_by uuid references auth.users (id) on delete set null,
  performed_by_email text not null default '',
  performed_at timestamptz not null default now()
);

create index if not exists pos_commerce_audit_entity_idx
  on public.pos_commerce_audit (entity_type, entity_id, performed_at desc);
create index if not exists pos_commerce_audit_brand_idx
  on public.pos_commerce_audit (brand_id, performed_at desc);

-- ---------------------------------------------------------------------------
-- Triggers / activity log
-- ---------------------------------------------------------------------------
drop trigger if exists pos_product_attributes_set_updated_at on public.pos_product_attributes;
create trigger pos_product_attributes_set_updated_at
  before update on public.pos_product_attributes
  for each row execute function public.set_updated_at();

drop trigger if exists pos_product_variants_set_updated_at on public.pos_product_variants;
create trigger pos_product_variants_set_updated_at
  before update on public.pos_product_variants
  for each row execute function public.set_updated_at();

drop trigger if exists pos_purchases_set_updated_at on public.pos_purchases;
create trigger pos_purchases_set_updated_at
  before update on public.pos_purchases
  for each row execute function public.set_updated_at();

drop trigger if exists pos_price_rules_set_updated_at on public.pos_price_rules;
create trigger pos_price_rules_set_updated_at
  before update on public.pos_price_rules
  for each row execute function public.set_updated_at();

do $$
begin
  drop trigger if exists pos_product_attributes_activity_log on public.pos_product_attributes;
  create trigger pos_product_attributes_activity_log
    after insert or update or delete on public.pos_product_attributes
    for each row execute function public.log_row_activity();

  drop trigger if exists pos_purchases_activity_log on public.pos_purchases;
  create trigger pos_purchases_activity_log
    after insert or update or delete on public.pos_purchases
    for each row execute function public.log_row_activity();

  drop trigger if exists pos_purchase_items_activity_log on public.pos_purchase_items;
  create trigger pos_purchase_items_activity_log
    after insert or update or delete on public.pos_purchase_items
    for each row execute function public.log_row_activity();

  drop trigger if exists pos_price_rules_activity_log on public.pos_price_rules;
  create trigger pos_price_rules_activity_log
    after insert or update or delete on public.pos_price_rules
    for each row execute function public.log_row_activity();
end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.pos_product_attributes enable row level security;
alter table public.pos_product_variants enable row level security;
alter table public.pos_purchases enable row level security;
alter table public.pos_purchase_items enable row level security;
alter table public.pos_price_rules enable row level security;
alter table public.pos_commerce_audit enable row level security;

drop policy if exists "pos_product_attributes_select_rbac" on public.pos_product_attributes;
drop policy if exists "pos_product_attributes_insert_rbac" on public.pos_product_attributes;
drop policy if exists "pos_product_attributes_update_rbac" on public.pos_product_attributes;
drop policy if exists "pos_product_attributes_delete_rbac" on public.pos_product_attributes;
create policy "pos_product_attributes_select_rbac"
  on public.pos_product_attributes for select to authenticated
  using (public.app_is_staff());
create policy "pos_product_attributes_insert_rbac"
  on public.pos_product_attributes for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_product_attributes_update_rbac"
  on public.pos_product_attributes for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_product_attributes_delete_rbac"
  on public.pos_product_attributes for delete to authenticated
  using (public.app_is_staff());

drop policy if exists "pos_product_variants_select_rbac" on public.pos_product_variants;
drop policy if exists "pos_product_variants_insert_rbac" on public.pos_product_variants;
drop policy if exists "pos_product_variants_update_rbac" on public.pos_product_variants;
drop policy if exists "pos_product_variants_delete_rbac" on public.pos_product_variants;
create policy "pos_product_variants_select_rbac"
  on public.pos_product_variants for select to authenticated
  using (public.app_is_staff());
create policy "pos_product_variants_insert_rbac"
  on public.pos_product_variants for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_product_variants_update_rbac"
  on public.pos_product_variants for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_product_variants_delete_rbac"
  on public.pos_product_variants for delete to authenticated
  using (public.app_is_staff());

drop policy if exists "pos_purchases_select_rbac" on public.pos_purchases;
drop policy if exists "pos_purchases_insert_rbac" on public.pos_purchases;
drop policy if exists "pos_purchases_update_rbac" on public.pos_purchases;
drop policy if exists "pos_purchases_delete_rbac" on public.pos_purchases;
create policy "pos_purchases_select_rbac"
  on public.pos_purchases for select to authenticated
  using (public.app_is_staff());
create policy "pos_purchases_insert_rbac"
  on public.pos_purchases for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_purchases_update_rbac"
  on public.pos_purchases for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_purchases_delete_rbac"
  on public.pos_purchases for delete to authenticated
  using (public.app_is_staff());

drop policy if exists "pos_purchase_items_select_rbac" on public.pos_purchase_items;
drop policy if exists "pos_purchase_items_insert_rbac" on public.pos_purchase_items;
drop policy if exists "pos_purchase_items_update_rbac" on public.pos_purchase_items;
drop policy if exists "pos_purchase_items_delete_rbac" on public.pos_purchase_items;
create policy "pos_purchase_items_select_rbac"
  on public.pos_purchase_items for select to authenticated
  using (public.app_is_staff());
create policy "pos_purchase_items_insert_rbac"
  on public.pos_purchase_items for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_purchase_items_update_rbac"
  on public.pos_purchase_items for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_purchase_items_delete_rbac"
  on public.pos_purchase_items for delete to authenticated
  using (public.app_is_staff());

drop policy if exists "pos_price_rules_select_rbac" on public.pos_price_rules;
drop policy if exists "pos_price_rules_insert_rbac" on public.pos_price_rules;
drop policy if exists "pos_price_rules_update_rbac" on public.pos_price_rules;
drop policy if exists "pos_price_rules_delete_rbac" on public.pos_price_rules;
create policy "pos_price_rules_select_rbac"
  on public.pos_price_rules for select to authenticated
  using (public.app_is_staff());
create policy "pos_price_rules_insert_rbac"
  on public.pos_price_rules for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_price_rules_update_rbac"
  on public.pos_price_rules for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_price_rules_delete_rbac"
  on public.pos_price_rules for delete to authenticated
  using (public.app_is_staff());

-- Audit: staff can read + insert; no update/delete (immutable).
drop policy if exists "pos_commerce_audit_select_rbac" on public.pos_commerce_audit;
drop policy if exists "pos_commerce_audit_insert_rbac" on public.pos_commerce_audit;
create policy "pos_commerce_audit_select_rbac"
  on public.pos_commerce_audit for select to authenticated
  using (public.app_is_staff());
create policy "pos_commerce_audit_insert_rbac"
  on public.pos_commerce_audit for insert to authenticated
  with check (public.app_is_staff());

grant select, insert, update, delete on public.pos_product_attributes to authenticated;
grant select, insert, update, delete on public.pos_product_variants to authenticated;
grant select, insert, update, delete on public.pos_purchases to authenticated;
grant select, insert, update, delete on public.pos_purchase_items to authenticated;
grant select, insert, update, delete on public.pos_price_rules to authenticated;
grant select, insert on public.pos_commerce_audit to authenticated;
revoke update, delete on public.pos_commerce_audit from authenticated;
