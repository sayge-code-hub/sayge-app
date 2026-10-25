-- Guest / QR menu: public read + place order (safe to re-run).
-- Prefer SECURITY DEFINER RPCs so anon needs no table grants.

-- ---------------------------------------------------------------------------
-- Public menu payload for /m/:cafeId
-- ---------------------------------------------------------------------------
-- Brand columns + layout live in cafe_pos_guest_brand.sql.
-- This RPC always returns brand keys (defaults when columns are missing).
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

-- ---------------------------------------------------------------------------
-- Guest places an order from their phone (pending payment, kitchen ticket).
-- p_items: [{ "menu_item_id": "...", "quantity": 1, "notes": "" }, ...]
-- ---------------------------------------------------------------------------
create or replace function public.create_guest_cafe_order(
  p_cafe_id text,
  p_items jsonb,
  p_table_no text default '',
  p_order_type text default 'dine_in'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cafe public.cafes%rowtype;
  v_order_type text;
  v_table_no text;
  v_prefix text;
  v_count int;
  v_attempt int;
  v_order_no text;
  v_order_id text;
  v_subtotal numeric(12, 2) := 0;
  v_tax numeric(12, 2) := 0;
  v_total numeric(12, 2) := 0;
  v_elem jsonb;
  v_item public.cafe_menu_items%rowtype;
  v_qty numeric(12, 2);
  v_notes text;
  v_line_total numeric(12, 2);
  v_line_tax numeric(12, 2);
  v_sort int := 0;
  v_item_id text;
  v_rows jsonb := '[]'::jsonb;
begin
  if p_cafe_id is null or length(trim(p_cafe_id)) = 0 then
    raise exception 'Cafe id required';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one item';
  end if;

  select * into v_cafe
  from public.cafes
  where id = trim(p_cafe_id)
    and is_active is true;
  if not found then
    raise exception 'Cafe not found or inactive';
  end if;

  v_order_type := lower(trim(coalesce(p_order_type, 'dine_in')));
  if v_order_type not in ('dine_in', 'takeaway') then
    v_order_type := 'dine_in';
  end if;

  v_table_no := trim(coalesce(p_table_no, ''));
  if v_order_type = 'takeaway' then
    v_table_no := '';
  end if;

  -- Snapshot lines from live menu (ignore client prices).
  for v_elem in select * from jsonb_array_elements(p_items)
  loop
    v_item_id := trim(coalesce(v_elem->>'menu_item_id', ''));
    v_qty := coalesce((v_elem->>'quantity')::numeric, 0);
    v_notes := left(trim(coalesce(v_elem->>'notes', '')), 200);
    if v_item_id = '' or v_qty <= 0 then
      continue;
    end if;

    select * into v_item
    from public.cafe_menu_items
    where id = v_item_id
      and cafe_id = v_cafe.id
      and is_active is true
      and is_available is true;
    if not found then
      raise exception 'Item unavailable: %', v_item_id;
    end if;

    v_line_total := round(v_item.price * v_qty, 2);
    v_line_tax := round(v_line_total * (coalesce(v_item.tax_rate, 0) / 100.0), 2);
    v_subtotal := v_subtotal + v_line_total;
    v_tax := v_tax + v_line_tax;
    v_sort := v_sort + 1;

    v_rows := v_rows || jsonb_build_array(
      jsonb_build_object(
        'id', 'coli_' || replace(gen_random_uuid()::text, '-', ''),
        'menu_item_id', v_item.id,
        'item_name', v_item.name,
        'unit_price', v_item.price,
        'tax_rate', coalesce(v_item.tax_rate, 0),
        'quantity', v_qty,
        'line_total', v_line_total,
        'notes', v_notes,
        'sort_order', v_sort - 1
      )
    );
  end loop;

  if jsonb_array_length(v_rows) = 0 then
    raise exception 'Add at least one item';
  end if;

  v_total := round(v_subtotal + v_tax, 2);

  v_prefix := 'C' || to_char(now(), 'YYMMDD');
  -- Next seq from existing order_no for today (not row count — seed/backfill
  -- and clock skew can collide with count(*) + 1).
  select coalesce(
    max(
      nullif(
        regexp_replace(order_no, '^' || v_prefix || '-', ''),
        ''
      )::int
    ),
    0
  )::int
  into v_count
  from public.cafe_orders
  where cafe_id = v_cafe.id
    and order_no ~ ('^' || v_prefix || '-[0-9]+$');

  v_order_id := 'cord_' || replace(gen_random_uuid()::text, '-', '');

  -- Requires cafe_pos_tables.sql (table_no column).
  -- Retry a few times if another concurrent insert races the same seq.
  for v_attempt in 1..8 loop
    v_order_no := v_prefix || '-' || lpad((v_count + v_attempt)::text, 3, '0');
    begin
      insert into public.cafe_orders (
        id, cafe_id, order_no, order_type, prep_status, payment_status,
        subtotal, tax_amount, discount_amount, total_amount,
        created_by, table_no
      ) values (
        v_order_id, v_cafe.id, v_order_no, v_order_type, 'new', 'pending',
        v_subtotal, v_tax, 0, v_total,
        null, v_table_no
      );
      exit;
    exception
      when unique_violation then
        if v_attempt = 8 then
          raise;
        end if;
    end;
  end loop;

  insert into public.cafe_order_items (
    id, order_id, menu_item_id, item_name, unit_price, tax_rate,
    quantity, line_total, notes, sort_order
  )
  select
    r->>'id',
    v_order_id,
    r->>'menu_item_id',
    r->>'item_name',
    (r->>'unit_price')::numeric,
    (r->>'tax_rate')::numeric,
    (r->>'quantity')::numeric,
    (r->>'line_total')::numeric,
    coalesce(r->>'notes', ''),
    (r->>'sort_order')::int
  from jsonb_array_elements(v_rows) as r;

  return jsonb_build_object(
    'id', v_order_id,
    'order_no', v_order_no,
    'cafe_id', v_cafe.id,
    'cafe_name', v_cafe.name,
    'order_type', v_order_type,
    'table_no', v_table_no,
    'subtotal', v_subtotal,
    'tax_amount', v_tax,
    'total_amount', v_total,
    'item_count', jsonb_array_length(v_rows)
  );
end;
$$;

revoke all on function public.create_guest_cafe_order(text, jsonb, text, text) from public;
grant execute on function public.create_guest_cafe_order(text, jsonb, text, text) to anon, authenticated;

comment on function public.create_guest_cafe_order(text, jsonb, text, text) is
  'QR guest order: validates menu prices, creates pending kitchen ticket.';
