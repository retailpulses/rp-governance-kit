#!/usr/bin/env bash
# test_template_placeholders.sh — verify template files have correct placeholder substitution

echo "--- Template placeholder checks ---"

TEMPLATES_DIR="$KIT_DIR/templates"

# Check 1: 16_DATABASE_GOVERNANCE.md has __REF__ and __INSTALLED_AT__ placeholders
GOV_TEMPLATE="$TEMPLATES_DIR/docs/16_DATABASE_GOVERNANCE.md"
if [[ -f "$GOV_TEMPLATE" ]]; then
  if grep -q '__REF__' "$GOV_TEMPLATE"; then
    pass "16_DATABASE_GOVERNANCE.md has __REF__ placeholder"
  else
    fail "16_DATABASE_GOVERNANCE.md missing __REF__ placeholder"
  fi

  if grep -q '__INSTALLED_AT__' "$GOV_TEMPLATE"; then
    pass "16_DATABASE_GOVERNANCE.md has __INSTALLED_AT__ placeholder"
  else
    fail "16_DATABASE_GOVERNANCE.md missing __INSTALLED_AT__ placeholder"
  fi

  # Must link to canonical policy
  if grep -q 'docs/DATABASE_GOVERNANCE.md' "$GOV_TEMPLATE"; then
    pass "16_DATABASE_GOVERNANCE.md links to canonical policy"
  else
    fail "16_DATABASE_GOVERNANCE.md missing link to canonical policy"
  fi

  # Must link to incident response
  if grep -q 'DATABASE_INCIDENT_RESPONSE' "$GOV_TEMPLATE"; then
    pass "16_DATABASE_GOVERNANCE.md links to incident response"
  else
    fail "16_DATABASE_GOVERNANCE.md missing link to DATABASE_INCIDENT_RESPONSE.md"
  fi

  # Must link to workload registry
  if grep -q 'DATABASE_WORKLOADS' "$GOV_TEMPLATE"; then
    pass "16_DATABASE_GOVERNANCE.md links to workload registry"
  else
    fail "16_DATABASE_GOVERNANCE.md missing link to DATABASE_WORKLOADS.yaml"
  fi
else
  fail "16_DATABASE_GOVERNANCE.md template not found"
fi

# Check 2: Workflow wrappers have __REF__
echo ""
echo "--- Workflow wrapper placeholders ---"

for wrapper in governance-checks-wrapper.yml database-governance-wrapper.yml post-deploy-governance-wrapper.yml; do
  WRAPPER="$TEMPLATES_DIR/github/workflows/$wrapper"
  if [[ -f "$WRAPPER" ]]; then
    if grep -q '__REF__' "$WRAPPER"; then
      pass "$wrapper has __REF__ placeholder"
    else
      fail "$wrapper missing __REF__ placeholder"
    fi

    if grep -q 'rp-governance-kit' "$WRAPPER"; then
      pass "$wrapper references rp-governance-kit"
    else
      fail "$wrapper missing rp-governance-kit reference"
    fi
  else
    warn "$wrapper not found"
  fi
done

# Check 3: PR template has new runtime impact fields
echo ""
echo "--- PR template fields ---"

PR_TEMPLATE="$TEMPLATES_DIR/github/pull_request_template.md"
if [[ -f "$PR_TEMPLATE" ]]; then
  REQUIRED_FIELDS=(
    "Runtime Database Impact"
    "Operational Budget"
    "Workload category"
    "Affected tables"
    "Kill-switch method"
    "Workload registry entry"
    "Peak connections consumed"
    "N+1 Lookup Safeguard"
    "Change-Aware Write Strategy"
    "Access path"
    "Rollout Gate Plan"
    "Request budget"
    "Source commit"
    "Run-level freshness"
  )

  for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -qi "$field" "$PR_TEMPLATE"; then
      pass "PR template has '$field' section"
    else
      fail "PR template missing '$field' section"
    fi
  done
else
  fail "PR template not found"
fi

# Check 4: Agent scripts reference governance docs where appropriate
echo ""
echo "--- Agent script governance references ---"

if [[ -f "$TEMPLATES_DIR/bin/rp-issue-work" ]]; then
  if grep -qiE 'database.*governance|16_DATABASE|DATABASE_GOVERNANCE' "$TEMPLATES_DIR/bin/rp-issue-work"; then
    pass "rp-issue-work references database governance"
  else
    warn "rp-issue-work does not reference database governance (non-critical)"
  fi
fi

if [[ -f "$TEMPLATES_DIR/bin/rp-issue-closeout" ]]; then
  if grep -qiE 'migration|supabase|database' "$TEMPLATES_DIR/bin/rp-issue-closeout"; then
    pass "rp-issue-closeout references database checks"
  else
    warn "rp-issue-closeout does not reference database checks (non-critical)"
  fi
fi

# Check 5: 16_DATABASE_GOVERNANCE.md (canonical) has all new sections
echo ""
echo "--- Canonical policy section coverage ---"

CANONICAL="$KIT_DIR/docs/DATABASE_GOVERNANCE.md"
if [[ -f "$CANONICAL" ]]; then
  REQUIRED_SECTIONS=(
    "Runtime Workload Safety"
    "Workload Categories"
    "Pre-Workload Declaration"
    "Batching and Pagination"
    "Connection Pooling and Concurrency"
    "Timeouts and Retries"
    "Kill Switches"
    "Approval Boundaries"
    "Evidence Capture"
    "N+1 Lookup Prohibition"
    "Change-Aware Writes"
    "Access Path Declaration"
    "Scheduled Workload Release Mapping"
    "Rollout Gates for High-Risk Workloads"
    "Current-Run Health Independence"
    "Resource Management"
    "Compute Resize"
    "Downgrade Gates"
    "Monitoring Thresholds"
    "Reporting and Governance"
    "Workload Registry"
    "Incident Escalation"
  )

  for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -q "$section" "$CANONICAL"; then
      pass "Policy has section: $section"
    else
      fail "Policy missing section: $section"
    fi
  done
else
  fail "Canonical DATABASE_GOVERNANCE.md not found"
fi
