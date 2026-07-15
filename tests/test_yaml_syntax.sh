#!/usr/bin/env bash
# test_yaml_syntax.sh — validate YAML files for structural correctness
# Uses basic grep and sed checks (no yq dependency required).

echo "--- YAML structural validation ---"

YAML_FILES=$(find "$KIT_DIR/docs" -name '*.yaml' -o -name '*.yml' | sort)

for f in $YAML_FILES; do
  fname=$(basename "$f")

  # Check: no tabs in YAML
  if grep -qP '\t' "$f" 2>/dev/null; then
    fail "$fname — contains TAB characters (YAML uses spaces)"
  else
    pass "$fname — no TAB characters"
  fi

  # Check: file is not empty
  if [[ ! -s "$f" ]]; then
    fail "$fname — file is empty"
  fi

  # Check: starts with a comment or a key (not malformed)
  FIRST_LINE=$(head -1 "$f")
  if echo "$FIRST_LINE" | grep -qE '^(\s*#|\s*[a-zA-Z_]+\s*:)'; then
    pass "$fname — first line is valid YAML start"
  else
    warn "$fname — unexpected first line: $FIRST_LINE"
  fi
done

# Specific checks for DATABASE_OWNERSHIP.yaml
echo ""
echo "--- DATABASE_OWNERSHIP.yaml schema ---"
OWNERSHIP="$KIT_DIR/docs/DATABASE_OWNERSHIP.yaml"

if [[ -f "$OWNERSHIP" ]]; then
  # Must contain the database key
  if grep -q '^database:' "$OWNERSHIP"; then
    pass "Has 'database:' key"
  else
    fail "Missing 'database:' key"
  fi

  # Must contain domains section
  if grep -q '^domains:' "$OWNERSHIP"; then
    pass "Has 'domains:' section"
  else
    fail "Missing 'domains:' section"
  fi

  # Check domain entries have required fields
  for DOMAIN in ticketing product_catalog agent_os task_management project_management listing_intelligence listing_quality order_management catalog_sync; do
    if grep -q "^  $DOMAIN:" "$OWNERSHIP"; then
      pass "Domain '$DOMAIN' declared"
    else
      warn "Domain '$DOMAIN' not found (may be renamed/removed)"
    fi
  done

  # Check access classes are valid
  ACCESS_CLASSES=$(grep -E '^\s+access_class:' "$OWNERSHIP" | sed 's/.*access_class: *//' | sort -u)
  for ac in $ACCESS_CLASSES; do
    case "$ac" in
      worker_only|authenticated_user|public_read|internal_admin) ;;
      *) fail "Invalid access class: $ac" ;;
    esac
  done
  pass "All access classes are valid keywords"
else
  fail "DATABASE_OWNERSHIP.yaml not found"
fi

# Specific checks for DATABASE_WORKLOADS.yaml
echo ""
echo "--- DATABASE_WORKLOADS.yaml schema ---"
WORKLOADS="$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"

if [[ -f "$WORKLOADS" ]]; then
  # Must contain the database key
  if grep -q '^database:' "$WORKLOADS"; then
    pass "Has 'database:' key"
  else
    fail "Missing 'database:' key"
  fi

  # Must contain workloads section
  if grep -q '^workloads:' "$WORKLOADS"; then
    pass "Has 'workloads:' section"
  else
    fail "Missing 'workloads:' section"
  fi

  # Example entries must be marked as examples
  if grep -q 'example_nightly_cleanup\|example_external_sync' "$WORKLOADS"; then
    pass "Contains example entries"
    # Example entries must have EXAMPLE in description
    if grep -A2 'example_nightly_cleanup:' "$WORKLOADS" | grep -qi 'EXAMPLE'; then
      pass "Example nightly_cleanup clearly marked as EXAMPLE"
    else
      warn "Example nightly_cleanup may not be clearly marked"
    fi
    if grep -A2 'example_external_sync:' "$WORKLOADS" | grep -qi 'EXAMPLE'; then
      pass "Example external_sync clearly marked as EXAMPLE"
    else
      warn "Example external_sync may not be clearly marked"
    fi
  else
    warn "No example workload entries found"
  fi

  # CatalogSync real workload entry must exist
  if grep -q 'catalogsync_product_mirror' "$WORKLOADS"; then
    pass "CatalogSync real workload entry exists"
    if grep -A5 'catalogsync_product_mirror:' "$WORKLOADS" | grep -q 'owner_repo.*CatalogSync'; then
      pass "CatalogSync entry has owner_repo field"
    else
      warn "CatalogSync entry missing owner_repo"
    fi
    if grep -A60 'catalogsync_product_mirror:' "$WORKLOADS" | grep -q 'incident_ref.*23'; then
      pass "CatalogSync entry references incident #23"
    else
      warn "CatalogSync entry missing incident_ref #23"
    fi
    if grep -A60 'catalogsync_product_mirror:' "$WORKLOADS" | grep -q 'access_path.*internal_api'; then
      pass "CatalogSync entry declares internal_api access path"
    else
      warn "CatalogSync entry missing internal_api access path"
    fi
  else
    warn "CatalogSync workload entry not found (optional: may be added in future)"
  fi

  # Schema extensions for incident #23
  if grep -q 'access_path:' "$WORKLOADS"; then
    pass "Schema includes access_path field"
  else
    fail "Schema missing access_path field"
  fi

  if grep -q 'rollout_gates:' "$WORKLOADS"; then
    pass "Schema includes rollout_gates field"
  else
    fail "Schema missing rollout_gates field"
  fi

  if grep -q 'request_budget:' "$WORKLOADS"; then
    pass "Schema includes request_budget field"
  else
    fail "Schema missing request_budget field"
  fi

  if grep -q 'change_aware_writes:' "$WORKLOADS"; then
    pass "Schema includes change_aware_writes field"
  else
    fail "Schema missing change_aware_writes field"
  fi

  # Required field documentation must be present
  if grep -q 'Required fields for every real workload entry' "$WORKLOADS"; then
    pass "Required fields documentation present"
  else
    warn "Required fields documentation section missing"
  fi

  # Kill switch documentation required
  if grep -q 'kill_switch' "$WORKLOADS"; then
    pass "Kill switch fields documented"
  else
    fail "Kill switch fields missing from workload schema"
  fi

  # Monitoring thresholds required
  if grep -q 'warning_thresholds\|critical_thresholds' "$WORKLOADS"; then
    pass "Monitoring threshold fields documented"
  else
    fail "Monitoring threshold fields missing from workload schema"
  fi
else
  fail "DATABASE_WORKLOADS.yaml not found"
fi
