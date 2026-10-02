-- Allow activity ledger reads for the app (anon + authenticated).
-- Run in Supabase SQL Editor if ledger returns empty / permission errors.

drop policy if exists "activity_log_select_auth" on public.activity_log;
drop policy if exists "activity_log_select_anon" on public.activity_log;

create policy "activity_log_select_anon"
  on public.activity_log for select
  to anon, authenticated
  using (true);

grant select on public.activity_log to anon, authenticated;
