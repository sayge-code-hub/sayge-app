#!/usr/bin/env bash
# Applies the Sayge database setup in order, then verifies that anonymous
# requests are denied. No seed/demo data.
#
# Order matters:
#   1. supabase/schema.sql             tables, triggers, storage buckets
#   2. supabase/security_hardening.sql grants + RLS policies (authoritative)
#
# Required in .env or .env.example:
#   SUPABASE_URL=https://xxxx.supabase.co
#   SUPABASE_ANON_KEY=eyJ...
#
# Optional:
#   SUPABASE_DB_URL=postgresql://...   # auto-apply DDL via psql
#
# Usage:
#   chmod +x scripts/setup_supabase.sh
#   ./scripts/setup_supabase.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
elif [[ -f .env.example ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env.example
  set +a
fi

SCHEMA_FILE="$ROOT_DIR/supabase/schema.sql"
SECURITY_FILE="$ROOT_DIR/supabase/security_hardening.sql"

need() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing $name. Add it to .env (see .env.example)." >&2
    exit 1
  fi
}

need SUPABASE_URL
need SUPABASE_ANON_KEY

echo "==> Sayge Supabase setup (schema + security, no seed data)"
echo "    URL: $SUPABASE_URL"

apply_sql() {
  if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
    return 1
  fi
  if ! command -v psql >/dev/null 2>&1; then
    echo "psql not found. Install PostgreSQL client tools, or run the SQL files in the SQL Editor." >&2
    return 1
  fi

  echo "==> 1/2 Applying schema..."
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE"

  # Single transaction: either every policy lands or none does, so the
  # database is never left half-open.
  echo "==> 2/2 Applying security policies..."
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --single-transaction -f "$SECURITY_FILE"
  return 0
}

# Anonymous requests must be rejected. A 200 here means data is exposed.
SENSITIVE_TABLES=(
  employees users clients dms_entities documents employee_purchase_orders
  expenses expense_categories invoices invoice_line_items
  proposals proposal_line_items payroll_runs payslip_records
  activity_log company_details roles
  pos_brands pos_products pos_purchases pos_purchase_items pos_price_rules
)

verify_anon_denied() {
  local failures=0
  echo "==> Verifying anonymous REST access is denied..."
  for table in "${SENSITIVE_TABLES[@]}"; do
    local code
    code="$(curl -sS -o /dev/null -w '%{http_code}' \
      "${SUPABASE_URL}/rest/v1/${table}?select=*&limit=1" \
      -H "apikey: ${SUPABASE_ANON_KEY}")"
    if [[ "$code" == "200" ]]; then
      echo "    FAIL ${table}: HTTP ${code} (readable by anon)"
      failures=$((failures + 1))
    else
      echo "    ok   ${table}: HTTP ${code}"
    fi
  done

  if (( failures > 0 )); then
    echo
    echo "==> ${failures} table(s) still readable anonymously." >&2
    echo "    Run supabase/security_hardening.sql, then re-run this script." >&2
    return 1
  fi
  echo "==> All checked tables deny anonymous reads."
}

if apply_sql; then
  echo "==> SQL applied."
else
  cat <<'EOF'
==> Could not auto-apply DDL (no SUPABASE_DB_URL / psql).

Do this in Supabase Dashboard → SQL Editor:
  See supabase/APPLY_ORDER.md for the full feature-pack list.
  Minimum:
  1. supabase/schema.sql
  2. Feature packs you need (expense categories, invoice/proposal status, …)
  3. supabase/security_hardening.sql  (always last)

Then re-run this script to verify anonymous access is denied.
EOF
fi

verify_anon_denied

cat <<'EOF'

==> Next steps
  - Full runbook: supabase/APPLY_ORDER.md
  - Inspect grants / RLS / policies / function ACLs: run
    supabase/security_verification.sql in the SQL Editor. Checks 1, 2, 3, 7, 8
    and 9 must return zero rows; the rest are inventories with the expected
    result noted above each query.
  - Create users in Authentication → Users. A public.users row is created
    automatically with the default Employee role; promote owners/admins in
    the dashboard. Login uses Supabase Auth — no demo credentials.
  - Keep SUPABASE_SERVICE_ROLE_KEY out of the app and out of version control.
    The Flutter client only ever uses SUPABASE_ANON_KEY.
EOF
echo "==> Done."

