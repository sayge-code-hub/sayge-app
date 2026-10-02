#!/usr/bin/env bash
# Deploy the invite-employee Edge Function (service role stays on the server).
# Requires: https://supabase.com/dashboard/account/tokens → SUPABASE_ACCESS_TOKEN
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Set SUPABASE_ACCESS_TOKEN (Supabase Dashboard → Account → Access Tokens)" >&2
  exit 1
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:-grtkunxakranseakxofl}"

npx --yes supabase@2.20.5 functions deploy invite-employee \
  --project-ref "$PROJECT_REF" \
  --no-verify-jwt

echo "Deployed. In Supabase → Authentication → URL Configuration, add:"
echo "  Site URL: your Netlify origin"
echo "  Redirect URLs: https://YOUR_SITE/set-password"
