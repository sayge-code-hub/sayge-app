-- POS: multi-brand shops + products with images
-- Staff (owner/admin) only.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.pos_brands (
  id text primary key,
  name text not null,
  description text not null default '',
  logo_path text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pos_products (
  id text primary key,
  brand_id text not null references public.pos_brands (id) on delete cascade,
  name text not null,
  sku text not null default '',
  short_description text not null default '',
  description text not null default '',
  category text not null default '',
  color text not null default '',
  material text not null default '',
  dimensions text not null default '',
  care_instructions text not null default '',
  price numeric(14, 2) not null default 0,
  compare_at_price numeric(14, 2) not null default 0,
  stock_qty integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pos_product_images (
  id text primary key,
  product_id text not null references public.pos_products (id) on delete cascade,
  storage_path text not null,
  file_name text not null default '',
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists pos_brands_name_idx on public.pos_brands (name);
create index if not exists pos_products_brand_id_idx on public.pos_products (brand_id);
create index if not exists pos_products_name_idx on public.pos_products (name);
create index if not exists pos_products_sku_idx on public.pos_products (sku);
create index if not exists pos_product_images_product_id_idx
  on public.pos_product_images (product_id, sort_order);

drop trigger if exists pos_brands_set_updated_at on public.pos_brands;
create trigger pos_brands_set_updated_at
  before update on public.pos_brands
  for each row execute function public.set_updated_at();

drop trigger if exists pos_products_set_updated_at on public.pos_products;
create trigger pos_products_set_updated_at
  before update on public.pos_products
  for each row execute function public.set_updated_at();

do $$
begin
  drop trigger if exists pos_brands_activity_log on public.pos_brands;
  create trigger pos_brands_activity_log
    after insert or update or delete on public.pos_brands
    for each row execute function public.log_row_activity();

  drop trigger if exists pos_products_activity_log on public.pos_products;
  create trigger pos_products_activity_log
    after insert or update or delete on public.pos_products
    for each row execute function public.log_row_activity();
end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.pos_brands enable row level security;
alter table public.pos_products enable row level security;
alter table public.pos_product_images enable row level security;

drop policy if exists "pos_brands_select_rbac" on public.pos_brands;
drop policy if exists "pos_brands_insert_rbac" on public.pos_brands;
drop policy if exists "pos_brands_update_rbac" on public.pos_brands;
drop policy if exists "pos_brands_delete_rbac" on public.pos_brands;

create policy "pos_brands_select_rbac"
  on public.pos_brands for select to authenticated
  using (public.app_is_staff());
create policy "pos_brands_insert_rbac"
  on public.pos_brands for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_brands_update_rbac"
  on public.pos_brands for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_brands_delete_rbac"
  on public.pos_brands for delete to authenticated
  using (public.app_is_staff());

drop policy if exists "pos_products_select_rbac" on public.pos_products;
drop policy if exists "pos_products_insert_rbac" on public.pos_products;
drop policy if exists "pos_products_update_rbac" on public.pos_products;
drop policy if exists "pos_products_delete_rbac" on public.pos_products;

create policy "pos_products_select_rbac"
  on public.pos_products for select to authenticated
  using (public.app_is_staff());
create policy "pos_products_insert_rbac"
  on public.pos_products for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_products_update_rbac"
  on public.pos_products for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_products_delete_rbac"
  on public.pos_products for delete to authenticated
  using (public.app_is_staff());

drop policy if exists "pos_product_images_select_rbac" on public.pos_product_images;
drop policy if exists "pos_product_images_insert_rbac" on public.pos_product_images;
drop policy if exists "pos_product_images_update_rbac" on public.pos_product_images;
drop policy if exists "pos_product_images_delete_rbac" on public.pos_product_images;

create policy "pos_product_images_select_rbac"
  on public.pos_product_images for select to authenticated
  using (public.app_is_staff());
create policy "pos_product_images_insert_rbac"
  on public.pos_product_images for insert to authenticated
  with check (public.app_is_staff());
create policy "pos_product_images_update_rbac"
  on public.pos_product_images for update to authenticated
  using (public.app_is_staff()) with check (public.app_is_staff());
create policy "pos_product_images_delete_rbac"
  on public.pos_product_images for delete to authenticated
  using (public.app_is_staff());

grant select, insert, update, delete on public.pos_brands to authenticated;
grant select, insert, update, delete on public.pos_products to authenticated;
grant select, insert, update, delete on public.pos_product_images to authenticated;

-- ---------------------------------------------------------------------------
-- Storage bucket for product images
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pos-product-images',
  'pos-product-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "pos_product_images_storage_select" on storage.objects;
drop policy if exists "pos_product_images_storage_insert" on storage.objects;
drop policy if exists "pos_product_images_storage_update" on storage.objects;
drop policy if exists "pos_product_images_storage_delete" on storage.objects;

create policy "pos_product_images_storage_select"
  on storage.objects for select to authenticated, anon
  using (bucket_id = 'pos-product-images');

create policy "pos_product_images_storage_insert"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'pos-product-images' and public.app_is_staff());

create policy "pos_product_images_storage_update"
  on storage.objects for update to authenticated
  using (bucket_id = 'pos-product-images' and public.app_is_staff())
  with check (bucket_id = 'pos-product-images' and public.app_is_staff());

create policy "pos_product_images_storage_delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'pos-product-images' and public.app_is_staff());
