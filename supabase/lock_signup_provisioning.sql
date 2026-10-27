-- Invite-only profile provisioning.
-- App has no signUp API; profiles must only be created for invited users.
-- ALSO disable public email signup in Dashboard → Authentication → Providers → Email
--   ("Allow new users to sign up" / Enable Sign Ups → OFF).

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
begin
  email_lower := lower(coalesce(new.email, ''));

  -- Any email domain can get an app profile (invite-only still applies).
  if email_lower = '' or position('@' in email_lower) = 0 then
    return new;
  end if;

  invited := new.invited_at is not null;
  must_set := coalesce(new.raw_user_meta_data ->> 'must_set_password', '')
    in ('true', '1');

  -- Skip open self-signup: require invite marker or invite metadata.
  if not invited and not must_set then
    return new;
  end if;

  meta_role := nullif(trim(coalesce(new.raw_user_meta_data ->> 'role_id', '')), '');
  if meta_role is not null then
    select id into default_role_id
    from public.roles
    where id = meta_role and is_active
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

  insert into public.users (id, email, full_name, role_id)
  values (new.id, new.email, preferred_name, default_role_id)
  on conflict (id) do nothing;

  return new;
end;
$$;
