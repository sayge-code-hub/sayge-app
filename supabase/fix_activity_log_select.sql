-- Activity ledger reads: owner/admin only. Rows are written by the
-- SECURITY DEFINER trigger public.log_row_activity(), never by a client.
-- Superseded by supabase/security_hardening.sql; kept for targeted re-runs.

drop policy if exists "activity_log_select_auth" on public.activity_log;
drop policy if exists "activity_log_select_anon" on public.activity_log;
drop policy if exists "activity_log_select_rbac" on public.activity_log;

create policy "activity_log_select_rbac"
  on public.activity_log for select
  to authenticated
  using (public.app_is_staff());

revoke all on public.activity_log from anon, authenticated;
grant select on public.activity_log to authenticated;
