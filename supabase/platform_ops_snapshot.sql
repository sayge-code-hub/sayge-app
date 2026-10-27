-- Platform owner snapshot — users, companies, plans.
-- Secret logo double-tap console. Re-run safe.

create or replace function public.platform_ops_snapshot(p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_users_active int := 0;
  v_users_total int := 0;
  v_new_today int := 0;
  v_companies_total int := 0;
  v_plans jsonb := '[]'::jsonb;
  v_users jsonb := '[]'::jsonb;
  v_companies jsonb := '[]'::jsonb;
  v_live_plan_code text := null;
  v_live_plan_name text := null;
  v_live_status text := null;
  v_pos_enabled boolean := null;
  v_solo_company_id uuid := null;
begin
  if coalesce(p_password, '') is distinct from 'ihateluvstories' then
    raise exception 'PLATFORM_OPS_FORBIDDEN' using errcode = '42501';
  end if;

  select
    count(*)::int,
    count(*) filter (where is_active is true)::int,
    count(*) filter (where created_at::date = current_date)::int
  into v_users_total, v_users_active, v_new_today
  from public.users;

  if to_regclass('public.company_details') is not null then
    select count(*)::int into v_companies_total from public.company_details;
    if v_companies_total = 1 then
      select id into v_solo_company_id from public.company_details limit 1;
    end if;
  end if;

  if to_regclass('public.billing_plans') is not null
     and to_regclass('public.billing_subscription') is not null then
    select s.plan_code, p.name, s.status, s.pos_enabled
    into v_live_plan_code, v_live_plan_name, v_live_status, v_pos_enabled
    from public.billing_subscription s
    left join public.billing_plans p on p.code = s.plan_code
    where s.id = 'deployment';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', u.id,
        'email', u.email,
        'full_name', u.full_name,
        'role', coalesce(r.label, r.code, ''),
        'role_code', coalesce(r.code, ''),
        'is_active', u.is_active,
        'created_at', u.created_at,
        -- Closed beta: attribute all logins to the solo company when present.
        'company', case
          when v_solo_company_id is not null then 'Sayge'
          else null
        end,
        'company_id', v_solo_company_id,
        'plan_code', v_live_plan_code
      )
      order by u.created_at desc
    ),
    '[]'::jsonb
  )
  into v_users
  from public.users u
  left join public.roles r on r.id = u.role_id;

  if to_regclass('public.company_details') is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'display_name', nullif(trim(c.display_name), ''),
          'email', c.email,
          'telephone', c.telephone,
          'gstin', c.gstin,
          'created_at', c.created_at,
          -- Closed beta: every company rides the singleton live plan.
          'plan_code', v_live_plan_code,
          'plan_name', v_live_plan_name,
          'users_count', case
            when v_companies_total = 1 then v_users_total
            else 0
          end
        )
        order by c.created_at asc
      ),
      '[]'::jsonb
    )
    into v_companies
    from public.company_details c;
  end if;

  if to_regclass('public.billing_plans') is not null
     and to_regclass('public.billing_subscription') is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'plan_code', p.code,
          'plan_name', p.name,
          'price_inr', p.price_inr,
          'employee_limit', p.employee_limit,
          'sort_order', p.sort_order,
          'is_active', p.is_active,
          'is_live', p.code = v_live_plan_code,
          'subscriptions', coalesce(s.cnt, 0),
          'companies_count', case
            when p.code = v_live_plan_code then v_companies_total
            else 0
          end,
          'users_count', case
            when p.code = v_live_plan_code then v_users_total
            else 0
          end
        )
        order by p.sort_order, p.code
      ),
      '[]'::jsonb
    )
    into v_plans
    from public.billing_plans p
    left join (
      select plan_code, count(*)::int as cnt
      from public.billing_subscription
      group by plan_code
    ) s on s.plan_code = p.code;
  end if;

  return jsonb_build_object(
    'generated_at', now(),
    'users_active', v_users_active,
    'users_total', v_users_total,
    'users_joined_today', v_new_today,
    'companies_total', v_companies_total,
    'users', v_users,
    'companies', v_companies,
    'plans', v_plans,
    'live_plan_code', v_live_plan_code,
    'live_plan_name', v_live_plan_name,
    'live_status', v_live_status,
    'pos_enabled', v_pos_enabled
  );
end;
$$;

revoke all on function public.platform_ops_snapshot(text) from public;
grant execute on function public.platform_ops_snapshot(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Update catalog pricing / seat limits (password-gated).
-- ---------------------------------------------------------------------------

create or replace function public.platform_ops_update_plan(
  p_password text,
  p_code text,
  p_name text,
  p_price_inr numeric,
  p_employee_limit int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_live text;
begin
  if coalesce(p_password, '') is distinct from 'ihateluvstories' then
    raise exception 'PLATFORM_OPS_FORBIDDEN' using errcode = '42501';
  end if;
  if to_regclass('public.billing_plans') is null then
    raise exception 'BILLING_NOT_INSTALLED' using errcode = 'P0001';
  end if;
  if p_code is null or trim(p_code) = '' then
    raise exception 'PLAN_CODE_REQUIRED' using errcode = 'P0001';
  end if;
  if p_name is null or trim(p_name) = '' then
    raise exception 'PLAN_NAME_REQUIRED' using errcode = 'P0001';
  end if;
  if p_price_inr is null or p_price_inr < 0 then
    raise exception 'PLAN_PRICE_INVALID' using errcode = 'P0001';
  end if;
  if p_employee_limit is null or p_employee_limit <= 0 then
    raise exception 'PLAN_LIMIT_INVALID' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.billing_plans where code = p_code) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  update public.billing_plans
  set
    name = trim(p_name),
    price_inr = p_price_inr,
    employee_limit = p_employee_limit
  where code = p_code;

  if to_regclass('public.billing_subscription') is not null
     and to_regclass('public.billing_periods') is not null then
    select plan_code into v_live
    from public.billing_subscription
    where id = 'deployment';

    if v_live = p_code then
      update public.billing_periods bp
      set list_price_inr = p_price_inr,
          amount_due_inr = public.billing_effective_amount_due(
            p_code,
            p_price_inr,
            s.offer_id,
            s.offer_price_inr,
            s.offer_ends_at
          )
      from public.billing_subscription s
      where bp.period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
        and s.id = 'deployment'
        and bp.payment_status = 'unpaid';

      update public.billing_periods
      set payment_status = 'comped',
          paid_at = now(),
          note = case
            when note = '' then 'Auto-settled after plan price change (₹0)'
            else note
          end
      where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
        and amount_due_inr <= 0
        and payment_status = 'unpaid';
    end if;
  end if;

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload)
    values (
      'platform_ops_plan_updated',
      jsonb_build_object(
        'code', p_code,
        'name', trim(p_name),
        'price_inr', p_price_inr,
        'employee_limit', p_employee_limit
      )
    );
  end if;

  return public.platform_ops_snapshot(p_password);
end;
$$;

revoke all on function public.platform_ops_update_plan(text, text, text, numeric, int) from public;
grant execute on function public.platform_ops_update_plan(text, text, text, numeric, int)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Activate / deactivate a catalog plan (cannot deactivate the live plan).
-- ---------------------------------------------------------------------------

create or replace function public.platform_ops_set_plan_active(
  p_password text,
  p_code text,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_live text;
begin
  if coalesce(p_password, '') is distinct from 'ihateluvstories' then
    raise exception 'PLATFORM_OPS_FORBIDDEN' using errcode = '42501';
  end if;
  if to_regclass('public.billing_plans') is null then
    raise exception 'BILLING_NOT_INSTALLED' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.billing_plans where code = p_code) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  if p_is_active is false
     and to_regclass('public.billing_subscription') is not null then
    select plan_code into v_live
    from public.billing_subscription
    where id = 'deployment';
    if v_live = p_code then
      raise exception 'CANNOT_DEACTIVATE_LIVE_PLAN' using errcode = 'P0001';
    end if;
  end if;

  update public.billing_plans
  set is_active = coalesce(p_is_active, false)
  where code = p_code;

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload)
    values (
      'platform_ops_plan_active_changed',
      jsonb_build_object('code', p_code, 'is_active', coalesce(p_is_active, false))
    );
  end if;

  return public.platform_ops_snapshot(p_password);
end;
$$;

revoke all on function public.platform_ops_set_plan_active(text, text, boolean) from public;
grant execute on function public.platform_ops_set_plan_active(text, text, boolean)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Switch the singleton deployment onto a different catalog plan.
-- ---------------------------------------------------------------------------

create or replace function public.platform_ops_set_live_plan(
  p_password text,
  p_plan_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old text;
begin
  if coalesce(p_password, '') is distinct from 'ihateluvstories' then
    raise exception 'PLATFORM_OPS_FORBIDDEN' using errcode = '42501';
  end if;
  if to_regclass('public.billing_plans') is null
     or to_regclass('public.billing_subscription') is null then
    raise exception 'BILLING_NOT_INSTALLED' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.billing_plans where code = p_plan_code) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  -- Making a plan live always activates it in the catalog.
  update public.billing_plans
  set is_active = true
  where code = p_plan_code;

  select plan_code into v_old
  from public.billing_subscription
  where id = 'deployment';

  update public.billing_subscription
  set plan_code = p_plan_code,
      updated_at = now()
  where id = 'deployment';

  if to_regclass('public.billing_periods') is not null then
    update public.billing_periods bp
    set plan_code = p_plan_code,
        list_price_inr = p.price_inr,
        amount_due_inr = public.billing_effective_amount_due(
          p_plan_code,
          p.price_inr,
          s.offer_id,
          s.offer_price_inr,
          s.offer_ends_at
        )
    from public.billing_plans p, public.billing_subscription s
    where bp.period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
      and p.code = p_plan_code
      and s.id = 'deployment'
      and bp.payment_status = 'unpaid';

    update public.billing_periods
    set payment_status = 'comped',
        paid_at = now(),
        note = case
          when note = '' then 'Auto-settled after plan change (₹0)'
          else note
        end
    where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
      and amount_due_inr <= 0
      and payment_status = 'unpaid';
  end if;

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload)
    values (
      'platform_ops_live_plan_changed',
      jsonb_build_object('from', v_old, 'to', p_plan_code)
    );
  end if;

  return public.platform_ops_snapshot(p_password);
end;
$$;

revoke all on function public.platform_ops_set_live_plan(text, text) from public;
grant execute on function public.platform_ops_set_live_plan(text, text)
  to anon, authenticated;
