-- Closed-beta subscription (SINGLE DEPLOYMENT — not multi-tenant).
-- Safe to re-run. Additive only; does not drop business tables.
--
-- Apply AFTER security_hardening.sql (needs public.app_is_staff()).
-- Does NOT revoke guest Cafe POS RPC grants.
--
-- Plans: free (5) / starter (10) / growth (30). Cafe POS = pos_enabled flag only.

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------

create table if not exists public.billing_plans (
  code text primary key,
  name text not null,
  price_inr numeric(12, 2) not null check (price_inr >= 0),
  employee_limit int not null check (employee_limit > 0),
  sort_order int not null default 0,
  is_active boolean not null default true
);

insert into public.billing_plans (code, name, price_inr, employee_limit, sort_order)
values
  ('free', 'Free', 0, 5, 10),
  ('starter', 'Starter', 499, 10, 20),
  ('growth', 'Growth', 999, 30, 30)
on conflict (code) do update set
  name = excluded.name,
  price_inr = excluded.price_inr,
  employee_limit = excluded.employee_limit,
  sort_order = excluded.sort_order,
  is_active = true;

-- ---------------------------------------------------------------------------
-- Offers (optional promos)
-- ---------------------------------------------------------------------------

create table if not exists public.billing_offers (
  id text primary key,
  code text not null unique,
  name text not null default '',
  applies_to_plan text references public.billing_plans (code) on delete set null,
  percent_off numeric(5, 2) check (percent_off is null or (percent_off > 0 and percent_off <= 100)),
  fixed_price_inr numeric(12, 2) check (fixed_price_inr is null or fixed_price_inr >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint billing_offers_discount_chk check (
    (percent_off is not null and fixed_price_inr is null)
    or (percent_off is null and fixed_price_inr is not null)
  )
);

-- ---------------------------------------------------------------------------
-- Singleton subscription
-- ---------------------------------------------------------------------------

create table if not exists public.billing_subscription (
  id text primary key default 'deployment' check (id = 'deployment'),
  plan_code text not null references public.billing_plans (code),
  -- Cached derived status; refreshed by billing_refresh_status().
  status text not null default 'active'
    check (status in ('trialing', 'active', 'past_due', 'read_only')),
  pos_enabled boolean not null default true,
  grace_days int not null default 7 check (grace_days >= 0 and grace_days <= 90),
  current_period_start date not null default (date_trunc('month', now())::date),
  current_period_end date not null default (
    (date_trunc('month', now()) + interval '1 month - 1 day')::date
  ),
  offer_id text references public.billing_offers (id) on delete set null,
  offer_price_inr numeric(12, 2),
  offer_ends_at timestamptz,
  manual_notes text not null default '',
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Seed: Growth + POS on so Sayge closed-beta ops keep working.
insert into public.billing_subscription (
  id, plan_code, status, pos_enabled, grace_days
)
values ('deployment', 'growth', 'active', true, 7)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Monthly periods
-- ---------------------------------------------------------------------------

create table if not exists public.billing_periods (
  id text primary key,
  period_ym text not null unique, -- YYYY-MM
  period_start date not null,
  period_end date not null,
  plan_code text not null references public.billing_plans (code),
  list_price_inr numeric(12, 2) not null,
  amount_due_inr numeric(12, 2) not null,
  amount_paid_inr numeric(12, 2) not null default 0,
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid', 'paid', 'waived', 'comped')),
  paid_at timestamptz,
  marked_by uuid references auth.users (id) on delete set null,
  note text not null default '',
  offer_id text references public.billing_offers (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists billing_periods_ym_idx
  on public.billing_periods (period_ym desc);

-- ---------------------------------------------------------------------------
-- Audit
-- ---------------------------------------------------------------------------

create table if not exists public.billing_events (
  id bigserial primary key,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  actor_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists billing_events_created_idx
  on public.billing_events (created_at desc);

do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    drop trigger if exists billing_subscription_set_updated_at
      on public.billing_subscription;
    create trigger billing_subscription_set_updated_at
      before update on public.billing_subscription
      for each row execute function public.set_updated_at();

    drop trigger if exists billing_periods_set_updated_at
      on public.billing_periods;
    create trigger billing_periods_set_updated_at
      before update on public.billing_periods
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.billing_log_event(
  p_type text,
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.billing_events (event_type, payload, actor_id)
  values (p_type, coalesce(p_payload, '{}'::jsonb), auth.uid());
end;
$$;

create or replace function public.billing_active_employee_count()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.employees
  where is_active is true
    and coalesce(is_draft, false) is false;
$$;

create or replace function public.billing_plan_limit()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select p.employee_limit
  from public.billing_subscription s
  join public.billing_plans p on p.code = s.plan_code
  where s.id = 'deployment';
$$;

create or replace function public.billing_can_consume_seat()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.billing_active_employee_count() < public.billing_plan_limit();
$$;

create or replace function public.billing_period_is_settled(p_status text)
returns boolean
language sql
immutable
as $$
  select p_status in ('paid', 'waived', 'comped');
$$;

create or replace function public.billing_effective_amount_due(
  p_plan_code text,
  p_list_price numeric,
  p_offer_id text,
  p_offer_price numeric,
  p_offer_ends_at timestamptz
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_offer public.billing_offers%rowtype;
  v_price numeric;
begin
  if p_offer_id is not null
     and (p_offer_ends_at is null or p_offer_ends_at > now())
     and p_offer_price is not null then
    return greatest(p_offer_price, 0);
  end if;

  if p_offer_id is not null then
    select * into v_offer from public.billing_offers where id = p_offer_id;
    if found
       and v_offer.is_active
       and (v_offer.applies_to_plan is null or v_offer.applies_to_plan = p_plan_code)
       and (v_offer.starts_at is null or v_offer.starts_at <= now())
       and (v_offer.ends_at is null or v_offer.ends_at > now()) then
      if v_offer.fixed_price_inr is not null then
        return greatest(v_offer.fixed_price_inr, 0);
      end if;
      if v_offer.percent_off is not null then
        v_price := round(p_list_price * (1 - v_offer.percent_off / 100.0), 2);
        return greatest(v_price, 0);
      end if;
    end if;
  end if;

  return greatest(p_list_price, 0);
end;
$$;

create or replace function public.billing_ensure_current_period()
returns public.billing_periods
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_ym text;
  v_start date;
  v_end date;
  v_period public.billing_periods%rowtype;
  v_due numeric;
  v_status text;
begin
  select * into v_sub from public.billing_subscription where id = 'deployment';
  if not found then
    raise exception 'BILLING_NO_SUBSCRIPTION';
  end if;

  select * into v_plan from public.billing_plans where code = v_sub.plan_code;

  v_start := date_trunc('month', now())::date;
  v_end := (date_trunc('month', now()) + interval '1 month - 1 day')::date;
  v_ym := to_char(v_start, 'YYYY-MM');

  select * into v_period from public.billing_periods where period_ym = v_ym;
  if found then
    -- Keep subscription period pointers in sync.
    update public.billing_subscription
    set current_period_start = v_start,
        current_period_end = v_end
    where id = 'deployment'
      and (current_period_start is distinct from v_start
           or current_period_end is distinct from v_end);
    return v_period;
  end if;

  v_due := public.billing_effective_amount_due(
    v_sub.plan_code,
    v_plan.price_inr,
    v_sub.offer_id,
    v_sub.offer_price_inr,
    v_sub.offer_ends_at
  );

  -- Free plan (₹0) or zero due → auto-settle.
  if v_due <= 0 then
    v_status := 'comped';
  else
    v_status := 'unpaid';
  end if;

  insert into public.billing_periods (
    id, period_ym, period_start, period_end, plan_code,
    list_price_inr, amount_due_inr, amount_paid_inr, payment_status,
    paid_at, note, offer_id
  ) values (
    'bp_' || v_ym,
    v_ym,
    v_start,
    v_end,
    v_sub.plan_code,
    v_plan.price_inr,
    v_due,
    case when v_status = 'comped' then 0 else 0 end,
    v_status,
    case when v_status = 'comped' then now() else null end,
    case when v_status = 'comped' then 'Auto-settled (₹0 due)' else '' end,
    v_sub.offer_id
  )
  returning * into v_period;

  update public.billing_subscription
  set current_period_start = v_start,
      current_period_end = v_end
  where id = 'deployment';

  perform public.billing_log_event(
    'period_created',
    jsonb_build_object('period_ym', v_ym, 'amount_due_inr', v_due, 'payment_status', v_status)
  );

  return v_period;
end;
$$;

create or replace function public.billing_derive_status()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sub public.billing_subscription%rowtype;
  v_period public.billing_periods%rowtype;
  v_grace_end timestamptz;
begin
  select * into v_sub from public.billing_subscription where id = 'deployment';
  if not found then
    return 'read_only';
  end if;

  -- Ensure we reason about the current calendar month.
  -- (stable fn cannot write; callers should ensure_current_period first)

  select * into v_period
  from public.billing_periods
  where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM');

  if not found then
    -- No period row yet — treat as active until ensure creates one.
    return 'active';
  end if;

  if public.billing_period_is_settled(v_period.payment_status) then
    return 'active';
  end if;

  v_grace_end := (v_period.period_end::timestamptz + interval '1 day')
                 + make_interval(days => v_sub.grace_days);

  if now() <= v_grace_end then
    return 'past_due';
  end if;

  return 'read_only';
end;
$$;

create or replace function public.billing_refresh_status()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  perform public.billing_ensure_current_period();
  v_status := public.billing_derive_status();
  update public.billing_subscription
  set status = v_status
  where id = 'deployment'
    and status is distinct from v_status;
  return v_status;
end;
$$;

create or replace function public.billing_writes_allowed()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  v_status := public.billing_derive_status();
  return v_status in ('trialing', 'active', 'past_due');
end;
$$;

-- Seat-increase guard on employees
create or replace function public.billing_employees_seat_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_seat boolean;
  v_new_seat boolean;
  v_limit int;
  v_count int;
  v_plan text;
begin
  if tg_op = 'INSERT' then
    v_old_seat := false;
    v_new_seat := (new.is_active is true and coalesce(new.is_draft, false) is false);
  elsif tg_op = 'UPDATE' then
    v_old_seat := (old.is_active is true and coalesce(old.is_draft, false) is false);
    v_new_seat := (new.is_active is true and coalesce(new.is_draft, false) is false);
  else
    return new;
  end if;

  -- Only block when this change would add a seat.
  if v_new_seat and not v_old_seat then
    v_limit := public.billing_plan_limit();
    v_count := public.billing_active_employee_count();
    -- On UPDATE of an existing seat-holder we already counted them; on INSERT not yet.
    if tg_op = 'UPDATE' and v_old_seat then
      null; -- unreachable due to condition
    end if;
    if v_count >= v_limit then
      select plan_code into v_plan from public.billing_subscription where id = 'deployment';
      raise exception 'BILLING_SEAT_LIMIT plan=% limit=% count=%',
        coalesce(v_plan, '?'), v_limit, v_count
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists billing_employees_seat_guard on public.employees;
create trigger billing_employees_seat_guard
  before insert or update on public.employees
  for each row execute function public.billing_employees_seat_guard();

-- ---------------------------------------------------------------------------
-- Staff RPCs
-- ---------------------------------------------------------------------------

create or replace function public.billing_get_state()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_period public.billing_periods%rowtype;
  v_status text;
  v_count int;
  v_offer public.billing_offers%rowtype;
  v_plans jsonb;
  v_periods jsonb;
  v_offers jsonb;
  v_grace_end timestamptz;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  perform public.billing_ensure_current_period();
  v_status := public.billing_refresh_status();

  select * into v_sub from public.billing_subscription where id = 'deployment';
  select * into v_plan from public.billing_plans where code = v_sub.plan_code;
  select * into v_period
  from public.billing_periods
  where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM');

  v_count := public.billing_active_employee_count();

  if v_sub.offer_id is not null then
    select * into v_offer from public.billing_offers where id = v_sub.offer_id;
  end if;

  v_grace_end := (v_period.period_end::timestamptz + interval '1 day')
                 + make_interval(days => v_sub.grace_days);

  select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb)
  into v_plans
  from public.billing_plans p
  where p.is_active;

  select coalesce(
    jsonb_agg(to_jsonb(bp) order by bp.period_ym desc),
    '[]'::jsonb
  )
  into v_periods
  from (
    select * from public.billing_periods order by period_ym desc limit 12
  ) bp;

  select coalesce(jsonb_agg(to_jsonb(o) order by o.created_at desc), '[]'::jsonb)
  into v_offers
  from public.billing_offers o
  where o.is_active;

  return jsonb_build_object(
    'subscription', to_jsonb(v_sub) || jsonb_build_object('status', v_status),
    'plan', to_jsonb(v_plan),
    'current_period', to_jsonb(v_period),
    'active_employees', v_count,
    'employee_limit', v_plan.employee_limit,
    'writes_allowed', v_status in ('trialing', 'active', 'past_due'),
    'can_add_employee', v_count < v_plan.employee_limit
      and v_status in ('trialing', 'active', 'past_due'),
    'grace_ends_at', v_grace_end,
    'offer', case when v_offer.id is null then null else to_jsonb(v_offer) end,
    'plans', v_plans,
    'periods', v_periods,
    'offers', v_offers
  );
end;
$$;

create or replace function public.billing_set_plan(p_plan_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old text;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;
  if not exists (select 1 from public.billing_plans where code = p_plan_code and is_active) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  select plan_code into v_old from public.billing_subscription where id = 'deployment';

  update public.billing_subscription
  set plan_code = p_plan_code
  where id = 'deployment';

  -- Refresh current period amounts to new plan list price / offer.
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

  -- If new due is 0, auto-comp.
  update public.billing_periods
  set payment_status = 'comped',
      paid_at = now(),
      note = case when note = '' then 'Auto-settled after plan change (₹0)' else note end
  where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and amount_due_inr <= 0
    and payment_status = 'unpaid';

  perform public.billing_log_event(
    'plan_changed',
    jsonb_build_object('from', v_old, 'to', p_plan_code)
  );

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_mark_period(
  p_period_id text,
  p_status text,
  p_note text default null,
  p_amount_paid numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;
  if p_status not in ('unpaid', 'paid', 'waived', 'comped') then
    raise exception 'BILLING_BAD_STATUS' using errcode = 'P0001';
  end if;

  update public.billing_periods
  set payment_status = p_status,
      amount_paid_inr = case
        when p_status = 'paid' then coalesce(p_amount_paid, amount_due_inr)
        else coalesce(p_amount_paid, amount_paid_inr)
      end,
      paid_at = case
        when p_status in ('paid', 'waived', 'comped') then now()
        else null
      end,
      marked_by = auth.uid(),
      note = coalesce(nullif(trim(p_note), ''), note)
  where id = p_period_id;

  if not found then
    raise exception 'BILLING_PERIOD_NOT_FOUND' using errcode = 'P0001';
  end if;

  perform public.billing_log_event(
    'period_marked',
    jsonb_build_object(
      'period_id', p_period_id,
      'payment_status', p_status,
      'note', coalesce(p_note, '')
    )
  );

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_apply_offer(
  p_offer_id text,
  p_offer_price_inr numeric default null,
  p_offer_ends_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.billing_offers%rowtype;
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_price numeric;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  select * into v_offer from public.billing_offers where id = p_offer_id and is_active;
  if not found then
    raise exception 'BILLING_OFFER_NOT_FOUND' using errcode = 'P0001';
  end if;

  select * into v_sub from public.billing_subscription where id = 'deployment';
  select * into v_plan from public.billing_plans where code = v_sub.plan_code;

  if v_offer.applies_to_plan is not null and v_offer.applies_to_plan <> v_sub.plan_code then
    raise exception 'BILLING_OFFER_PLAN_MISMATCH' using errcode = 'P0001';
  end if;

  v_price := coalesce(
    p_offer_price_inr,
    public.billing_effective_amount_due(
      v_sub.plan_code,
      v_plan.price_inr,
      v_offer.id,
      null,
      null
    )
  );

  -- Recompute from offer definition when price not forced.
  if p_offer_price_inr is null then
    if v_offer.fixed_price_inr is not null then
      v_price := v_offer.fixed_price_inr;
    elsif v_offer.percent_off is not null then
      v_price := round(v_plan.price_inr * (1 - v_offer.percent_off / 100.0), 2);
    end if;
  end if;

  update public.billing_subscription
  set offer_id = v_offer.id,
      offer_price_inr = v_price,
      offer_ends_at = coalesce(p_offer_ends_at, v_offer.ends_at)
  where id = 'deployment';

  update public.billing_periods
  set amount_due_inr = v_price,
      offer_id = v_offer.id
  where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and payment_status = 'unpaid';

  perform public.billing_log_event(
    'offer_applied',
    jsonb_build_object('offer_id', v_offer.id, 'offer_price_inr', v_price)
  );

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_clear_offer()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  select * into v_sub from public.billing_subscription where id = 'deployment';
  select * into v_plan from public.billing_plans where code = v_sub.plan_code;

  update public.billing_subscription
  set offer_id = null,
      offer_price_inr = null,
      offer_ends_at = null
  where id = 'deployment';

  update public.billing_periods
  set amount_due_inr = v_plan.price_inr,
      offer_id = null
  where period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and payment_status = 'unpaid';

  perform public.billing_log_event('offer_cleared', '{}'::jsonb);

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_set_grace_days(p_days int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;
  if p_days < 0 or p_days > 90 then
    raise exception 'BILLING_BAD_GRACE' using errcode = 'P0001';
  end if;

  update public.billing_subscription
  set grace_days = p_days
  where id = 'deployment';

  perform public.billing_log_event(
    'grace_days_set',
    jsonb_build_object('grace_days', p_days)
  );

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_set_pos_enabled(p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  update public.billing_subscription
  set pos_enabled = coalesce(p_enabled, true)
  where id = 'deployment';

  perform public.billing_log_event(
    'pos_enabled_set',
    jsonb_build_object('pos_enabled', coalesce(p_enabled, true))
  );

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_upsert_offer(
  p_id text,
  p_code text,
  p_name text,
  p_applies_to_plan text,
  p_percent_off numeric,
  p_fixed_price_inr numeric,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id text;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  v_id := nullif(trim(p_id), '');
  if v_id is null then
    v_id := 'boff_' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
  end if;

  insert into public.billing_offers (
    id, code, name, applies_to_plan, percent_off, fixed_price_inr,
    starts_at, ends_at, is_active
  ) values (
    v_id,
    upper(trim(p_code)),
    coalesce(nullif(trim(p_name), ''), upper(trim(p_code))),
    nullif(trim(p_applies_to_plan), ''),
    p_percent_off,
    p_fixed_price_inr,
    p_starts_at,
    p_ends_at,
    coalesce(p_is_active, true)
  )
  on conflict (id) do update set
    code = excluded.code,
    name = excluded.name,
    applies_to_plan = excluded.applies_to_plan,
    percent_off = excluded.percent_off,
    fixed_price_inr = excluded.fixed_price_inr,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    is_active = excluded.is_active;

  perform public.billing_log_event(
    'offer_upserted',
    jsonb_build_object('offer_id', v_id, 'code', upper(trim(p_code)))
  );

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_set_notes(p_notes text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  update public.billing_subscription
  set manual_notes = coalesce(p_notes, '')
  where id = 'deployment';

  return public.billing_get_state();
end;
$$;

-- Public read helpers for any authenticated user (gates / banners).
create or replace function public.billing_public_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_status text;
  v_count int;
begin
  if auth.uid() is null then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  select * into v_sub from public.billing_subscription where id = 'deployment';
  if not found then
    return jsonb_build_object(
      'status', 'active',
      'writes_allowed', true,
      'pos_enabled', true,
      'can_add_employee', true,
      'active_employees', 0,
      'employee_limit', 30,
      'plan_code', 'growth',
      'plan_name', 'Growth'
    );
  end if;

  select * into v_plan from public.billing_plans where code = v_sub.plan_code;
  v_status := public.billing_derive_status();
  v_count := public.billing_active_employee_count();

  return jsonb_build_object(
    'status', v_status,
    'writes_allowed', v_status in ('trialing', 'active', 'past_due'),
    'pos_enabled', v_sub.pos_enabled,
    'can_add_employee',
      v_count < v_plan.employee_limit
      and v_status in ('trialing', 'active', 'past_due'),
    'active_employees', v_count,
    'employee_limit', v_plan.employee_limit,
    'plan_code', v_plan.code,
    'plan_name', v_plan.name,
    'grace_days', v_sub.grace_days,
    'current_period_end', v_sub.current_period_end
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.billing_plans enable row level security;
alter table public.billing_subscription enable row level security;
alter table public.billing_periods enable row level security;
alter table public.billing_offers enable row level security;
alter table public.billing_events enable row level security;

revoke all on table public.billing_plans from anon, public;
revoke all on table public.billing_subscription from anon, public;
revoke all on table public.billing_periods from anon, public;
revoke all on table public.billing_offers from anon, public;
revoke all on table public.billing_events from anon, public;

grant select on table public.billing_plans to authenticated;
grant select on table public.billing_subscription to authenticated;
grant select on table public.billing_periods to authenticated;
grant select on table public.billing_offers to authenticated;
-- events: staff via RPC only
grant select on table public.billing_events to authenticated;

drop policy if exists billing_plans_select on public.billing_plans;
create policy billing_plans_select on public.billing_plans
  for select to authenticated using (true);

drop policy if exists billing_subscription_select on public.billing_subscription;
create policy billing_subscription_select on public.billing_subscription
  for select to authenticated using (true);

drop policy if exists billing_periods_select on public.billing_periods;
create policy billing_periods_select on public.billing_periods
  for select to authenticated
  using (public.app_is_staff());

drop policy if exists billing_offers_select on public.billing_offers;
create policy billing_offers_select on public.billing_offers
  for select to authenticated
  using (public.app_is_staff());

drop policy if exists billing_events_select on public.billing_events;
create policy billing_events_select on public.billing_events
  for select to authenticated
  using (public.app_is_staff());

-- Mutations only via security definer RPCs (no direct insert/update policies).

grant execute on function public.billing_active_employee_count() to authenticated;
grant execute on function public.billing_plan_limit() to authenticated;
grant execute on function public.billing_can_consume_seat() to authenticated;
grant execute on function public.billing_writes_allowed() to authenticated;
grant execute on function public.billing_derive_status() to authenticated;
grant execute on function public.billing_public_snapshot() to authenticated;
grant execute on function public.billing_get_state() to authenticated;
grant execute on function public.billing_set_plan(text) to authenticated;
grant execute on function public.billing_mark_period(text, text, text, numeric) to authenticated;
grant execute on function public.billing_apply_offer(text, numeric, timestamptz) to authenticated;
grant execute on function public.billing_clear_offer() to authenticated;
grant execute on function public.billing_set_grace_days(int) to authenticated;
grant execute on function public.billing_set_pos_enabled(boolean) to authenticated;
grant execute on function public.billing_upsert_offer(text, text, text, text, numeric, numeric, timestamptz, timestamptz, boolean) to authenticated;
grant execute on function public.billing_set_notes(text) to authenticated;
grant execute on function public.billing_ensure_current_period() to authenticated;
grant execute on function public.billing_refresh_status() to authenticated;

-- Seed current period for Growth (comped if somehow ₹0; else unpaid until marked).
do $$
declare
  r public.billing_periods;
begin
  r := public.billing_ensure_current_period();
  -- Closed beta: mark current period paid so ops are not immediately past_due.
  update public.billing_periods
  set payment_status = 'paid',
      amount_paid_inr = amount_due_inr,
      paid_at = now(),
      note = case
        when note = '' then 'Seeded paid for closed beta'
        else note
      end
  where id = r.id
    and payment_status = 'unpaid';
  perform public.billing_refresh_status();
end $$;
