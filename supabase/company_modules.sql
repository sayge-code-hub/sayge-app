-- Company module opt-in (post-signup picker).
-- Run after multi_tenant.sql / billing. Safe to re-run.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.company_details
  add column if not exists enabled_modules text[] not null default '{}';

alter table public.company_details
  add column if not exists modules_selected_at timestamptz;

comment on column public.company_details.enabled_modules is
  'Opted-in product packs: hrms, finances, pos, assets, checklist.';

comment on column public.company_details.modules_selected_at is
  'When the owner finished module onboarding. Null = must pick modules.';

-- Grandfather existing tenants (full access, onboarding done).
update public.company_details
set
  enabled_modules = array[
    'hrms', 'finances', 'pos', 'assets', 'checklist'
  ],
  modules_selected_at = coalesce(modules_selected_at, now())
where modules_selected_at is null
  and (
    id = 'company_sayge'
    or exists (
      select 1 from public.billing_subscription s
      where s.company_id = company_details.id
    )
  );

-- New self-serve signups: empty modules until picker (idempotent patch).
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

  insert into public.company_details (
    id, name, display_name, enabled_modules, modules_selected_at
  ) values (
    v_id, v_slug, v_display, '{}', null
  );

  -- POS off until owner opts into the pos module.
  insert into public.billing_subscription (
    id, company_id, plan_code, status, pos_enabled, grace_days
  ) values (
    v_id, v_id, 'free', 'active', false, 7
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
    'modules_selected', false,
    'payments_provider', null
  );
end;
$$;

revoke all on function public.saasify_complete_signup(text, text) from public;
grant execute on function public.saasify_complete_signup(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Save modules (owner/admin of active company)
-- ---------------------------------------------------------------------------

create or replace function public.company_set_modules(p_modules text[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company text;
  v_clean text[];
  v_allowed text[] := array[
    'hrms', 'finances', 'pos', 'assets', 'checklist'
  ];
  v_want_pos boolean;
begin
  if auth.uid() is null then
    raise exception 'MODULES_AUTH_REQUIRED' using errcode = '42501';
  end if;
  if not public.app_is_staff() then
    raise exception 'MODULES_FORBIDDEN' using errcode = '42501';
  end if;

  v_company := public.app_company_id();
  if v_company is null or length(trim(v_company)) = 0 then
    raise exception 'MODULES_NO_COMPANY' using errcode = 'P0001';
  end if;

  select coalesce(array_agg(distinct m order by m), '{}')
  into v_clean
  from unnest(coalesce(p_modules, '{}')) as m
  where m = any (v_allowed);

  if v_clean is null or cardinality(v_clean) = 0 then
    raise exception 'MODULES_REQUIRED' using errcode = 'P0001';
  end if;

  v_want_pos := 'pos' = any (v_clean);

  update public.company_details
  set
    enabled_modules = v_clean,
    modules_selected_at = now()
  where id = v_company;

  update public.billing_subscription
  set pos_enabled = v_want_pos
  where company_id = v_company;

  if to_regclass('public.billing_events') is not null then
    insert into public.billing_events (event_type, payload, company_id)
    values (
      'company_modules_set',
      jsonb_build_object(
        'company_id', v_company,
        'modules', to_jsonb(v_clean),
        'pos_enabled', v_want_pos
      ),
      v_company
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'company_id', v_company,
    'enabled_modules', to_jsonb(v_clean),
    'modules_selected', true,
    'pos_enabled', v_want_pos
  );
end;
$$;

revoke all on function public.company_set_modules(text[]) from public;
grant execute on function public.company_set_modules(text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Expose modules on billing_public_snapshot
-- ---------------------------------------------------------------------------

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
  v_modules text[] := '{}';
  v_selected_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;

  v_company := public.billing_company_id();

  if v_company is not null then
    select enabled_modules, modules_selected_at
    into v_modules, v_selected_at
    from public.company_details
    where id = v_company;
  end if;

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
      'enabled_modules', to_jsonb(coalesce(v_modules, '{}')),
      'modules_selected', v_selected_at is not null,
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
    'enabled_modules', to_jsonb(coalesce(v_modules, '{}')),
    'modules_selected', v_selected_at is not null,
    'payments_provider', null
  );
end;
$$;

revoke all on function public.billing_public_snapshot() from public;
grant execute on function public.billing_public_snapshot() to authenticated;
