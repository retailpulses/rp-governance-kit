#!/usr/bin/env bash
set -uo pipefail

MODE="${1:-}"
BASE="${GITHUB_BASE_SHA:-${BASE_SHA:-}}"
HEAD="${GITHUB_HEAD_SHA:-${HEAD_SHA:-HEAD}}"
PR_BODY="${PR_BODY:-}"
REPO_NAME="${GITHUB_REPOSITORY:-unknown/unknown}"

if [[ -z "$MODE" || -z "$BASE" || -z "$HEAD" ]]; then
  echo "usage: database-governance-checks.sh <blocking|production-gate|advisory>" >&2
  echo "requires GITHUB_BASE_SHA/BASE_SHA and GITHUB_HEAD_SHA/HEAD_SHA" >&2
  exit 2
fi

changed_files() { git diff --name-only "$BASE"..."$HEAD" || true; }
new_migrations() { git diff --name-only --diff-filter=A "$BASE"..."$HEAD" -- 'supabase/migrations/*.sql' || true; }

run_check() {
  local label="$1" fn="$2"
  echo ""
  echo "===== $label ====="
  if "$fn"; then
    echo "[$label] OK"
    return 0
  else
    local rc=$?
    echo "[$label] FAILED (rc=$rc)"
    return "$rc"
  fi
}

check_egress_contract() {
  local changed file content failed=0 field
  local -a read_paths=()
  changed="$(changed_files)"
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    echo "$file" | grep -qE '\.(js|mjs|cjs|ts|tsx|py)$' || continue
    echo "$file" | grep -qE '(^|/)(test|tests|fixtures|dist|vendor|node_modules)(/|$)|\.(test|spec)\.' && continue
    content="$(git diff "$BASE"..."$HEAD" -- "$file")"
    if echo "$content" | grep -qE '^\+.*(\.select\(|select=|/rest/v1/|createClient\(|supabase)' && \
       echo "$content" | grep -qE '^\+.*(select|GET|fetch|\.from\()'; then
      read_paths+=("$file")
    fi
  done <<< "$changed"
  if [[ ${#read_paths[@]} -eq 0 ]]; then
    echo "No changed runtime Supabase read paths: OK"
    return 0
  fi
  local -a required=(
    "Stable client identity"
    "Read projection"
    "Pagination / incremental cursor"
    "Measured response bytes per invocation"
    "Projected response bytes per day"
    "Egress warning / critical thresholds"
  )
  for field in "${required[@]}"; do
    if ! echo "$PR_BODY" | grep -qiE "${field}[^:]*:[[:space:]]*[^[:space:]]"; then
      echo "::error::Runtime database read changed but PR field is missing or blank: $field"
      failed=1
    fi
  done
  for file in "${read_paths[@]}"; do
    echo "::notice file=$file::Runtime Supabase read path changed; egress contract required."
  done
  return "$failed"
}

check_migration_naming() {
  local migrations fname failed=0 migration
  migrations="$(new_migrations)"
  [[ -z "$migrations" ]] && { echo "No new migration files: OK"; return 0; }
  echo "$migrations"
  while IFS= read -r migration; do
    [[ -z "$migration" ]] && continue
    fname="$(basename "$migration")"
    if ! echo "$fname" | grep -qE '^[0-9]{14}_[a-z0-9_]+\.sql$' && \
       ! echo "$fname" | grep -qE '^[0-9]{1,13}_shared_remote\.sql$'; then
      echo "::error file=$migration::Migration filename does not match required pattern: YYYYMMDDHHMMSS_description.sql"
      failed=1
    fi
  done <<< "$migrations"
  return "$failed"
}

check_duplicate_timestamps_local() {
  local migrations dups migration new_ts existing count
  migrations="$(new_migrations)"
  [[ -z "$migrations" ]] && { echo "No new migration files: OK"; return 0; }
  dups="$(echo "$migrations" | while IFS= read -r f; do basename "$f" | grep -oE '^[0-9]{14}'; done | sort | uniq -d)"
  if [[ -n "$dups" ]]; then
    echo "::error::Duplicate migration timestamps found among new files: $dups"
    return 1
  fi
  while IFS= read -r migration; do
    [[ -z "$migration" ]] && continue
    new_ts="$(basename "$migration" | grep -oE '^[0-9]{14}' || true)"
    [[ -z "$new_ts" ]] && continue
    existing="$(git ls-files 'supabase/migrations/'"$new_ts"'_*.sql' 2>/dev/null || true)"
    count="$(echo "$existing" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [[ "$count" -gt 1 ]]; then
      echo "::error file=$migration::Timestamp $new_ts already exists in repository."
      return 1
    fi
  done <<< "$migrations"
  echo "No duplicate timestamps among new migrations: OK"
}

check_migration_docs_impact() {
  local changed migrations docs
  changed="$(changed_files)"
  migrations="$(echo "$changed" | grep 'supabase/migrations/' || true)"
  docs="$(echo "$changed" | grep -E '^docs/|^README\.md' || true)"
  if [[ -n "$migrations" ]]; then
    if [[ ! -f docs/16_DATABASE_GOVERNANCE.md ]]; then
      echo "::error::Migration files changed but docs/16_DATABASE_GOVERNANCE.md is not installed."
      return 1
    fi
    if [[ -z "$docs" ]]; then
      echo "::error::Migration files changed but no documentation was updated."
      return 1
    fi
  fi
  echo "Migration docs impact: OK"
}

check_secret_detection() {
  local changed file content failed=0
  changed="$(changed_files)"
  [[ -z "$changed" ]] && { echo "No changed files: OK"; return 0; }
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" == *.md || "$file" == *.yaml || "$file" == *.yml || "$file" == *.json || "$file" == *.toml || "$file" == .gitignore || "$file" == .github/* ]] && continue
    content="$(cat "$file" 2>/dev/null || true)"
    [[ -z "$content" ]] && continue
    if echo "$content" | grep -qE 'postgres(ql)?://[^@]+:[^@]+@'; then echo "::error file=$file::PostgreSQL connection URL with embedded credentials"; failed=1; fi
    if echo "$content" | grep -qE '(service_role|SERVICE_ROLE).*(eyJ[A-Za-z0-9_\-]{100,})'; then echo "::error file=$file::service_role key pattern detected"; failed=1; fi
    if echo "$content" | grep -qE 'sbp_[a-f0-9]{40,}'; then echo "::error file=$file::Supabase access token pattern detected"; failed=1; fi
    if echo "$content" | grep -qE '(eyJ[A-Za-z0-9_\-]{50,})' && ! echo "$file" | grep -qE '\.env|config|\.example|\.sample|\.test'; then
      echo "::error file=$file::JWT token pattern detected outside config file"; failed=1
    fi
  done <<< "$changed"
  return "$failed"
}

check_migration_header() {
  local migrations migration header failed=0
  local -a required=("Domain:" "Owner:" "Affected:" "Change class:" "Hosted write required:")
  migrations="$(new_migrations)"
  [[ -z "$migrations" ]] && { echo "No new migration files: OK"; return 0; }
  while IFS= read -r migration; do
    [[ -z "$migration" || ! -f "$migration" ]] && continue
    for header in "${required[@]}"; do
      if ! head -20 "$migration" | grep -q "$header"; then
        echo "::error file=$migration::Missing required migration header: $header"
        failed=1
      fi
    done
  done <<< "$migrations"
  return "$failed"
}

check_cross_domain_owner() {
  local migrations repo_lower migration mig_owner mig_owner_lower has_issue failed=0
  migrations="$(new_migrations)"
  [[ -z "$migrations" ]] && { echo "No new migration files: OK"; return 0; }
  repo_lower="$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r migration; do
    [[ -z "$migration" || ! -f "$migration" ]] && continue
    mig_owner="$(head -20 "$migration" | grep -E '^-- Owner:' | sed 's/-- Owner:[[:space:]]*//' | xargs || true)"
    [[ -z "$mig_owner" ]] && continue
    mig_owner_lower="$(echo "$mig_owner" | tr '[:upper:]' '[:lower:]')"
    if [[ "$mig_owner_lower" != *"$repo_lower"* ]]; then
      if ! grep -qE -- '-- Cross-domain exception:|cross.domain.exception' "$migration" 2>/dev/null; then
        echo "::error file=$migration::Migration declares owner '$mig_owner' but this repository is '$repo_lower'."
        failed=1
      else
        has_issue="$(echo "$PR_BODY" | grep -cE '(Refs|Closes|Fixes|Resolves)[[:space:]]+#[0-9]+' || true)"
        [[ "$has_issue" -eq 0 ]] && echo "::warning file=$migration::Cross-domain exception present but no Issue reference found in PR."
      fi
    fi
  done <<< "$migrations"
  return "$failed"
}

check_runtime_impact_declaration() {
  local changed file content write_indicators=0 has_workload_category has_registry workload_yaml=false local_decl=false
  local -a signals=()
  changed="$(changed_files)"
  [[ -z "$changed" ]] && { echo "No changed files: OK"; return 0; }
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    echo "$file" | grep -qE '\.(md|yaml|yml|json|toml|txt|env|example|sample)$' && continue
    content="$(cat "$file" 2>/dev/null || true)"; [[ -z "$content" ]] && continue
    if echo "$content" | grep -qE '\.(insert|upsert|update|delete)\(|\.from\([^)]+\)\.(insert|upsert|update|delete)'; then signals+=("$file: database write operation detected"); ((write_indicators+=1)); fi
    if echo "$content" | grep -qE 'batchSize|batch_size|BATCH_SIZE|bulkInsert|bulk.*insert|bulk.*update|bulk.*delete'; then signals+=("$file: bulk/batch database operation detected"); ((write_indicators+=1)); fi
    if echo "$file" | grep -qE 'cron|scheduled|trigger' && echo "$content" | grep -qE '(supabase|pg|postgres|database|db)'; then signals+=("$file: scheduled database access detected"); ((write_indicators+=1)); fi
    if echo "$file" | grep -qiE 'worker' && echo "$content" | grep -qE '(supabase|createClient|\.from\()'; then signals+=("$file: Worker database access detected"); ((write_indicators+=1)); fi
    if echo "$content" | grep -qE '(supabase|pg|postgres|database|db)' && echo "$content" | grep -qE '(\.from\(|\.select\(|\.insert\(|\.upsert\(|\.update\(|\.delete\(|createClient)' && ! echo "$file" | grep -qE '\.(test|spec)\.'; then
      signals+=("$file: runtime script database access detected"); ((write_indicators+=1))
    fi
  done <<< "$changed"
  [[ "$write_indicators" -eq 0 ]] && { echo "No database-writing code patterns detected: OK"; return 0; }
  printf '  - %s\n' "${signals[@]}"
  has_workload_category="$(echo "$PR_BODY" | grep -qiE 'Workload category:' && echo yes || echo no)"
  has_registry="$(echo "$PR_BODY" | grep -qiE '(Workload registry|DATABASE_WORKLOADS)' && echo yes || echo no)"
  [[ -f docs/DATABASE_WORKLOADS.yaml ]] && workload_yaml=true
  if [[ -f docs/16_DATABASE_GOVERNANCE.local.md ]] && grep -qiE '(Workload|workload|cron|sync|import|backfill)' docs/16_DATABASE_GOVERNANCE.local.md 2>/dev/null; then local_decl=true; fi
  if [[ "$has_registry" == yes ]]; then
    echo "Runtime workload declaration found in PR body: OK"
  elif [[ "$workload_yaml" == true ]]; then
    echo "docs/DATABASE_WORKLOADS.yaml exists: workload registry available"
    [[ "$has_workload_category" == no ]] && echo "::warning::Database-writing code detected but PR body does not include Runtime Database Impact section."
  elif [[ "$local_decl" == true ]]; then
    echo "Workload declaration found in docs/16_DATABASE_GOVERNANCE.local.md: OK"
  else
    echo "::warning::Database-writing code patterns detected without workload declaration."
  fi
  return 0
}

check_n_plus_one() {
  local changed file content signals=0 has_db has_loop has_bulk
  changed="$(changed_files)"
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" == *.md || "$file" == *.yaml || "$file" == *.yml || "$file" == *.json ]] && continue
    content="$(cat "$file" 2>/dev/null || true)"; [[ -z "$content" ]] && continue
    has_db=false; has_loop=false; has_bulk=false
    echo "$content" | grep -qE '(\.from\(|\.select\(|createClient|supabase|pg\.|postgres\b)' && has_db=true
    echo "$content" | grep -qE '\b(for|while|forEach|\.map\s*\(|for\s*\(|for\s+const|for\s+let|for\s+var|\.each\()' && has_loop=true
    echo "$content" | grep -qiE '(bulk|batch|Promise\.all|\.in\(|IN\s*\()' && has_bulk=true
    if [[ "$has_db" == true && "$has_loop" == true && "$has_bulk" == false ]]; then echo "::warning file=$file::Possible N+1 lookup pattern"; ((signals+=1)); fi
  done <<< "$changed"
  echo "$signals possible N+1 pattern(s) found"
  return 0
}

check_change_aware_write() {
  local changed file content signals=0 has_read has_write declared
  changed="$(changed_files)"
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" == *.md || "$file" == *.yaml || "$file" == *.yml || "$file" == *.json ]] && continue
    content="$(cat "$file" 2>/dev/null || true)"; [[ -z "$content" ]] && continue
    has_read=false; has_write=false; declared=false
    echo "$content" | grep -qE '(\.select\(|SELECT\s+)' && has_read=true
    echo "$content" | grep -qE '(\.upsert\(|\.update\(|\.insert\(|INSERT\s+|UPDATE\s+|\.save\()' && has_write=true
    echo "$PR_BODY" | grep -qiE 'change.aware|freshness_strategy|unchanged.write' && declared=true
    [[ -f docs/16_DATABASE_GOVERNANCE.local.md ]] && grep -qiE 'change.aware|freshness_strategy|unchanged.write' docs/16_DATABASE_GOVERNANCE.local.md 2>/dev/null && declared=true
    if [[ "$has_read" == true && "$has_write" == true && "$declared" == false ]]; then echo "::warning file=$file::Change-aware write review recommended"; ((signals+=1)); fi
  done <<< "$changed"
  echo "$signals change-aware write concern(s) found"
  return 0
}

check_access_path() {
  local changed file content signals=0 has_direct=false
  changed="$(changed_files)"
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" == *.md || "$file" == *.yaml || "$file" == *.yml || "$file" == *.json || "$file" == *.toml ]] && continue
    content="$(cat "$file" 2>/dev/null || true)"; [[ -z "$content" ]] && continue
    has_direct=false
    echo "$content" | grep -qE '(createClient|supabase\.from|pg\.connect|Pool\(|new pg\.|psycopg|postgresql://)' && has_direct=true
    if [[ "$has_direct" == true ]]; then echo "::notice file=$file::Database client import detected."; ((signals+=1)); fi
  done <<< "$changed"
  if [[ "$signals" -gt 0 ]] && ! echo "$PR_BODY" | grep -qiE 'access.path|internal_api|supavisor|postgrest|direct_postgres'; then
    echo "::warning::Database client imports detected without access path declaration."
  fi
  return 0
}

check_run_health_independence() {
  local changed file signals=0
  changed="$(changed_files)"
  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" == *.md || "$file" == *.yaml || "$file" == *.yml || "$file" == *.json ]] && continue
    if echo "$file" | grep -qiE 'cron|scheduled|trigger|timer'; then
      echo "::notice file=$file::Scheduled/cron workload detected; verify current-run health independence."
      ((signals+=1))
    fi
  done <<< "$changed"
  echo "$signals scheduled workload file(s) detected"
  return 0
}

check_migration_warnings() {
  local migrations migration fname warnings=0 type_files
  migrations="$(git diff --name-only "$BASE"..."$HEAD" -- 'supabase/migrations/*.sql' || true)"
  while IFS= read -r migration; do
    [[ -z "$migration" || ! -f "$migration" ]] && continue
    [[ ! -s "$migration" ]] && { echo "::warning file=$migration::Empty migration file detected."; ((warnings+=1)); }
    fname="$(basename "$migration")"
    if echo "$fname" | grep -q '_remote\.sql$' && [[ -s "$migration" ]]; then echo "::warning file=$migration::_remote.sql contains content."; ((warnings+=1)); fi
    if head -20 "$migration" | grep -qE 'CREATE TABLE' && [[ -f docs/16_DATABASE_GOVERNANCE.local.md ]] && ! grep -qE 'access.class|access_class' docs/16_DATABASE_GOVERNANCE.local.md 2>/dev/null; then
      echo "::warning file=$migration::New table created but no access class declaration found."; ((warnings+=1))
    fi
  done <<< "$migrations"
  if [[ -n "$migrations" && -f docs/16_DATABASE_GOVERNANCE.local.md ]] && ! grep -qE '(supabase.cli|CLI version)' docs/16_DATABASE_GOVERNANCE.local.md 2>/dev/null; then
    echo "::warning::Supabase CLI version not recorded."; ((warnings+=1))
  fi
  if [[ -n "$migrations" ]]; then
    type_files="$(changed_files | grep -E 'types|database\.ts|supabase\.ts' || true)"
    if [[ -z "$type_files" && -f docs/16_DATABASE_GOVERNANCE.local.md ]] && ! grep -qE 'generated.types.*exempt' docs/16_DATABASE_GOVERNANCE.local.md 2>/dev/null; then
      echo "::warning::Migration changed but no generated type files updated."; ((warnings+=1))
    fi
  fi
  echo "$warnings migration warning(s) found"
  return 0
}

check_org_duplicate_timestamps() {
  local migrations migration ts
  migrations="$(new_migrations)"
  [[ -z "$migrations" ]] && { echo "No new migration files: OK"; return 0; }
  echo "::warning::Organization-wide duplicate timestamp scan requires cross-repo access."
  while IFS= read -r migration; do
    [[ -z "$migration" ]] && continue
    ts="$(basename "$migration" | grep -oE '^[0-9]{14}' || true)"
    [[ -n "$ts" ]] && echo "::warning::  $ts - verify uniqueness across all Retailpulses repos"
  done <<< "$migrations"
  return 0
}

case "$MODE" in
  blocking)
    failures=0
    run_check "BLOCKING | Supabase Egress Contract" check_egress_contract || failures=1
    run_check "BLOCKING | Migration Naming" check_migration_naming || failures=1
    run_check "BLOCKING | Duplicate Timestamps (Local)" check_duplicate_timestamps_local || failures=1
    run_check "BLOCKING | Migration Docs Impact" check_migration_docs_impact || failures=1
    run_check "BLOCKING | Secret Detection" check_secret_detection || failures=1
    run_check "BLOCKING | Migration Header Check" check_migration_header || failures=1
    run_check "BLOCKING | Cross-Domain Owner Check" check_cross_domain_owner || failures=1
    exit "$failures"
    ;;
  production-gate)
    run_check "PRODUCTION_GATE | Runtime Impact Declaration" check_runtime_impact_declaration
    ;;
  advisory)
    run_check "ADVISORY | N+1 Lookup Detection" check_n_plus_one
    run_check "ADVISORY | Change-Aware Write Detection" check_change_aware_write
    run_check "ADVISORY | Access Path Enforcement" check_access_path
    run_check "ADVISORY | Run Health Independence Check" check_run_health_independence
    run_check "ADVISORY | Migration Warnings" check_migration_warnings
    run_check "ADVISORY | Org-Wide Duplicate Timestamps" check_org_duplicate_timestamps
    ;;
  *) echo "unknown mode: $MODE" >&2; exit 2 ;;
esac
