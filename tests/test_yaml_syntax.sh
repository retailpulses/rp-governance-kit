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

	  # Check domain_type field exists on all domains (v4 schema)
	  DOMAIN_TYPES=$(grep -c 'domain_type:' "$OWNERSHIP" || true)
	  if [[ "$DOMAIN_TYPES" -ge 1 ]]; then
	    pass "domain_type field present ($DOMAIN_TYPES domains)"
	  else
	    warn "domain_type field not found (v4 schema may not be applied)"
	  fi

	  # Check consumers are simple strings (v5 schema — access policy moved to DATABASE_ACCESS_POLICY.yaml)
	  if grep -q "repo:" "$OWNERSHIP"; then
	    warn "DATABASE_OWNERSHIP.yaml consumers should be simple strings (v5); structured consumers belong in DATABASE_ACCESS_POLICY.yaml"
	  else
	    pass "Consumers are simple strings (v5 — access policy separated)"
	  fi


	  if grep -q "permitted_access_classes:" "$OWNERSHIP"; then
	    warn "permitted_access_classes found in DATABASE_OWNERSHIP.yaml (should be in DATABASE_ACCESS_POLICY.yaml in v5)"
	  else
	    pass "permitted_access_classes correctly absent from ownership (v5 — in DATABASE_ACCESS_POLICY.yaml)"
	  fi

	  # catalog_sync should be classified as consumer_capability
	  if grep -A2 'catalog_sync:' "$OWNERSHIP" | grep -q 'consumer_capability'; then
	    pass "catalog_sync domain correctly classified as consumer_capability"
	  else
	    warn "catalog_sync domain may not be classified as consumer_capability"
	  fi

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
  if grep -q 'example_low_risk_read\|example_high_risk_sync' "$WORKLOADS"; then
    pass "Contains example entries"
    # Example entries must have EXAMPLE in description
    if grep -A2 'example_low_risk_read:' "$WORKLOADS" | grep -qi 'EXAMPLE'; then
      pass "Example nightly_cleanup clearly marked as EXAMPLE"
    else
      warn "Example nightly_cleanup may not be clearly marked"
    fi
    if grep -A2 'example_high_risk_sync:' "$WORKLOADS" | grep -qi 'EXAMPLE'; then
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
    if grep -A100 'catalogsync_product_mirror:' "$WORKLOADS" | grep -q 'incident_ref.*23'; then
      pass "CatalogSync entry references incident #23"
    else
      warn "CatalogSync entry missing incident_ref #23"
    fi
    if grep -A100 'catalogsync_product_mirror:' "$WORKLOADS" | grep -q 'access_path'; then
      pass "CatalogSync entry declares access path"
    else
      warn "CatalogSync entry missing access path"
    fi
  else
    warn "CatalogSync workload entry not found (optional: may be added in future)"
  fi

  if grep -q 'catalogsync_mercari_shop4_read' "$WORKLOADS"; then
    pass "CatalogSync shop4 read workload entry exists"
    if grep -A90 'catalogsync_mercari_shop4_read:' "$WORKLOADS" | grep -q 'access_path: postgrest'; then
      pass "CatalogSync shop4 entry declares postgrest access"
    else
      fail "CatalogSync shop4 entry must declare postgrest access"
    fi
    if grep -A90 'catalogsync_mercari_shop4_read:' "$WORKLOADS" | grep -q 'service_role_forbidden: true'; then
      pass "CatalogSync shop4 entry forbids service_role"
    else
      fail "CatalogSync shop4 entry must forbid service_role"
    fi
  else
    fail "CatalogSync shop4 read workload entry missing"
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
  if grep -q 'Standard fields (required for every workload)' "$WORKLOADS"; then
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

# Specific checks for DATABASE_ACCESS_POLICY.yaml
echo ""
echo "--- DATABASE_ACCESS_POLICY.yaml schema ---"
ACCESS_POLICY="$KIT_DIR/docs/DATABASE_ACCESS_POLICY.yaml"

if [[ -f "$ACCESS_POLICY" ]]; then
  if grep -q '^database:' "$ACCESS_POLICY"; then
    pass "DATABASE_ACCESS_POLICY.yaml: Has 'database:' key"
  else
    fail "DATABASE_ACCESS_POLICY.yaml: Missing 'database:' key"
  fi

  if grep -q '^access_policy:' "$ACCESS_POLICY"; then
    pass "DATABASE_ACCESS_POLICY.yaml: Has 'access_policy:' section"
  else
    fail "DATABASE_ACCESS_POLICY.yaml: Missing 'access_policy:' section"
  fi

  if grep -q 'permitted_access_classes:' "$ACCESS_POLICY"; then
    pass "DATABASE_ACCESS_POLICY.yaml: Has permitted_access_classes field"
  else
    fail "DATABASE_ACCESS_POLICY.yaml: Missing permitted_access_classes field"
  fi

  if grep -q 'service_role_forbidden' "$ACCESS_POLICY"; then
    pass "DATABASE_ACCESS_POLICY.yaml: Has service_role_forbidden field"
  else
    warn "DATABASE_ACCESS_POLICY.yaml: Missing service_role_forbidden field"
  fi
else
  fail "DATABASE_ACCESS_POLICY.yaml not found"
fi

# Specific checks for DATABASE_CAPABILITIES.yaml
echo ""
echo "--- DATABASE_CAPABILITIES.yaml schema ---"
CAPABILITIES="$KIT_DIR/docs/DATABASE_CAPABILITIES.yaml"

if [[ -f "$CAPABILITIES" ]]; then
  if grep -q '^database:' "$CAPABILITIES"; then
    pass "DATABASE_CAPABILITIES.yaml: Has 'database:' key"
  else
    fail "DATABASE_CAPABILITIES.yaml: Missing 'database:' key"
  fi

  if grep -q '^capabilities:' "$CAPABILITIES"; then
    pass "DATABASE_CAPABILITIES.yaml: Has 'capabilities:' section"
  else
    fail "DATABASE_CAPABILITIES.yaml: Missing 'capabilities:' section"
  fi

  # Key repos should be declared
  for REPO in retailpulses/RPagentOS retailpulses/CatalogSync retailpulses/ticket-handling retailpulses/OrderMgmt; do
    if grep -q "  $REPO:" "$CAPABILITIES"; then
      pass "DATABASE_CAPABILITIES.yaml: '$REPO' declared"
    else
      warn "DATABASE_CAPABILITIES.yaml: '$REPO' not found"
    fi
  done

  # Capability fields should exist
  if grep -q 'read:' "$CAPABILITIES" && grep -q 'write:' "$CAPABILITIES" && grep -q 'schema_change:' "$CAPABILITIES"; then
    pass "DATABASE_CAPABILITIES.yaml: Has read/write/schema_change capability fields"
  else
    fail "DATABASE_CAPABILITIES.yaml: Missing capability fields"
  fi
else
  warn "DATABASE_CAPABILITIES.yaml not found (v5 schema — may not be created yet)"
fi
