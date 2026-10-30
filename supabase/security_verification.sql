-- ===========================================================================
-- Sayge — security verification.
--
-- Read-only. Run in the Supabase SQL Editor AFTER supabase/security_hardening.sql.
-- Nothing here prints, needs, or stores a secret.
--
--   Must return ZERO rows : 1, 2, 3, 7, 8, 9, 14
--   Inventory / review    : 4, 5, 6, 10, 11, 12, 13 (expected values noted
--                           above each query)
--
-- Passing these checks demonstrates the access model documented in the README
-- is actually installed. It says nothing about any database you have not run
-- it against.
-- ===========================================================================

-- 1. anon must hold no table privileges in the public schema. Expect 0 rows.
select table_name, privilege_type, grantee
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'PUBLIC')
order by table_name, privilege_type;

-- 2. No RLS policy may name anon or the PUBLIC pseudo-role. Expect 0 rows.
--    (Permissive policies combine with OR, so a single leftover re-opens
--     the table regardless of how strict the other policies are.)
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and ('anon' = any(roles) or 'public' = any(roles))
order by tablename, policyname;

-- 3. RLS must be enabled on every table in the public schema. Expect 0 rows.
select c.relname as table_without_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and not c.relrowsecurity
order by 1;

-- 4. No table may be left RLS-enabled with zero policies *and* privileges
--    granted to authenticated (that would silently break the app, not leak).
--    Review anything listed here.
select c.relname as table_name
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relrowsecurity
  and not exists (
    select 1 from pg_policies p
    where p.schemaname = 'public' and p.tablename = c.relname
  )
order by 1;

-- 5. Full policy inventory — eyeball that each sensitive table is
--    `{authenticated}` and gated on app_is_staff() / self-ownership.
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;

-- 6. Storage: only intentionally public buckets may have public = true.
--    Expect exactly: brand-logos, employee-avatars, pos-product-images,
--    user-avatars. `documents` and `employee-pos` must be false.
select id, name, public
from storage.buckets
order by id;

-- 7. Storage policies on private buckets must not be reachable by anon.
--    Expect 0 rows.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and ('anon' = any(roles) or 'public' = any(roles))
  and (qual || coalesce(with_check, '')) like any (
    array['%documents%', '%employee-pos%']
  );

-- 8. Public buckets must not contain HR / finance files.
--    Expect 0 rows. Two rules: public buckets hold images and nothing else,
--    and no object may be named after an identity / finance document.
--    Keywords are word-bounded so "company" does not trip the "pan" rule.
select bucket_id, name
from storage.objects
where bucket_id in (
    'brand-logos', 'employee-avatars', 'pos-product-images', 'user-avatars'
  )
  and (
    name !~* '\.(png|jpe?g|webp|gif|svg|avif)$'
    or name ~* '(^|[^a-z])(payslip|salary|invoice|contract|offer[-_ ]?letter|aadhaar|pan|passport|receipt|bank)([^a-z]|$)'
  )
order by bucket_id, name;

-- 9. No function in `public` may be executable by anon or PUBLIC —
--    except intentional guest Cafe POS + password-gated platform_ops RPCs.
--    PostgreSQL grants EXECUTE to PUBLIC on every new function, and anon
--    inherits it, so this must cover the whole schema — not just the role
--    helpers. Extension-owned functions are excluded; their ACLs are the
--    extension's to manage. Expect 0 rows.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       case when acl.grantee = 0 then 'PUBLIC'
            else pg_get_userbyid(acl.grantee) end as grantee
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
where n.nspname = 'public'
  and acl.privilege_type = 'EXECUTE'
  and (acl.grantee = 0 or pg_get_userbyid(acl.grantee) = 'anon')
  and p.proname not in (
    'get_guest_cafe_menu',
    'create_guest_cafe_order',
    'platform_ops_snapshot',
    'platform_ops_update_plan',
    'platform_ops_set_live_plan',
    'platform_ops_set_plan_active',
    'platform_ops_create_company',
    'platform_ops_set_company_plan',
    'platform_ops_prepare_owner_invite'
  )
  and not exists (
    select 1 from pg_depend d
    where d.classid = 'pg_proc'::regclass
      and d.objid = p.oid
      and d.deptype = 'e'
  )
order by 1, 3;

-- 10. SECURITY DEFINER audit. These run as their owner and bypass RLS, so
--     each one must have a pinned search_path and a deliberate grantee list.
--     Review every row; expect only the role helpers and trigger functions.
select p.proname,
       p.prosecdef as security_definer,
       p.prorettype::regtype::text as returns,
       coalesce(array_to_string(p.proconfig, ', '), '(no search_path pinned)') as config,
       coalesce(
         (select string_agg(
            case when a.grantee = 0 then 'PUBLIC'
                 else pg_get_userbyid(a.grantee) end, ', ')
          from aclexplode(p.proacl) a
          where a.privilege_type = 'EXECUTE'),
         '(owner only)'
       ) as execute_granted_to
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and not exists (
    select 1 from pg_depend d
    where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'
  )
order by 1;

-- 11. Coverage: distinguishes a MISSING optional table from an EXPOSED one.
--     `missing` is fine (feature pack not installed). Anything reported as
--     'EXPOSED - ...' must be fixed before go-live.
with expected(table_name) as (
  values ('employees'), ('users'), ('roles'), ('clients'), ('dms_entities'),
         ('documents'), ('employee_purchase_orders'), ('expenses'),
         ('expense_categories'), ('invoices'), ('invoice_line_items'),
         ('proposals'), ('proposal_line_items'), ('payroll_runs'),
         ('payslip_records'), ('activity_log'), ('company_details'),
         ('pos_brands'), ('pos_products'), ('pos_product_images'),
         ('pos_product_attributes'), ('pos_product_variants'),
         ('pos_purchases'), ('pos_purchase_items'), ('pos_price_rules'),
         ('pos_commerce_audit')
)
select e.table_name,
       case
         when c.oid is null then 'missing (optional feature not installed)'
         when not c.relrowsecurity then 'EXPOSED - RLS disabled'
         when exists (
           select 1 from pg_policies p
           where p.schemaname = 'public' and p.tablename = e.table_name
             and ('anon' = any(p.roles) or 'public' = any(p.roles))
         ) then 'EXPOSED - anon policy present'
         when exists (
           select 1 from information_schema.role_table_grants g
           where g.table_schema = 'public' and g.table_name = e.table_name
             and g.grantee in ('anon', 'PUBLIC')
         ) then 'EXPOSED - anon grant present'
         else 'ok'
       end as verdict
from expected e
left join pg_class c
  on c.relname = e.table_name
 and c.relnamespace = 'public'::regnamespace
 and c.relkind = 'r'
order by 2 desc, 1;

-- 12. The column-level write guards the README relies on must be installed.
--     Expect exactly 3 rows: employees_self_update_guard,
--     users_self_update_guard, expenses_guard_approval.
select c.relname as table_name, t.tgname as trigger_name
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
where not t.tgisinternal
  and c.relnamespace = 'public'::regnamespace
  and t.tgname in (
    'employees_self_update_guard',
    'users_self_update_guard',
    'expenses_guard_approval'
  )
order by 1, 2;

-- 13. Employee uploads into the private `documents` bucket must be pinned to
--     their own folder. Expect 1 row whose with_check references
--     app_employee_id() and storage.foldername — a policy that only checks
--     bucket_id would let any employee write into any other's folder.
select policyname, roles, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname = 'documents_storage_insert';

-- 14. Degraded-mode detector. security_hardening.sql fails closed when the
--     expense ownership columns are absent, which silently turns expenses and
--     expense receipts staff-only. Expect 0 rows; a row means a prerequisite
--     migration was skipped, not that the hardening failed.
select 'expenses.created_by' as missing_column,
       'expenses are staff-only; employees cannot file or see own claims' as effect
where to_regclass('public.expenses') is not null
  and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'expenses'
      and column_name = 'created_by'
  )
union all
select 'expenses.receipt_path',
       'receipt upload to documents/expenses/<id>/ is staff-only'
where to_regclass('public.expenses') is not null
  and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'expenses'
      and column_name = 'receipt_path'
  );


-- ===========================================================================
-- Out-of-band check: anonymous REST requests must be denied.
--
-- Run from a shell with the project's *anon* key. Do not paste the key into
-- the repo, a ticket, or a chat window; read it from your local .env.
--
--   set -a; source .env; set +a
--   for t in employees users clients documents expenses invoices \
--            invoice_line_items proposals proposal_line_items \
--            payroll_runs payslip_records activity_log expense_categories \
--            pos_products pos_purchases; do
--     code=$(curl -s -o /dev/null -w '%{http_code}' \
--       "$SUPABASE_URL/rest/v1/$t?select=*&limit=1" \
--       -H "apikey: $SUPABASE_ANON_KEY")
--     echo "$t -> $code"
--   done
--
-- Expected: 401 / 403 / 404 for every table. A 200 means data is exposed.
-- `scripts/setup_supabase.sh` runs exactly this check and exits non-zero on 200.
-- ===========================================================================
