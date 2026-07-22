#!/usr/bin/env bash
# test_inquiry_management_contract.sh — semantic contract for Phase 1 inquiry governance

echo "--- Inquiry management Phase 1 contract ---"

OWNERSHIP="$KIT_DIR/docs/DATABASE_OWNERSHIP.yaml"
ACCESS="$KIT_DIR/docs/DATABASE_ACCESS_POLICY.yaml"
CAPABILITIES="$KIT_DIR/docs/DATABASE_CAPABILITIES.yaml"
WORKLOADS="$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"

section() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    $0 == "  " key ":" { inside = 1 }
    inside && $0 != "  " key ":" && /^  [a-zA-Z0-9_\/:-]+:$/ { exit }
    inside { print }
  ' "$file"
}

subsection() {
  local content="$1"
  local start="$2"
  local stop="$3"
  printf '%s\n' "$content" | sed -n "/^      $start:/,/^      $stop:/p"
}

INQUIRY_OWNERSHIP=$(section "$OWNERSHIP" inquiry_management)
TABLES=$(subsection "$INQUIRY_OWNERSHIP" tables views | grep -c '^        - ' || true)
VIEWS=$(subsection "$INQUIRY_OWNERSHIP" views functions | grep -c '^        - ' || true)

if [[ "$TABLES" -eq 4 ]]; then
  pass "inquiry_management owns exactly four Phase 1 tables"
else
  fail "inquiry_management must own exactly four Phase 1 tables (found $TABLES)"
fi

for table in inquiries inquiry_product_links inquiry_knowledge_links knowledge_articles; do
  if printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q "^        - $table$"; then
    pass "inquiry_management table registered: $table"
  else
    fail "inquiry_management table missing: $table"
  fi
done

if [[ "$VIEWS" -eq 2 ]] && \
   printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q '^        - inquiry_list_vw$' && \
   printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q '^        - inquiry_detail_vw$'; then
  pass "inquiry_management owns exactly the two Phase 1 views"
else
  fail "inquiry_management must own inquiry_list_vw and inquiry_detail_vw only"
fi

if printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q '^        - inquiry_management_set_updated_at$'; then
  pass "inquiry-owned updated_at function registered"
else
  fail "inquiry_management_set_updated_at function missing"
fi

for trigger in \
  'trg_inquiries_updated_at ON inquiries' \
  'trg_knowledge_articles_updated_at ON knowledge_articles'; do
  if printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q "^        - $trigger$"; then
    pass "inquiry trigger registered: $trigger"
  else
    fail "inquiry trigger missing: $trigger"
  fi
done

for dependency in product_variants platform_accounts; do
  if printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q "$dependency"; then
    pass "UUID owner-domain dependency documented: $dependency"
  else
    fail "UUID owner-domain dependency missing: $dependency"
  fi
done

PRODUCT_OWNERSHIP=$(section "$OWNERSHIP" product_catalog)
PRODUCT_CAPABILITIES=$(section "$CAPABILITIES" product_catalog)
for consumer in retailpulses/inquiry-automation retailpulses/workers; do
  if printf '%s\n' "$PRODUCT_OWNERSHIP" | grep -q -- "- $consumer"; then
    pass "product_catalog ownership lists consumer: $consumer"
  else
    fail "product_catalog ownership missing consumer: $consumer"
  fi
  if printf '%s\n' "$PRODUCT_CAPABILITIES" | grep -q "^      $consumer:$"; then
    pass "product_catalog capability lists consumer: $consumer"
  else
    fail "product_catalog capability missing consumer: $consumer"
  fi
done

INQUIRY_ACCESS=$(section "$ACCESS" retailpulses/inquiry-automation)
if printf '%s\n' "$INQUIRY_ACCESS" | grep -A7 '^    product_catalog:' | grep -q 'service_role_forbidden: false'; then
  pass "inquiry-automation product catalog access matches Phase 1 worker_only service_role"
else
  fail "inquiry-automation product_catalog access must match the Phase 1 worker_only service_role"
fi

RPAGENT_ACCESS=$(section "$ACCESS" retailpulses/RPagentOS)
if printf '%s\n' "$RPAGENT_ACCESS" | grep -A8 '^    inquiry_management:' | grep -q 'service_role_forbidden: true'; then
  pass "RPagentOS temporary inquiry access is read-only scoped"
else
  fail "RPagentOS temporary inquiry access must forbid service_role"
fi

if printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q '2026-10-31' && \
   printf '%s\n' "$INQUIRY_OWNERSHIP" | grep -q 'completeness guard'; then
  pass "legacy compatibility dependency has guard and removal date"
else
  fail "legacy compatibility dependency must name completeness guard and removal date"
fi

INQUIRY_WORKLOADS=(
  inquiry_mail_ingestion
  inquiry_automation_worker
  inquiry_dashboard_mutations
  inquiry_vps_enrichment
  inquiry_follow_up
  inquiry_historical_migration
)

for workload in "${INQUIRY_WORKLOADS[@]}"; do
  BLOCK=$(section "$WORKLOADS" "$workload")
  if [[ -z "$BLOCK" ]]; then
    fail "inquiry workload missing: $workload"
    continue
  fi

  pass "inquiry workload registered: $workload"
  for required in \
    'risk_level: high' \
    'credential_class: service_role' \
    'fail_closed: true' \
    'expected_volume_rows_max:' \
    'batch_size_max:' \
    'cursor_strategy:' \
    'max_rows_per_invocation:' \
    'formula:' \
    'error_recording:' \
    'rollout_gates:' \
    'monitoring:' \
    'local_inventory_ref:'; do
    if printf '%s\n' "$BLOCK" | grep -q "$required"; then
      pass "$workload declares $required"
    else
      fail "$workload missing $required"
    fi
  done
done

VPS=$(section "$WORKLOADS" inquiry_vps_enrichment)
if printf '%s\n' "$VPS" | grep -q '^    access_path: postgrest$' && \
   ! printf '%s\n' "$VPS" | grep -q 'direct_postgres'; then
  pass "VPS enrichment uses PostgREST only"
else
  fail "VPS enrichment must use PostgREST, never direct_postgres"
fi

HISTORICAL=$(section "$WORKLOADS" inquiry_historical_migration)
if printf '%s\n' "$HISTORICAL" | grep -q 'category: backfills' && \
   printf '%s\n' "$HISTORICAL" | grep -q 'coordinated_RPagentOS_mercari_inquiries_retirement_PR'; then
  pass "historical backfill declares coordinated legacy retirement dependency"
else
  fail "historical backfill missing category or legacy retirement dependency"
fi

if grep -q 'method: config_flag' "$WORKLOADS" && grep -q 'method: process_signal' "$WORKLOADS"; then
  pass "fail-closed config and process kill-switch methods are represented"
else
  fail "inquiry workloads require config_flag and process_signal kill-switch methods"
fi

if grep -q 'Fail-closed config flag' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md" && \
   grep -q 'Process signal' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "canonical policy documents both inquiry kill-switch types"
else
  fail "canonical policy must document config_flag and process_signal kill switches"
fi
