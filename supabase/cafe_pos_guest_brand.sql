-- Guest QR menu branding / layout (safe to re-run).
-- Layouts: fresh | gallery (night removed).
-- Also refreshes get_guest_cafe_menu so the public /m menu receives brand fields.

alter table public.cafes
  add column if not exists guest_logo_path text not null default '';

alter table public.cafes
  add column if not exists guest_show_logo boolean not null default true;

alter table public.cafes
  add column if not exists guest_tagline text not null default '';

alter table public.cafes
  add column if not exists guest_accent_hex text not null default '';

alter table public.cafes
  add column if not exists guest_layout text not null default 'fresh';

alter table public.cafes
  add column if not exists guest_show_search boolean not null default false;

-- Migrate legacy night → fresh before tightening the check.
update public.cafes
set guest_layout = 'fresh'
where guest_layout is null
   or guest_layout = ''
   or guest_layout = 'night';

alter table public.cafes
  drop constraint if exists cafes_guest_layout_check;

alter table public.cafes
  add constraint cafes_guest_layout_check
  check (guest_layout in ('fresh', 'gallery'));

alter table public.cafes
  alter column guest_layout set default 'fresh';

comment on column public.cafes.guest_logo_path is
  'Storage path in brand-logos for guest QR menu logo.';
comment on column public.cafes.guest_layout is
  'Guest menu layout: fresh | gallery.';
comment on column public.cafes.guest_accent_hex is
  'Optional #RRGGBB accent for guest menu; empty uses default.';

create or replace function public.get_guest_cafe_menu(p_cafe_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cafe public.cafes%rowtype;
  v_categories jsonb;
  v_items jsonb;
  v_logo text := '';
  v_tagline text := '';
  v_accent text := '';
  v_layout text := 'fresh';
  v_show_logo boolean := true;
  v_show_search boolean := false;
begin
  if p_cafe_id is null or length(trim(p_cafe_id)) = 0 then
    raise exception 'Cafe id required';
  end if;

  select * into v_cafe
  from public.cafes
  where id = trim(p_cafe_id)
    and is_active is true;

  if not found then
    raise exception 'Cafe not found or inactive';
  end if;

  begin
    v_logo := coalesce(v_cafe.guest_logo_path, '');
    v_tagline := coalesce(v_cafe.guest_tagline, '');
    v_accent := coalesce(v_cafe.guest_accent_hex, '');
    v_layout := coalesce(nullif(v_cafe.guest_layout, ''), 'fresh');
    if v_layout = 'night' then
      v_layout := 'fresh';
    end if;
    v_show_logo := coalesce(v_cafe.guest_show_logo, true);
    v_show_search := coalesce(v_cafe.guest_show_search, false);
  exception
    when undefined_column then
      v_logo := '';
      v_tagline := '';
      v_accent := '';
      v_layout := 'fresh';
      v_show_logo := true;
      v_show_search := false;
  end;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'sort_order', c.sort_order
    )
    order by c.sort_order, c.name
  ), '[]'::jsonb)
  into v_categories
  from public.cafe_categories c
  where c.cafe_id = v_cafe.id
    and c.is_active is true;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'category_id', m.category_id,
      'name', m.name,
      'price', m.price,
      'tax_rate', m.tax_rate,
      'sort_order', m.sort_order,
      'category_name', coalesce(cat.name, '')
    )
    order by m.sort_order, m.name
  ), '[]'::jsonb)
  into v_items
  from public.cafe_menu_items m
  left join public.cafe_categories cat on cat.id = m.category_id
  where m.cafe_id = v_cafe.id
    and m.is_active is true
    and m.is_available is true;

  return jsonb_build_object(
    'cafe', jsonb_build_object(
      'id', v_cafe.id,
      'name', v_cafe.name,
      'guest_logo_path', v_logo,
      'guest_show_logo', v_show_logo,
      'guest_tagline', v_tagline,
      'guest_accent_hex', v_accent,
      'guest_layout', v_layout,
      'guest_show_search', v_show_search
    ),
    'categories', v_categories,
    'items', v_items
  );
end;
$$;

revoke all on function public.get_guest_cafe_menu(text) from public;
grant execute on function public.get_guest_cafe_menu(text) to anon, authenticated;

comment on function public.get_guest_cafe_menu(text) is
  'Public QR menu: cafe brand/layout + categories + available items.';
