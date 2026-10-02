#!/usr/bin/env bash
# Applies Sayge schema (tables + RLS). No seed/demo data.
#
# Required in .env or .env.example:
#   SUPABASE_URL=https://xxxx.supabase.co
#   SUPABASE_ANON_KEY=eyJ...
#
# Optional:
#   SUPABASE_DB_URL=postgresql://...   # auto-apply DDL via psql
#   SUPABASE_SERVICE_ROLE_KEY=eyJ...   # for verify with elevated key
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

need() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing $name. Add it to .env (see .env.example)." >&2
    exit 1
  fi
}

need SUPABASE_URL
need SUPABASE_ANON_KEY

echo "==> Sayge Supabase setup (schema only, no seed data)"
echo "    URL: $SUPABASE_URL"

apply_schema() {
  if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
    if ! command -v psql >/dev/null 2>&1; then
      echo "psql not found. Install PostgreSQL client tools, or run schema.sql in the SQL Editor." >&2
      return 1
    fi
    echo "==> Applying schema via SUPABASE_DB_URL..."
    psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE"
    return 0
  fi
  return 1
}

verify() {
  local key="${SUPABASE_SERVICE_ROLE_KEY:-$SUPABASE_ANON_KEY}"
  echo "==> Verifying REST access..."
  for table in roles users clients employees dms_entities documents activity_log; do
    local code
    code="$(curl -sS -o /dev/null -w '%{http_code}' \
      "${SUPABASE_URL}/rest/v1/${table}?select=*&limit=1" \
      -H "apikey: ${key}" \
      -H "Authorization: Bearer ${key}")"
    echo "    ${table}: HTTP ${code}"
  done
}

if apply_schema; then
  echo "==> Schema applied."
else
  cat <<EOF
==> Could not auto-apply DDL (no SUPABASE_DB_URL / psql).

Do this in Supabase Dashboard → SQL Editor:
  1. Open supabase/schema.sql
  2. Paste & Run

Then re-run this script to verify REST access.
EOF
fi

verify

cat <<EOF

==> Flutter
Put the same URL + anon key into .env (bundled by the app; gitignored):

SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

Create users in Authentication → Users (e.g. aditya.rana@sayge.in).
Login uses Supabase Auth — no demo credentials.

EOF
echo "==> Done."
