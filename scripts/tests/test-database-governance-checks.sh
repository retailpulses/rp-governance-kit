#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/database-governance-checks.sh"
PASS=0
FAIL=0

run_case() {
  local name="$1" expected="$2" setup_fn="$3" mode="$4" body="${5:-}"
  local dir base head rc
  dir="$(mktemp -d)"
  (
    cd "$dir"
    git init -q
    git config user.email test@example.com
    git config user.name test
    mkdir -p docs supabase/migrations src
    echo '# governance' > docs/16_DATABASE_GOVERNANCE.md
    git add . && git commit -qm base
    base="$(git rev-parse HEAD)"
    "$setup_fn"
    git add . && git commit -qm head
    head="$(git rev-parse HEAD)"
    set +e
    GITHUB_BASE_SHA="$base" GITHUB_HEAD_SHA="$head" GITHUB_REPOSITORY="retailpulses/testrepo" PR_BODY="$body" bash "$SCRIPT" "$mode" >/tmp/dbgov-case.log 2>&1
    rc=$?
    set -e
    if [[ "$expected" == pass && "$rc" -eq 0 ]] || [[ "$expected" == fail && "$rc" -ne 0 ]]; then
      exit 0
    fi
    cat /tmp/dbgov-case.log >&2
    exit 1
  ) && { echo "PASS $name"; PASS=$((PASS+1)); } || { echo "FAIL $name"; FAIL=$((FAIL+1)); }
  rm -rf "$dir"
}

valid_migration() {
  cat > supabase/migrations/20260915010101_valid_change.sql <<'SQL'
-- Domain: test
-- Owner: retailpulses/testrepo
-- Affected: public.example
-- Change class: additive
-- Hosted write required: no
-- Consumers: none
create table if not exists example(id bigint);
SQL
  echo 'updated' >> docs/16_DATABASE_GOVERNANCE.md
}

invalid_name() {
  cat > supabase/migrations/bad.sql <<'SQL'
-- Domain: test
-- Owner: retailpulses/testrepo
-- Affected: public.example
-- Change class: additive
-- Hosted write required: no
create table example(id bigint);
SQL
  echo 'updated' >> docs/16_DATABASE_GOVERNANCE.md
}

runtime_read() {
  cat > src/read.ts <<'TS'
const rows = await supabase.from('x').select('*')
TS
}

advisory_n1() {
  cat > src/n1.ts <<'TS'
for (const id of ids) { await supabase.from('x').select('*') }
TS
}

run_case valid-migration pass valid_migration blocking
run_case invalid-migration-name fail invalid_name blocking
run_case egress-contract-missing fail runtime_read blocking
run_case egress-contract-present pass runtime_read blocking $'Stable client identity: test\nRead projection: explicit\nPagination / incremental cursor: cursor\nMeasured response bytes per invocation: 1\nProjected response bytes per day: 1\nEgress warning / critical thresholds: 1/2'
run_case advisory-remains-nonblocking pass advisory_n1 advisory

echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
