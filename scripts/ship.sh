#!/usr/bin/env bash
# Ship local commits through a PR so main branch rules (CI gates) stay satisfied.
# Usage:
#   ./scripts/ship.sh
#   ./scripts/ship.sh "optional PR title"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI first: brew install gh && gh auth login" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Not logged into gh. Run: gh auth login" >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
  echo "Detached HEAD — checkout a branch first." >&2
  exit 1
fi

# Always ship via a short-lived branch so required status checks can run.
STAMP="$(date +%Y%m%d-%H%M%S)"
SHIP_BRANCH="ship/${BRANCH}-${STAMP}"
TITLE="${1:-Ship ${BRANCH} (${STAMP})}"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit or stash before shipping." >&2
  exit 1
fi

BASE="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
BASE="${BASE:-main}"

echo "==> Creating ship branch ${SHIP_BRANCH} from ${BRANCH}"
git branch "$SHIP_BRANCH" HEAD
git push -u origin "$SHIP_BRANCH"

echo "==> Opening PR into ${BASE}"
PR_URL="$(gh pr create \
  --base "$BASE" \
  --head "$SHIP_BRANCH" \
  --title "$TITLE" \
  --body "$(cat <<EOF
## Summary
Automated ship of \`${BRANCH}\` via \`scripts/ship.sh\`.

## Test plan
- [ ] CI **Analyze & test** is green
EOF
)")"

echo "PR: ${PR_URL}"
PR_NUMBER="$(gh pr view "$PR_URL" --json number -q .number)"

echo "==> Waiting for required checks"
gh pr checks "$PR_NUMBER" --watch --fail-fast

echo "==> Merging"
gh pr merge "$PR_NUMBER" --merge --delete-branch

# Refresh local main if we were shipping from main.
if [[ "$BRANCH" == "$BASE" ]]; then
  echo "==> Syncing local ${BASE}"
  git fetch origin "$BASE"
  git checkout "$BASE"
  git pull --ff-only origin "$BASE"
  git branch -D "$SHIP_BRANCH" 2>/dev/null || true
fi

echo "==> Done"
