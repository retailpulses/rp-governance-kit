#!/usr/bin/env bash
# test_sync_governance.sh — verify sync workload governance artifacts

echo "--- Sync governance policy ---"

CENTRAL="$KIT_DIR/docs/SYNC_WORKLOAD_GOVERNANCE.md"
TEMPLATE_17="$KIT_DIR/templates/docs/17_SYNC_WORKLOAD_GOVERNANCE.md"
TEMPLATE_INV="$KIT_DIR/templates/docs/SYNC_JOB_INVENTORY.template.md"
INSTALLER="$KIT_DIR/bin/rp-governance-install"

# ── Central policy checks ──

if [[ -f "$CENTRAL" ]]; then
  pass "SYNC_WORKLOAD_GOVERNANCE.md exists"

  if grep -q '## 1. Scope' "$CENTRAL"; then
    pass "Policy has Scope section"
  else
    fail "Policy missing Scope section"
  fi

  if grep -q '## 2. Workload Classification' "$CENTRAL"; then
    pass "Policy has Workload Classification section"
  else
    fail "Policy missing Workload Classification section"
  fi

  if grep -q 'pull.*Ingest data\|push.*Send internal data\|reconcile.*Compare two systems\|projection.*Transform data' "$CENTRAL"; then
    pass "Policy defines workload kinds"
  else
    fail "Policy missing workload kind definitions"
  fi

  if grep -q 'read_only.*No writes\|internal_write.*Writes only to internal\|external_write.*Writes to external' "$CENTRAL"; then
    pass "Policy defines effect levels"
  else
    fail "Policy missing effect level definitions"
  fi

  if grep -q 'lower_snake_case' "$CENTRAL"; then
    pass "Policy specifies lower_snake_case for workload IDs"
  else
    fail "Policy missing snake_case ID convention"
  fi

  if grep -q 'Agent Preflight Checklist' "$CENTRAL"; then
    pass "Policy has Agent Preflight Checklist"
  else
    fail "Policy missing Agent Preflight Checklist"
  fi

  # Check all 10 checklist items are present
  if grep -q 'Read.*SYNC_JOB_INVENTORY' "$CENTRAL"; then
    pass "Preflight step 1: Read inventory"
  else
    fail "Preflight missing step 1: Read inventory"
  fi

  if grep -q 'Identify the existing workload ID' "$CENTRAL"; then
    pass "Preflight step 2: Identify workload ID"
  else
    fail "Preflight missing step 2: Identify workload ID"
  fi

  if grep -q 'Search for existing jobs' "$CENTRAL"; then
    pass "Preflight step 3: Search for existing jobs"
  else
    fail "Preflight missing step 3: Search for existing jobs"
  fi

  if grep -q 'Inspect the canonical source' "$CENTRAL"; then
    pass "Preflight step 4: Inspect canonical source"
  else
    fail "Preflight missing step 4: Inspect canonical source"
  fi

  if grep -q 'Identify overlapping writers' "$CENTRAL"; then
    pass "Preflight step 5: Identify overlapping writers"
  else
    fail "Preflight missing step 5: Identify overlapping writers"
  fi

  if grep -q 'Confirm idempotency.*retry.*checkpoint.*kill-switch' "$CENTRAL"; then
    pass "Preflight step 6: Confirm safety behaviors"
  else
    fail "Preflight missing step 6: Confirm safety behaviors"
  fi

  if grep -q 'Verify runtime state' "$CENTRAL"; then
    pass "Preflight step 7: Verify runtime state"
  else
    fail "Preflight missing step 7: Verify runtime state"
  fi

  if grep -q 'Update the inventory in the same PR' "$CENTRAL"; then
    pass "Preflight step 8: Update inventory in same PR"
  else
    fail "Preflight missing step 8: Update inventory in same PR"
  fi

  if grep -q 'Report.*mismatches.*drift' "$CENTRAL"; then
    pass "Preflight step 9: Report drift"
  else
    fail "Preflight missing step 9: Report drift"
  fi

  if grep -q 'cutover.*retirement' "$CENTRAL"; then
    pass "Preflight step 10: Include cutover/retirement steps"
  else
    fail "Preflight missing step 10: Cutover/retirement steps"
  fi

  # Policy must reference database governance boundary
  if grep -q 'DATABASE_GOVERNANCE.md\|database.*governance' "$CENTRAL"; then
    pass "Policy references database governance boundary"
  else
    fail "Policy missing database governance boundary reference"
  fi

  # Policy size check (150–250 lines target, allow some margin)
  POLICY_LINES=$(wc -l < "$CENTRAL")
  if [[ "$POLICY_LINES" -le 350 ]]; then
    pass "Policy line count ($POLICY_LINES) is within reasonable range"
  else
    fail "Policy line count ($POLICY_LINES) exceeds 350-line limit"
  fi
else
  fail "SYNC_WORKLOAD_GOVERNANCE.md not found"
fi

# ── Template checks ──

echo ""
echo "--- Sync governance templates ---"

# 17_SYNC_WORKLOAD_GOVERNANCE.md template
if [[ -f "$TEMPLATE_17" ]]; then
  pass "17_SYNC_WORKLOAD_GOVERNANCE.md template exists"

  if grep -q '__REF__' "$TEMPLATE_17"; then
    pass "17 template has __REF__ placeholder"
  else
    fail "17 template missing __REF__ placeholder"
  fi

  if grep -q '__INSTALLED_AT__' "$TEMPLATE_17"; then
    pass "17 template has __INSTALLED_AT__ placeholder"
  else
    fail "17 template missing __INSTALLED_AT__ placeholder"
  fi

  if grep -q 'SYNC_WORKLOAD_GOVERNANCE.md' "$TEMPLATE_17"; then
    pass "17 template links to canonical policy"
  else
    fail "17 template missing link to canonical policy"
  fi

  if grep -q 'Agent Preflight Checklist' "$TEMPLATE_17"; then
    pass "17 template includes preflight checklist"
  else
    fail "17 template missing preflight checklist"
  fi

  if grep -q 'SYNC_JOB_INVENTORY.md' "$TEMPLATE_17"; then
    pass "17 template references local inventory"
  else
    fail "17 template missing local inventory reference"
  fi
else
  fail "17_SYNC_WORKLOAD_GOVERNANCE.md template not found"
fi

# SYNC_JOB_INVENTORY.template.md
if [[ -f "$TEMPLATE_INV" ]]; then
  pass "SYNC_JOB_INVENTORY.template.md exists"

  if grep -q 'Workload ID' "$TEMPLATE_INV"; then
    pass "Inventory template has workload ID column"
  else
    fail "Inventory template missing workload ID column"
  fi

  if grep -q 'Kind / Effect' "$TEMPLATE_INV"; then
    pass "Inventory template has Kind/Effect column"
  else
    fail "Inventory template missing Kind/Effect column"
  fi

  if grep -q 'lifecycle_state\|Lifecycle State' "$TEMPLATE_INV"; then
    pass "Inventory template defines lifecycle states"
  else
    fail "Inventory template missing lifecycle state definitions"
  fi

  if grep -q 'deployment_state\|Deployment State' "$TEMPLATE_INV"; then
    pass "Inventory template defines deployment states"
  else
    fail "Inventory template missing deployment state definitions"
  fi

  if grep -q 'operational_state\|Operational State' "$TEMPLATE_INV"; then
    pass "Inventory template defines operational states"
  else
    fail "Inventory template missing operational state definitions"
  fi

  if grep -q 'Governance drift\|governance drift' "$TEMPLATE_INV"; then
    pass "Inventory template addresses governance drift"
  else
    fail "Inventory template missing governance drift reference"
  fi
else
  fail "SYNC_JOB_INVENTORY.template.md not found"
fi

# ── Installer checks ──

echo ""
echo "--- Installer sync governance support ---"

if [[ -f "$INSTALLER" ]]; then
  if grep -q '\-\-with-sync-governance' "$INSTALLER"; then
    pass "Installer supports --with-sync-governance flag"
  else
    fail "Installer missing --with-sync-governance flag"
  fi

  if grep -q 'WITH_SYNC_GOVERNANCE' "$INSTALLER"; then
    pass "Installer has WITH_SYNC_GOVERNANCE variable"
  else
    fail "Installer missing WITH_SYNC_GOVERNANCE variable"
  fi

  if grep -q '17_SYNC_WORKLOAD_GOVERNANCE.md' "$INSTALLER"; then
    pass "Installer copies 17_SYNC_WORKLOAD_GOVERNANCE.md"
  else
    fail "Installer missing 17_SYNC_WORKLOAD_GOVERNANCE.md copy"
  fi

  if grep -q 'SYNC_JOB_INVENTORY.template.md' "$INSTALLER"; then
    pass "Installer references inventory template"
  else
    fail "Installer missing inventory template reference"
  fi

  # Installer must NOT overwrite existing inventory
  if grep -q 'not overwriting\|never overwrite\|not.*exist.*inventory' "$INSTALLER" || \
     grep -q '! -f.*SYNC_JOB_INVENTORY' "$INSTALLER"; then
    pass "Installer guards against overwriting existing inventory"
  else
    fail "Installer missing inventory overwrite guard"
  fi

  # Installer preflight must validate new templates
  if grep -q '17_SYNC_WORKLOAD_GOVERNANCE.md\|SYNC_JOB_INVENTORY.template.md' "$INSTALLER"; then
    pass "Installer preflight validates sync governance templates"
  else
    warn "Installer preflight may not validate sync governance templates"
  fi
else
  fail "Installer not found"
fi

# ── Existing workload ID convention check ──

echo ""
echo "--- Workload ID convention ---"

WORKLOADS="$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"
if [[ -f "$WORKLOADS" ]]; then
  # Verify comment now says lower_snake_case (not kebab-case)
  if grep -q 'lower_snake_case' "$WORKLOADS"; then
    pass "DATABASE_WORKLOADS.yaml documents lower_snake_case convention"
  else
    # Check if the old kebab-case comment is still there
    if grep -q 'kebab-case' "$WORKLOADS"; then
      fail "DATABASE_WORKLOADS.yaml still says kebab-case in comments"
    else
      warn "DATABASE_WORKLOADS.yaml workload ID convention not explicitly documented"
    fi
  fi

  # All existing workload IDs use snake_case (verify they weren't broken)
  REAL_IDS=$(grep -E '^  [a-z]+_[a-z].*:' "$WORKLOADS" | grep -v '^  [a-z]*example' | grep -v 'workloads:' | grep -v 'database:' | grep -v 'safety_profile:' | grep -v 'kill_switch:' | grep -v 'rollout_gates:' | grep -v 'monitoring:' | grep -v 'request_budget:' | grep -v 'change_aware' | grep -v 'depends_on:' | grep -v 'excluded_windows:' | grep -v 'credential_contract:' | sed 's/:$//' | tr -d ' ')
  if [[ -n "$REAL_IDS" ]]; then
    INVALID=$(echo "$REAL_IDS" | grep -v '^[a-z][a-z0-9_]*$' || true)
    if [[ -z "$INVALID" ]]; then
      pass "All existing workload IDs use valid snake_case"
    else
      fail "Some workload IDs do not match snake_case pattern: $INVALID"
    fi
  else
    warn "No real workload IDs found to validate"
  fi
else
  warn "DATABASE_WORKLOADS.yaml not found — skipping ID convention check"
fi

# ── Scope boundary check ──

echo ""
echo "--- Database governance scope boundary ---"

DB_GOV="$KIT_DIR/docs/DATABASE_GOVERNANCE.md"
if [[ -f "$DB_GOV" ]]; then
  if grep -q 'Sync Workload Governance' "$DB_GOV"; then
    pass "DATABASE_GOVERNANCE.md has sync governance scope boundary"
  else
    fail "DATABASE_GOVERNANCE.md missing sync governance scope boundary"
  fi

  if grep -q 'SYNC_WORKLOAD_GOVERNANCE.md' "$DB_GOV"; then
    pass "DATABASE_GOVERNANCE.md references SYNC_WORKLOAD_GOVERNANCE.md"
  else
    fail "DATABASE_GOVERNANCE.md missing SYNC_WORKLOAD_GOVERNANCE.md reference"
  fi

  # Risk classification should now differentiate external vs internal
  if grep -q 'external_write.*High.*read_only.*Low' "$DB_GOV" || \
     grep -q 'external_write syncs are High' "$DB_GOV"; then
    pass "DATABASE_GOVERNANCE.md risk classification accounts for external vs internal"
  else
    warn "DATABASE_GOVERNANCE.md risk classification may not differentiate external/internal writes"
  fi

  # Hardcoded numbers should be replaced with bounded-and-appropriate language
  if grep -q 'bounded and appropriate' "$DB_GOV"; then
    pass "DATABASE_GOVERNANCE.md uses bounded-and-appropriate language"
  else
    warn "DATABASE_GOVERNANCE.md may still have universal hardcoded limits"
  fi
else
  fail "DATABASE_GOVERNANCE.md not found"
fi

# ── CI sync warning check ──

echo ""
echo "--- CI sync governance warnings ---"

CI="$KIT_DIR/.github/workflows/governance-checks.yml"
if [[ -f "$CI" ]]; then
  if grep -q 'sync.*inventory\|SYNC_JOB_INVENTORY' "$CI"; then
    pass "CI has sync inventory warning"
  else
    fail "CI missing sync inventory warning"
  fi

  if grep -q 'Possible production sync behavior changed' "$CI"; then
    pass "CI warning message explains sync behavior concern"
  else
    fail "CI missing sync warning message"
  fi
else
  fail "governance-checks.yml not found"
fi
