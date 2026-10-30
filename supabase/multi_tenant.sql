-- Multi-tenant Saasify (shared DB + company_id).
-- Safe to re-run. Apply AFTER billing_closed_beta.sql + security_hardening.sql.
--
-- Product identity:
--   Saasify = the product / platform (what you sell).
--   Sayge (`company_sayge`) = the first client company using Saasify — not the product.
--
-- Adds: company_members, users.company_id, domain company_id backfill,
-- per-company billing, platform ops create/invite, public Free signup (no payment gateway yet).

-- ---------------------------------------------------------------------------
-- Mark: Sayge is client #1
-- ---------------------------------------------------------------------------

comment on table public.company_details is
  'Saasify tenant (client company). Sayge (id=company_sayge) is the first client — not the product brand.';

do $$
begin
  if exists (
    select 1 from public.company_details where id = 'company_sayge'
  ) then
    execute $c$
      comment on column public.company_details.id is
        'Tenant id. company_sayge = first Saasify client (Sayge).'
    $c$;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.saasify_slugify(p_name text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
begin
  v := lower(trim(coalesce(p_name, '')));
  v := regexp_replace(v, '[^a-z0-9]+', '-', 'g');
  v := trim(both '-' from v);
  if v = '' then
    v := 'company';
  end if;
  return left(v, 48);
end;
$$;

-- ---------------------------------------------------------------------------
-- company_members + users.company_id
-- ---------------------------------------------------------------------------

create table if not exists public.company_members (
  company_id text not null references public.company_details (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (company_id, user_id)
);

create index if not exists company_members_user_idx
  on public.company_members (user_id);

alter table public.company_members enable row level security;

alter table public.users
  add column if not exists company_id text references public.company_details (id) on delete set null;

create index if not exists users_company_id_idx on public.users (company_id);

-- Backfill active company = Sayge for existing users.
update public.users
set company_id = 'company_sayge'
where company_id is null
  and exists (select 1 from public.company_details where id = 'company_sayge');

insert into public.company_members (company_id, user_id, role)
select
  'company_sayge',
  u.id,
  case
    when r.code in ('owner') then 'owner'
    when r.code in ('admin') then 'admin'
    else 'member'
  end
from public.users u
left join public.roles r on r.id = u.role_id
where exists (select 1 from public.company_details where id = 'company_sayge')
on conflict (company_id, user_id) do nothing;

create or replace function public.app_company_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select company_id from public.users where id = auth.uid()
$$;

create or replace function public.app_in_company(p_company_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_company_id is not null
    and exists (
      select 1
      from public.company_members m
      where m.user_id = auth.uid()
        and m.company_id = p_company_id
    );
$$;

create or replace function public.app_is_company_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_staff()
    and public.app_company_id() is not null;
$$;

grant execute on function public.app_company_id() to authenticated, anon, service_role;
grant execute on function public.app_in_company(text) to authenticated, anon, service_role;
grant execute on function public.app_is_company_staff() to authenticated, service_role;
grant execute on function public.saasify_slugify(text) to authenticated, anon, service_role;

drop policy if exists company_members_select on public.company_members;
create policy company_members_select on public.company_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.app_in_company(company_id)
  );

revoke all on table public.company_members from anon, public;
grant select on table public.company_members to authenticated;

-- ---------------------------------------------------------------------------
-- Domain tables: company_id + backfill to Sayge
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'employees',
    'clients',
    'cafes',
    'payroll_runs',
    'payslip_records',
    'employee_purchase_orders',
    'proposals',
    'invoices',
    'expenses',
    'expense_categories',
    'dms_entities',
    'documents'
  ]
  loop
    if to_regclass('public.' || t) is not null then
      execute format(
        'alter table public.%I add column if not exists company_id text references public.company_details (id) on delete cascade',
        t
      );
      execute format(
        'create index if not exists %I on public.%I (company_id)',
        t || '_company_id_idx',
        t
      );
      execute format(
        'update public.%I set company_id = %L where company_id is null',
        t,
        'company_sayge'
      );
    end if;
  end loop;

  -- Legacy POS commerce (optional)
  foreach t in array array[
    'pos_brands',
    'pos_products'
  ]
  loop
    if to_regclass('public.' || t) is not null then
      execute format(
        'alter table public.%I add column if not exists company_id text references public.company_details (id) on delete cascade',
        t
      );
      execute format(
        'update public.%I set company_id = %L where company_id is null',
        t,
        'company_sayge'
      );
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Auth provision: company_id + membership from invite / signup metadata
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  default_role_id text;
  preferred_name text;
  meta_role text;
  invited boolean;
  must_set boolean;
  email_lower text;
  meta_company text;
  meta_member_role text;
  signup_flag boolean;
begin
  email_lower := lower(coalesce(new.email, ''));

  if email_lower = '' or position('@' in email_lower) = 0 then
    return new;
  end if;

  invited := new.invited_at is not null;
  must_set := coalesce(new.raw_user_meta_data ->> 'must_set_password', '')
    in ('true', '1');
  signup_flag := coalesce(new.raw_user_meta_data ->> 'saasify_signup', '')
    in ('true', '1');

  -- Invite, password-setup invite, or public Saasify signup.
  if not invited and not must_set and not signup_flag then
    return new;
  end if;

  meta_role := nullif(trim(coalesce(new.raw_user_meta_data ->> 'role_id', '')), '');
  if meta_role is not null then
    select id into default_role_id
    from public.roles
    where id = meta_role and is_active
    limit 1;
  end if;

  if default_role_id is null
     and coalesce(new.raw_user_meta_data ->> 'role_code', '') <> '' then
    select id into default_role_id
    from public.roles
    where code = trim(new.raw_user_meta_data ->> 'role_code') and is_active
    order by sort_order
    limit 1;
  end if;

  if default_role_id is null and signup_flag then
    select id into default_role_id
    from public.roles
    where code = 'owner' and is_active
    order by sort_order
    limit 1;
  end if;

  if default_role_id is null then
    select id into default_role_id
    from public.roles
    where code = 'employee' and is_active
    order by sort_order
    limit 1;
  end if;

  if default_role_id is null then
    select id into default_role_id from public.roles order by sort_order limit 1;
  end if;

  preferred_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  meta_company := nullif(trim(coalesce(new.raw_user_meta_data ->> 'company_id', '')), '');
  if meta_company is null and not signup_flag then
    -- Legacy invites without company → Sayge (first client).
    meta_company := 'company_sayge';
  end if;

  meta_member_role := lower(coalesce(new.raw_user_meta_data ->> 'member_role', 'member'));
  if meta_member_role not in ('owner', 'admin', 'member') then
    meta_member_role := 'member';
  end if;
  if signup_flag then
    meta_member_role := 'owner';
  end if;

  insert into public.users (id, email, full_name, role_id, company_id)
  values (new.id, new.email, preferred_name, default_role_id, meta_company)
  on conflict (id) do update set
    company_id = coalesce(public.users.company_id, excluded.company_id);

  if meta_company is not null
     and exists (select 1 from public.company_details where id = meta_company) then
    insert into public.company_members (company_id, user_id, role)
    values (meta_company, new.id, meta_member_role)
    on conflict (company_id, user_id) do nothing;
  end if;

  return new;
end;
$$;

comment on function public.handle_new_auth_user() is
  'Invite / signup provisioning with company_id + company_members. Sayge is first Saasify client.';

-- ---------------------------------------------------------------------------
-- Billing: per-company subscriptions (replaces id='deployment' singleton)
-- ---------------------------------------------------------------------------

alter table public.billing_subscription
  add column if not exists company_id text references public.company_details (id) on delete cascade;

alter table public.billing_periods
  add column if not exists company_id text references public.company_details (id) on delete cascade;

alter table public.billing_events
  add column if not exists company_id text references public.company_details (id) on delete set null;

-- Drop singleton check if present.
do $$
declare
  cname text;
begin
  select conname into cname
  from pg_constraint
  where conrelid = 'public.billing_subscription'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%deployment%';
  if cname is not null then
    execute format('alter table public.billing_subscription drop constraint %I', cname);
  end if;
end $$;

-- Migrate legacy deployment row → Sayge.
update public.billing_subscription
set company_id = 'company_sayge'
where id = 'deployment' and company_id is null;

update public.billing_subscription
set id = 'company_sayge',
    company_id = 'company_sayge'
where id = 'deployment'
  and not exists (
    select 1 from public.billing_subscription where id = 'company_sayge'
  );

-- If both somehow exist, keep company_sayge and drop deployment.
delete from public.billing_subscription
where id = 'deployment'
  and exists (select 1 from public.billing_subscription where id = 'company_sayge');

insert into public.billing_subscription (
  id, company_id, plan_code, status, pos_enabled, grace_days
)
select 'company_sayge', 'company_sayge', 'growth', 'active', true, 7
where exists (select 1 from public.company_details where id = 'company_sayge')
  and not exists (
    select 1 from public.billing_subscription where company_id = 'company_sayge'
  )
on conflict (id) do nothing;

update public.billing_periods
set company_id = 'company_sayge'
where company_id is null;

-- Unique company_id on subscription (1:1).
create unique index if not exists billing_subscription_company_uidx
  on public.billing_subscription (company_id)
  where company_id is not null;

-- Periods unique per company + month.
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.billing_periods'::regclass
      and conname = 'billing_periods_period_ym_key'
  ) then
    alter table public.billing_periods drop constraint billing_periods_period_ym_key;
  end if;
exception when undefined_object then
  null;
end $$;

create unique index if not exists billing_periods_company_ym_uidx
  on public.billing_periods (company_id, period_ym)
  where company_id is not null;

comment on table public.billing_subscription is
  'Per-company Saasify subscription. Sayge (company_sayge) is client #1. Payment gateway not wired yet.';

create or replace function public.billing_company_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.app_company_id(),
    (select company_id from public.billing_subscription where company_id = 'company_sayge' limit 1),
    (select company_id from public.billing_subscription order by created_at limit 1)
  );
$$;

grant execute on function public.billing_company_id() to authenticated, service_role;

-- Drop legacy zero-arg overloads so default-arg versions are unambiguous.
drop function if exists public.billing_active_employee_count();
drop function if exists public.billing_active_employee_count(text);
drop function if exists public.billing_plan_limit();
drop function if exists public.billing_plan_limit(text);
drop function if exists public.billing_can_consume_seat();
drop function if exists public.billing_ensure_current_period();
drop function if exists public.billing_ensure_current_period(text);
drop function if exists public.billing_derive_status();
drop function if exists public.billing_derive_status(text);
drop function if exists public.billing_refresh_status();
drop function if exists public.billing_refresh_status(text);

create or replace function public.billing_active_employee_count(p_company_id text default null)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.employees e
  where e.is_active is true
    and coalesce(e.is_draft, false) is false
    and e.company_id = coalesce(p_company_id, public.billing_company_id());
$$;

create or replace function public.billing_plan_limit(p_company_id text default null)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.employee_limit
      from public.billing_subscription s
      join public.billing_plans p on p.code = s.plan_code
      where s.company_id = coalesce(p_company_id, public.billing_company_id())
      limit 1
    ),
    5
  );
$$;

create or replace function public.billing_can_consume_seat()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.billing_active_employee_count(null::text)
       < public.billing_plan_limit(null::text);
$$;

create or replace function public.billing_ensure_current_period(
  p_company_id text default null
)
returns public.billing_periods
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company text;
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_ym text;
  v_start date;
  v_end date;
  v_period public.billing_periods%rowtype;
  v_due numeric;
  v_status text;
  v_period_id text;
begin
  v_company := coalesce(nullif(trim(p_company_id), ''), public.billing_company_id());
  if v_company is null then
    raise exception 'BILLING_NO_SUBSCRIPTION';
  end if;

  select * into v_sub from public.billing_subscription where company_id = v_company;
  if not found then
    raise exception 'BILLING_NO_SUBSCRIPTION';
  end if;

  select * into v_plan from public.billing_plans where code = v_sub.plan_code;

  v_start := date_trunc('month', now())::date;
  v_end := (date_trunc('month', now()) + interval '1 month - 1 day')::date;
  v_ym := to_char(v_start, 'YYYY-MM');

  select * into v_period
  from public.billing_periods
  where company_id = v_company and period_ym = v_ym;
  if found then
    update public.billing_subscription
    set current_period_start = v_start,
        current_period_end = v_end
    where company_id = v_company
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

  if v_due <= 0 then
    v_status := 'comped';
  else
    v_status := 'unpaid';
  end if;

  v_period_id := 'bp_' || v_company || '_' || v_ym;

  insert into public.billing_periods (
    id, company_id, period_ym, period_start, period_end, plan_code,
    list_price_inr, amount_due_inr, amount_paid_inr, payment_status,
    paid_at, note, offer_id
  ) values (
    v_period_id,
    v_company,
    v_ym,
    v_start,
    v_end,
    v_sub.plan_code,
    v_plan.price_inr,
    v_due,
    0,
    v_status,
    case when v_status = 'comped' then now() else null end,
    case when v_status = 'comped' then 'Auto-settled (₹0 due)' else '' end,
    v_sub.offer_id
  )
  returning * into v_period;

  update public.billing_subscription
  set current_period_start = v_start,
      current_period_end = v_end
  where company_id = v_company;

  perform public.billing_log_event(
    'period_created',
    jsonb_build_object(
      'company_id', v_company,
      'period_ym', v_ym,
      'amount_due_inr', v_due,
      'payment_status', v_status
    )
  );

  return v_period;
end;
$$;

create or replace function public.billing_derive_status(p_company_id text default null)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_company text;
  v_sub public.billing_subscription%rowtype;
  v_period public.billing_periods%rowtype;
  v_grace_end timestamptz;
begin
  v_company := coalesce(nullif(trim(p_company_id), ''), public.billing_company_id());
  select * into v_sub from public.billing_subscription where company_id = v_company;
  if not found then
    return 'read_only';
  end if;

  select * into v_period
  from public.billing_periods
  where company_id = v_company
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM');

  if not found then
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

create or replace function public.billing_refresh_status(p_company_id text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company text;
  v_status text;
begin
  v_company := coalesce(nullif(trim(p_company_id), ''), public.billing_company_id());
  perform public.billing_ensure_current_period(v_company);
  v_status := public.billing_derive_status(v_company);
  update public.billing_subscription
  set status = v_status
  where company_id = v_company
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
  v_company text;
begin
  if new.company_id is null then
    new.company_id := coalesce(public.app_company_id(), 'company_sayge');
  end if;
  v_company := new.company_id;

  if tg_op = 'INSERT' then
    v_old_seat := false;
    v_new_seat := (new.is_active is true and coalesce(new.is_draft, false) is false);
  elsif tg_op = 'UPDATE' then
    v_old_seat := (old.is_active is true and coalesce(old.is_draft, false) is false);
    v_new_seat := (new.is_active is true and coalesce(new.is_draft, false) is false);
  else
    return new;
  end if;

  if v_new_seat and not v_old_seat then
    v_limit := public.billing_plan_limit(v_company);
    v_count := public.billing_active_employee_count(v_company);
    if v_count >= v_limit then
      select plan_code into v_plan
      from public.billing_subscription
      where company_id = v_company;
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

create or replace function public.billing_get_state()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company text;
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

  v_company := public.billing_company_id();
  perform public.billing_ensure_current_period(v_company);
  v_status := public.billing_refresh_status(v_company);

  select * into v_sub from public.billing_subscription where company_id = v_company;
  select * into v_plan from public.billing_plans where code = v_sub.plan_code;
  select * into v_period
  from public.billing_periods
  where company_id = v_company
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM');

  v_count := public.billing_active_employee_count(v_company);

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
    select * from public.billing_periods
    where company_id = v_company
    order by period_ym desc
    limit 12
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
    'offers', v_offers,
    'company_id', v_company,
    'payments_provider', null
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
  v_company text;
  v_old text;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;
  if not exists (select 1 from public.billing_plans where code = p_plan_code and is_active) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  v_company := public.billing_company_id();
  select plan_code into v_old from public.billing_subscription where company_id = v_company;

  update public.billing_subscription
  set plan_code = p_plan_code
  where company_id = v_company;

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
  where bp.company_id = v_company
    and bp.period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and p.code = p_plan_code
    and s.company_id = v_company
    and bp.payment_status = 'unpaid';

  update public.billing_periods
  set payment_status = 'comped',
      paid_at = now(),
      note = case when note = '' then 'Auto-settled after plan change (₹0)' else note end
  where company_id = v_company
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and amount_due_inr <= 0
    and payment_status = 'unpaid';

  perform public.billing_log_event(
    'plan_changed',
    jsonb_build_object('company_id', v_company, 'from', v_old, 'to', p_plan_code)
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
  v_company text;
  v_offer public.billing_offers%rowtype;
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_price numeric;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  v_company := public.billing_company_id();
  select * into v_offer from public.billing_offers where id = p_offer_id and is_active;
  if not found then
    raise exception 'BILLING_OFFER_NOT_FOUND' using errcode = 'P0001';
  end if;

  select * into v_sub from public.billing_subscription where company_id = v_company;
  select * into v_plan from public.billing_plans where code = v_sub.plan_code;

  if v_offer.applies_to_plan is not null and v_offer.applies_to_plan <> v_sub.plan_code then
    raise exception 'BILLING_OFFER_PLAN_MISMATCH' using errcode = 'P0001';
  end if;

  v_price := coalesce(
    p_offer_price_inr,
    public.billing_effective_amount_due(
      v_sub.plan_code, v_plan.price_inr, v_offer.id, null, null
    )
  );

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
  where company_id = v_company;

  update public.billing_periods
  set amount_due_inr = v_price,
      offer_id = v_offer.id
  where company_id = v_company
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and payment_status = 'unpaid';

  perform public.billing_log_event(
    'offer_applied',
    jsonb_build_object('company_id', v_company, 'offer_id', v_offer.id, 'offer_price_inr', v_price)
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
  v_company text;
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
begin
  if not public.app_is_staff() then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  v_company := public.billing_company_id();
  select * into v_sub from public.billing_subscription where company_id = v_company;
  select * into v_plan from public.billing_plans where code = v_sub.plan_code;

  update public.billing_subscription
  set offer_id = null, offer_price_inr = null, offer_ends_at = null
  where company_id = v_company;

  update public.billing_periods
  set amount_due_inr = v_plan.price_inr, offer_id = null
  where company_id = v_company
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and payment_status = 'unpaid';

  perform public.billing_log_event(
    'offer_cleared',
    jsonb_build_object('company_id', v_company)
  );

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
  where company_id = public.billing_company_id();

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
  where company_id = public.billing_company_id();

  perform public.billing_log_event(
    'pos_enabled_set',
    jsonb_build_object('pos_enabled', coalesce(p_enabled, true))
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
  where company_id = public.billing_company_id();

  return public.billing_get_state();
end;
$$;

create or replace function public.billing_public_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_company text;
  v_sub public.billing_subscription%rowtype;
  v_plan public.billing_plans%rowtype;
  v_status text;
  v_count int;
begin
  if auth.uid() is null then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  v_company := public.billing_company_id();
  select * into v_sub from public.billing_subscription where company_id = v_company;
  if not found then
    return jsonb_build_object(
      'status', 'active',
      'writes_allowed', true,
      'pos_enabled', true,
      'can_add_employee', true,
      'active_employees', 0,
      'employee_limit', 5,
      'plan_code', 'free',
      'plan_name', 'Free',
      'company_id', v_company,
      'payments_provider', null
    );
  end if;

  select * into v_plan from public.billing_plans where code = v_sub.plan_code;
  v_status := public.billing_derive_status(v_company);
  v_count := public.billing_active_employee_count(v_company);

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
    'current_period_end', v_sub.current_period_end,
    'company_id', v_company,
    'payments_provider', null
  );
end;
$$;

-- Tighten billing RLS to own company.
drop policy if exists billing_subscription_select on public.billing_subscription;
create policy billing_subscription_select on public.billing_subscription
  for select to authenticated
  using (
    company_id = public.app_company_id()
    or public.app_in_company(company_id)
  );

drop policy if exists billing_periods_select on public.billing_periods;
create policy billing_periods_select on public.billing_periods
  for select to authenticated
  using (
    public.app_is_staff()
    and company_id = public.app_company_id()
  );

-- Re-grant billing executes (signatures with defaults still match).
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'billing_%'
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
  end loop;
end $$;

grant execute on function public.billing_active_employee_count(text) to authenticated;
grant execute on function public.billing_plan_limit(text) to authenticated;
grant execute on function public.billing_can_consume_seat() to authenticated;
grant execute on function public.billing_writes_allowed() to authenticated;
grant execute on function public.billing_derive_status(text) to authenticated;
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
grant execute on function public.billing_ensure_current_period(text) to authenticated;
grant execute on function public.billing_refresh_status(text) to authenticated;
grant execute on function public.billing_company_id() to authenticated;

-- ---------------------------------------------------------------------------
-- Company-scoped RLS overlays (staff limited to own company)
-- ---------------------------------------------------------------------------

-- company_details: members only
drop policy if exists company_details_select_member on public.company_details;
create policy company_details_select_member on public.company_details
  for select to authenticated
  using (public.app_in_company(id) or id = public.app_company_id());

drop policy if exists company_details_update_member on public.company_details;
create policy company_details_update_member on public.company_details
  for update to authenticated
  using (public.app_is_staff() and id = public.app_company_id())
  with check (public.app_is_staff() and id = public.app_company_id());

-- Helper used by rewritten policies below
create or replace function public.app_same_company(p_company_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_company_id is not null
    and p_company_id = public.app_company_id();
$$;

grant execute on function public.app_same_company(text) to authenticated, service_role;

-- employees
drop policy if exists employees_select_company on public.employees;
create policy employees_select_company on public.employees
  for select to authenticated
  using (
    (public.app_is_staff() and public.app_same_company(company_id))
    or employee_id = public.app_employee_id()
  );

drop policy if exists employees_insert_company on public.employees;
create policy employees_insert_company on public.employees
  for insert to authenticated
  with check (public.app_is_staff() and public.app_same_company(company_id));

drop policy if exists employees_update_company on public.employees;
create policy employees_update_company on public.employees
  for update to authenticated
  using (
    (public.app_is_staff() and public.app_same_company(company_id))
    or employee_id = public.app_employee_id()
  )
  with check (
    (public.app_is_staff() and public.app_same_company(company_id))
    or employee_id = public.app_employee_id()
  );

drop policy if exists employees_delete_company on public.employees;
create policy employees_delete_company on public.employees
  for delete to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id));

-- clients
drop policy if exists clients_select_company on public.clients;
create policy clients_select_company on public.clients
  for select to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id));

drop policy if exists clients_write_company on public.clients;
create policy clients_write_company on public.clients
  for all to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id))
  with check (public.app_is_staff() and public.app_same_company(company_id));

-- cafes
drop policy if exists cafes_select_company on public.cafes;
create policy cafes_select_company on public.cafes
  for select to authenticated
  using (
    public.app_same_company(company_id)
    or public.app_in_company(company_id)
  );

drop policy if exists cafes_write_company on public.cafes;
create policy cafes_write_company on public.cafes
  for all to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id))
  with check (public.app_is_staff() and public.app_same_company(company_id));

-- users: same company or self
drop policy if exists users_select_company on public.users;
create policy users_select_company on public.users
  for select to authenticated
  using (
    id = auth.uid()
    or (public.app_is_staff() and public.app_same_company(company_id))
  );

-- ---------------------------------------------------------------------------
-- Platform ops: real multi-company snapshot + create + invite + set plan
-- ---------------------------------------------------------------------------

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
  v_sayge_plan_code text := null;
  v_sayge_plan_name text := null;
  v_sayge_status text := null;
  v_pos_enabled boolean := null;
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
  end if;

  if to_regclass('public.billing_subscription') is not null then
    select s.plan_code, p.name, s.status, s.pos_enabled
    into v_sayge_plan_code, v_sayge_plan_name, v_sayge_status, v_pos_enabled
    from public.billing_subscription s
    left join public.billing_plans p on p.code = s.plan_code
    where s.company_id = 'company_sayge'
    limit 1;
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
        'company', coalesce(nullif(trim(c.display_name), ''), c.name),
        'company_id', u.company_id,
        'plan_code', s.plan_code
      )
      order by u.created_at desc
    ),
    '[]'::jsonb
  )
  into v_users
  from public.users u
  left join public.roles r on r.id = u.role_id
  left join public.company_details c on c.id = u.company_id
  left join public.billing_subscription s on s.company_id = u.company_id;

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
          'is_first_client', c.id = 'company_sayge',
          'plan_code', s.plan_code,
          'plan_name', p.name,
          'users_count', coalesce(uc.cnt, 0)
        )
        order by c.created_at asc
      ),
      '[]'::jsonb
    )
    into v_companies
    from public.company_details c
    left join public.billing_subscription s on s.company_id = c.id
    left join public.billing_plans p on p.code = s.plan_code
    left join (
      select company_id, count(*)::int as cnt
      from public.users
      group by company_id
    ) uc on uc.company_id = c.id;
  end if;

  if to_regclass('public.billing_plans') is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'plan_code', p.code,
          'plan_name', p.name,
          'price_inr', p.price_inr,
          'employee_limit', p.employee_limit,
          'sort_order', p.sort_order,
          'is_active', p.is_active,
          'is_live', p.code = v_sayge_plan_code,
          'subscriptions', coalesce(s.cnt, 0),
          'companies_count', coalesce(s.cnt, 0),
          'users_count', coalesce(uu.cnt, 0)
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
    ) s on s.plan_code = p.code
    left join (
      select bs.plan_code, count(u.id)::int as cnt
      from public.billing_subscription bs
      join public.users u on u.company_id = bs.company_id
      group by bs.plan_code
    ) uu on uu.plan_code = p.code;
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
    'live_plan_code', v_sayge_plan_code,
    'live_plan_name', v_sayge_plan_name,
    'live_status', v_sayge_status,
    'pos_enabled', v_pos_enabled,
    'first_client_id', 'company_sayge',
    'first_client_name', 'Sayge',
    'product_name', 'Saasify'
  );
end;
$$;

revoke all on function public.platform_ops_snapshot(text) from public;
grant execute on function public.platform_ops_snapshot(text) to anon, authenticated;

-- Create a new client company + Free subscription (ops).
create or replace function public.platform_ops_create_company(
  p_password text,
  p_display_name text,
  p_name text default null,
  p_plan_code text default 'free',
  p_email text default null,
  p_telephone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_id text;
  v_plan text;
  v_base text;
  v_i int := 0;
begin
  if coalesce(p_password, '') is distinct from 'ihateluvstories' then
    raise exception 'PLATFORM_OPS_FORBIDDEN' using errcode = '42501';
  end if;
  if nullif(trim(p_display_name), '') is null then
    raise exception 'COMPANY_NAME_REQUIRED' using errcode = 'P0001';
  end if;

  v_plan := coalesce(nullif(trim(p_plan_code), ''), 'free');
  if not exists (select 1 from public.billing_plans where code = v_plan) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  v_base := coalesce(nullif(public.saasify_slugify(p_name), ''), public.saasify_slugify(p_display_name));
  v_slug := v_base;
  while exists (select 1 from public.company_details where name = v_slug) loop
    v_i := v_i + 1;
    v_slug := v_base || '-' || v_i::text;
  end loop;

  v_id := 'company_' || replace(v_slug, '-', '_');
  if exists (select 1 from public.company_details where id = v_id) then
    v_id := v_id || '_' || substr(md5(random()::text), 1, 6);
  end if;

  insert into public.company_details (id, name, display_name, email, telephone)
  values (
    v_id,
    v_slug,
    trim(p_display_name),
    coalesce(trim(p_email), ''),
    coalesce(trim(p_telephone), '')
  );

  insert into public.billing_subscription (
    id, company_id, plan_code, status, pos_enabled, grace_days
  ) values (
    v_id, v_id, v_plan, 'active', true, 7
  );

  perform public.billing_ensure_current_period(v_id);

  update public.billing_periods
  set payment_status = 'comped',
      paid_at = now(),
      note = 'Ops-created company · manual billing'
  where company_id = v_id
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and payment_status = 'unpaid';

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload, company_id)
    values (
      'platform_ops_company_created',
      jsonb_build_object(
        'company_id', v_id,
        'name', v_slug,
        'display_name', trim(p_display_name),
        'plan_code', v_plan
      ),
      v_id
    );
  end if;

  return public.platform_ops_snapshot(p_password);
end;
$$;

revoke all on function public.platform_ops_create_company(text, text, text, text, text, text) from public;
grant execute on function public.platform_ops_create_company(text, text, text, text, text, text)
  to anon, authenticated;

-- Set a company's plan (replaces singleton "live plan" for multi-tenant).
create or replace function public.platform_ops_set_company_plan(
  p_password text,
  p_company_id text,
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
  if not exists (select 1 from public.company_details where id = p_company_id) then
    raise exception 'COMPANY_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.billing_plans where code = p_plan_code) then
    raise exception 'BILLING_UNKNOWN_PLAN' using errcode = 'P0001';
  end if;

  update public.billing_plans set is_active = true where code = p_plan_code;

  select plan_code into v_old
  from public.billing_subscription
  where company_id = p_company_id;

  insert into public.billing_subscription (
    id, company_id, plan_code, status, pos_enabled, grace_days
  ) values (
    p_company_id, p_company_id, p_plan_code, 'active', true, 7
  )
  on conflict (id) do update set
    plan_code = excluded.plan_code,
    company_id = excluded.company_id,
    updated_at = now();

  perform public.billing_ensure_current_period(p_company_id);

  update public.billing_periods bp
  set plan_code = p_plan_code,
      list_price_inr = p.price_inr,
      amount_due_inr = public.billing_effective_amount_due(
        p_plan_code, p.price_inr, s.offer_id, s.offer_price_inr, s.offer_ends_at
      )
  from public.billing_plans p, public.billing_subscription s
  where bp.company_id = p_company_id
    and bp.period_ym = to_char(date_trunc('month', now()), 'YYYY-MM')
    and p.code = p_plan_code
    and s.company_id = p_company_id
    and bp.payment_status = 'unpaid';

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload, company_id)
    values (
      'platform_ops_company_plan_changed',
      jsonb_build_object('company_id', p_company_id, 'from', v_old, 'to', p_plan_code),
      p_company_id
    );
  end if;

  return public.platform_ops_snapshot(p_password);
end;
$$;

revoke all on function public.platform_ops_set_company_plan(text, text, text) from public;
grant execute on function public.platform_ops_set_company_plan(text, text, text)
  to anon, authenticated;

-- Keep set_live_plan as convenience → Sayge (first client).
create or replace function public.platform_ops_set_live_plan(
  p_password text,
  p_plan_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.platform_ops_set_company_plan(p_password, 'company_sayge', p_plan_code);
end;
$$;

revoke all on function public.platform_ops_set_live_plan(text, text) from public;
grant execute on function public.platform_ops_set_live_plan(text, text)
  to anon, authenticated;

-- Record an owner invite intent (edge function still sends the email).
create or replace function public.platform_ops_prepare_owner_invite(
  p_password text,
  p_company_id text,
  p_email text,
  p_full_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_role text;
  v_email text;
begin
  if coalesce(p_password, '') is distinct from 'ihateluvstories' then
    raise exception 'PLATFORM_OPS_FORBIDDEN' using errcode = '42501';
  end if;
  if not exists (select 1 from public.company_details where id = p_company_id) then
    raise exception 'COMPANY_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_email := lower(trim(coalesce(p_email, '')));
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'EMAIL_REQUIRED' using errcode = 'P0001';
  end if;

  select id into v_owner_role
  from public.roles
  where code = 'owner' and is_active
  order by sort_order
  limit 1;

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload, company_id)
    values (
      'platform_ops_owner_invite_prepared',
      jsonb_build_object(
        'company_id', p_company_id,
        'email', v_email,
        'full_name', coalesce(nullif(trim(p_full_name), ''), ''),
        'role_id', v_owner_role,
        'member_role', 'owner',
        'must_set_password', true
      ),
      p_company_id
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'company_id', p_company_id,
    'email', v_email,
    'full_name', coalesce(nullif(trim(p_full_name), ''), ''),
    'role_id', v_owner_role,
    'member_role', 'owner',
    'must_set_password', true,
    'invite_metadata', jsonb_build_object(
      'must_set_password', 'true',
      'company_id', p_company_id,
      'member_role', 'owner',
      'role_id', coalesce(v_owner_role, ''),
      'role_code', 'owner',
      'full_name', coalesce(nullif(trim(p_full_name), ''), ''),
      'name', coalesce(nullif(trim(p_full_name), ''), '')
    )
  );
end;
$$;

revoke all on function public.platform_ops_prepare_owner_invite(text, text, text, text) from public;
grant execute on function public.platform_ops_prepare_owner_invite(text, text, text, text)
  to anon, authenticated;

-- Update set_plan_active: cannot deactivate if ANY company is on it.
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
     and exists (
       select 1 from public.billing_subscription where plan_code = p_code
     ) then
    raise exception 'CANNOT_DEACTIVATE_PLAN_IN_USE' using errcode = 'P0001';
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
-- Public self-serve signup (Free plan). Payment provider: not wired (null).
-- Call after auth.signUp with metadata saasify_signup=true, company_name=...
-- ---------------------------------------------------------------------------

create or replace function public.saasify_complete_signup(
  p_company_name text,
  p_display_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_base text;
  v_slug text;
  v_id text;
  v_i int := 0;
  v_display text;
  v_owner_role text;
begin
  if v_uid is null then
    raise exception 'SIGNUP_AUTH_REQUIRED' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.company_members where user_id = v_uid
  ) then
    return jsonb_build_object(
      'ok', true,
      'already_provisioned', true,
      'company_id', (select company_id from public.users where id = v_uid)
    );
  end if;

  v_display := coalesce(
    nullif(trim(p_display_name), ''),
    nullif(trim(p_company_name), ''),
    'My Company'
  );
  v_base := public.saasify_slugify(v_display);
  v_slug := v_base;
  while exists (select 1 from public.company_details where name = v_slug) loop
    v_i := v_i + 1;
    v_slug := v_base || '-' || v_i::text;
  end loop;

  v_id := 'company_' || replace(v_slug, '-', '_');
  if exists (select 1 from public.company_details where id = v_id) then
    v_id := v_id || '_' || substr(md5(random()::text), 1, 6);
  end if;

  select id into v_owner_role
  from public.roles where code = 'owner' and is_active
  order by sort_order limit 1;

  insert into public.company_details (id, name, display_name)
  values (v_id, v_slug, v_display);

  insert into public.billing_subscription (
    id, company_id, plan_code, status, pos_enabled, grace_days
  ) values (
    v_id, v_id, 'free', 'active', true, 7
  );

  perform public.billing_ensure_current_period(v_id);
  update public.billing_periods
  set payment_status = 'comped',
      paid_at = now(),
      note = 'Self-serve Free signup · payment gateway not connected'
  where company_id = v_id
    and period_ym = to_char(date_trunc('month', now()), 'YYYY-MM');

  insert into public.users (id, email, full_name, role_id, company_id)
  select
    v_uid,
    au.email,
    coalesce(
      nullif(trim(au.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(au.raw_user_meta_data ->> 'name'), ''),
      split_part(au.email, '@', 1)
    ),
    coalesce(v_owner_role, (select id from public.roles order by sort_order limit 1)),
    v_id
  from auth.users au
  where au.id = v_uid
  on conflict (id) do update set
    company_id = excluded.company_id,
    role_id = coalesce(excluded.role_id, public.users.role_id);

  insert into public.company_members (company_id, user_id, role)
  values (v_id, v_uid, 'owner')
  on conflict (company_id, user_id) do update set role = 'owner';

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload, company_id)
    values (
      'saasify_self_serve_signup',
      jsonb_build_object(
        'company_id', v_id,
        'user_id', v_uid,
        'plan_code', 'free',
        'payments_provider', null
      ),
      v_id
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'company_id', v_id,
    'company_name', v_slug,
    'display_name', v_display,
    'plan_code', 'free',
    'payments_provider', null
  );
end;
$$;

revoke all on function public.saasify_complete_signup(text, text) from public;
grant execute on function public.saasify_complete_signup(text, text) to authenticated;

-- Payment provider placeholder (Phase 5 stub).
create table if not exists public.billing_payment_provider_config (
  id text primary key default 'default' check (id = 'default'),
  provider text, -- future: 'razorpay' | 'stripe' | null
  is_enabled boolean not null default false,
  public_key text,
  notes text not null default 'Not connected. Plans are assigned manually or Free self-serve.',
  updated_at timestamptz not null default now()
);

insert into public.billing_payment_provider_config (id, provider, is_enabled, notes)
values (
  'default',
  null,
  false,
  'Payment gateway not connected. Use platform ops or Free self-serve signup.'
)
on conflict (id) do nothing;

alter table public.billing_payment_provider_config enable row level security;
drop policy if exists billing_payment_provider_select on public.billing_payment_provider_config;
create policy billing_payment_provider_select on public.billing_payment_provider_config
  for select to authenticated using (true);
grant select on table public.billing_payment_provider_config to authenticated;

comment on table public.billing_payment_provider_config is
  'Stub for Razorpay/Stripe. provider=null until Phase 5 payments are wired.';

-- ---------------------------------------------------------------------------
-- Drop legacy global staff policies (OR would leak across tenants)
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
  ops text[] := array['select', 'insert', 'update', 'delete'];
  op text;
begin
  foreach t in array array[
    'clients', 'dms_entities', 'company_details', 'invoices', 'invoice_line_items',
    'proposals', 'proposal_line_items', 'payroll_runs', 'pos_brands', 'pos_products',
    'employees', 'users', 'expenses', 'payslip_records', 'employee_purchase_orders',
    'documents', 'expense_categories'
  ]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    foreach op in array ops
    loop
      begin
        execute format('drop policy if exists %I on public.%I', t || '_' || op || '_rbac', t);
        execute format('drop policy if exists %I on public.%I', '"' || t || '_' || op || '_rbac' || '"', t);
      exception when others then
        null;
      end;
      execute format('drop policy if exists %I on public.%I', t || '_' || op || '_rbac', t);
    end loop;
    -- Quoted policy names from security_hardening
    execute format('drop policy if exists %I on public.%I', t || '_select_rbac', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_rbac', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_rbac', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_rbac', t);
  end loop;
end $$;

-- Recreate company-scoped staff policies for core tables with company_id
do $$
declare
  t text;
begin
  foreach t in array array[
    'clients', 'dms_entities', 'invoices', 'proposals', 'payroll_runs',
    'pos_brands', 'pos_products', 'expenses', 'payslip_records',
    'employee_purchase_orders', 'documents', 'expense_categories'
  ]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = t and column_name = 'company_id'
    ) then
      continue;
    end if;

    execute format('drop policy if exists %I on public.%I', t || '_select_tenant', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_tenant', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_tenant', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_tenant', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (
         (public.app_is_staff() and public.app_same_company(company_id))
         or public.app_in_company(company_id)
       )',
      t || '_select_tenant', t
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (
         public.app_is_staff() and public.app_same_company(coalesce(company_id, public.app_company_id()))
       )',
      t || '_insert_tenant', t
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (
         public.app_is_staff() and public.app_same_company(company_id)
       ) with check (
         public.app_is_staff() and public.app_same_company(company_id)
       )',
      t || '_update_tenant', t
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (
         public.app_is_staff() and public.app_same_company(company_id)
       )',
      t || '_delete_tenant', t
    );
  end loop;
end $$;

-- Replace users / employees rbac with tenant-aware versions (idempotent names)
drop policy if exists "users_select_rbac" on public.users;
drop policy if exists "users_insert_rbac" on public.users;
drop policy if exists "users_update_rbac" on public.users;
drop policy if exists "users_delete_rbac" on public.users;
drop policy if exists users_select_rbac on public.users;
drop policy if exists users_insert_rbac on public.users;
drop policy if exists users_update_rbac on public.users;
drop policy if exists users_delete_rbac on public.users;

drop policy if exists users_select_company on public.users;
create policy users_select_company on public.users
  for select to authenticated
  using (
    id = auth.uid()
    or (public.app_is_staff() and public.app_same_company(company_id))
  );

drop policy if exists users_insert_company on public.users;
create policy users_insert_company on public.users
  for insert to authenticated
  with check (public.app_is_staff() and public.app_same_company(company_id));

drop policy if exists users_update_company on public.users;
create policy users_update_company on public.users
  for update to authenticated
  using (id = auth.uid() or (public.app_is_staff() and public.app_same_company(company_id)))
  with check (id = auth.uid() or (public.app_is_staff() and public.app_same_company(company_id)));

drop policy if exists users_delete_company on public.users;
create policy users_delete_company on public.users
  for delete to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id));

drop policy if exists "employees_select_rbac" on public.employees;
drop policy if exists "employees_insert_rbac" on public.employees;
drop policy if exists "employees_update_rbac" on public.employees;
drop policy if exists "employees_delete_rbac" on public.employees;

drop policy if exists company_details_select_rbac on public.company_details;
drop policy if exists company_details_insert_rbac on public.company_details;
drop policy if exists company_details_update_rbac on public.company_details;
drop policy if exists company_details_delete_rbac on public.company_details;

-- Cafe policies: keep cafe access AND same company when company_id set
drop policy if exists cafes_select on public.cafes;
drop policy if exists cafes_insert on public.cafes;
drop policy if exists cafes_update on public.cafes;
drop policy if exists cafes_delete on public.cafes;
drop policy if exists cafes_select_company on public.cafes;
drop policy if exists cafes_write_company on public.cafes;

create policy cafes_select on public.cafes
  for select to authenticated
  using (
    public.app_can_access_cafe(id)
    and (company_id is null or public.app_same_company(company_id) or public.app_in_company(company_id))
  );

create policy cafes_insert on public.cafes
  for insert to authenticated
  with check (
    public.app_is_staff()
    and public.app_same_company(coalesce(company_id, public.app_company_id()))
  );

create policy cafes_update on public.cafes
  for update to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id))
  with check (public.app_is_staff() and public.app_same_company(company_id));

create policy cafes_delete on public.cafes
  for delete to authenticated
  using (public.app_is_staff() and public.app_same_company(company_id));

-- Default company_id on insert for key tables
create or replace function public.saasify_set_company_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.company_id is null then
    new.company_id := coalesce(public.app_company_id(), 'company_sayge');
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'employees', 'clients', 'cafes', 'expenses', 'proposals', 'invoices',
    'payroll_runs', 'payslip_records', 'dms_entities', 'documents',
    'expense_categories', 'employee_purchase_orders'
  ]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    execute format('drop trigger if exists saasify_set_company_id on public.%I', t);
    execute format(
      'create trigger saasify_set_company_id before insert on public.%I
       for each row execute function public.saasify_set_company_id()',
      t
    );
  end loop;
end $$;
-- Restore RLS for child line-item tables (no company_id of their own).
-- Broken by multi_tenant.sql which dropped *_rbac policies but did not recreate them.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- proposal_line_items — staff of the parent proposal's company
-- ---------------------------------------------------------------------------

alter table public.proposal_line_items enable row level security;

drop policy if exists proposal_line_items_select_tenant on public.proposal_line_items;
drop policy if exists proposal_line_items_insert_tenant on public.proposal_line_items;
drop policy if exists proposal_line_items_update_tenant on public.proposal_line_items;
drop policy if exists proposal_line_items_delete_tenant on public.proposal_line_items;
drop policy if exists "proposal_line_items_select_rbac" on public.proposal_line_items;
drop policy if exists "proposal_line_items_insert_rbac" on public.proposal_line_items;
drop policy if exists "proposal_line_items_update_rbac" on public.proposal_line_items;
drop policy if exists "proposal_line_items_delete_rbac" on public.proposal_line_items;

create policy proposal_line_items_select_tenant on public.proposal_line_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

create policy proposal_line_items_insert_tenant on public.proposal_line_items
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

create policy proposal_line_items_update_tenant on public.proposal_line_items
  for update to authenticated
  using (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  )
  with check (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

create policy proposal_line_items_delete_tenant on public.proposal_line_items
  for delete to authenticated
  using (
    exists (
      select 1
      from public.proposals p
      where p.id = proposal_id
        and public.app_is_staff()
        and public.app_same_company(p.company_id)
    )
  );

grant select, insert, update, delete on public.proposal_line_items to authenticated;

-- ---------------------------------------------------------------------------
-- invoice_line_items — staff of the parent invoice's company
-- ---------------------------------------------------------------------------

alter table public.invoice_line_items enable row level security;

drop policy if exists invoice_line_items_select_tenant on public.invoice_line_items;
drop policy if exists invoice_line_items_insert_tenant on public.invoice_line_items;
drop policy if exists invoice_line_items_update_tenant on public.invoice_line_items;
drop policy if exists invoice_line_items_delete_tenant on public.invoice_line_items;
drop policy if exists "invoice_line_items_select_rbac" on public.invoice_line_items;
drop policy if exists "invoice_line_items_insert_rbac" on public.invoice_line_items;
drop policy if exists "invoice_line_items_update_rbac" on public.invoice_line_items;
drop policy if exists "invoice_line_items_delete_rbac" on public.invoice_line_items;

create policy invoice_line_items_select_tenant on public.invoice_line_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

create policy invoice_line_items_insert_tenant on public.invoice_line_items
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

create policy invoice_line_items_update_tenant on public.invoice_line_items
  for update to authenticated
  using (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  )
  with check (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

create policy invoice_line_items_delete_tenant on public.invoice_line_items
  for delete to authenticated
  using (
    exists (
      select 1
      from public.invoices i
      where i.id = invoice_id
        and public.app_is_staff()
        and public.app_same_company(i.company_id)
    )
  );

grant select, insert, update, delete on public.invoice_line_items to authenticated;
-- EOF line items RLS
