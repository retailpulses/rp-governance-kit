#!/usr/bin/env bash
# test_policy_cross_references.sh — verify cross-references between governance docs are valid

echo "--- Policy cross-reference integrity ---"

KIT_DOCS="$KIT_DIR/docs"

# Check that every file referenced in DATABASE_GOVERNANCE.md exists
echo "--- DATABASE_GOVERNANCE.md references ---"

if [[ -f "$KIT_DOCS/DATABASE_GOVERNANCE.md" ]]; then
  REFS=$(grep -oE '`?docs/(DATABASE_[A-Z_]+\.(yaml|md)|[0-9]+_.+\.md)`?' "$KIT_DOCS/DATABASE_GOVERNANCE.md" | sed "s/\`//g" | sort -u)

  for ref in $REFS; do
    # Extract just the filename from the ref
    fname=$(basename "$ref")
    # Look for it in the canonical docs
    if [[ -f "$KIT_DOCS/$fname" ]] || [[ -f "$KIT_DIR/$ref" ]]; then
      pass "Reference exists: $ref"
    else
      # Some refs are repo-local (docs/16_DATABASE_GOVERNANCE.local.md etc.)
      if echo "$ref" | grep -q 'local\.md'; then
        pass "Reference to repo-local file (expected): $ref"
      else
        warn "Reference may be stale: $ref"
      fi
    fi
  done
else
  fail "DATABASE_GOVERNANCE.md not found"
fi

# Check incident response references
echo ""
echo "--- DATABASE_INCIDENT_RESPONSE.md structure ---"

if [[ -f "$KIT_DOCS/DATABASE_INCIDENT_RESPONSE.md" ]]; then
  REQUIRED_SECTIONS=(
    "Incident Classification"
    "Resource-Exhaustion Triage"
    "Evidence Capture Before Mitigation"
    "Emergency Shutdown"
    "Compute Resize"
    "Recovery Validation"
    "Downgrade Gates"
    "Post-Incident"
  )

  for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -q "$section" "$KIT_DOCS/DATABASE_INCIDENT_RESPONSE.md"; then
      pass "Incident response has: $section"
    else
      fail "Incident response missing: $section"
    fi
  done

  # Must reference governance policy
  if grep -q 'DATABASE_GOVERNANCE.md' "$KIT_DOCS/DATABASE_INCIDENT_RESPONSE.md"; then
    pass "Incident response references DATABASE_GOVERNANCE.md"
  else
    fail "Incident response missing reference to DATABASE_GOVERNANCE.md"
  fi

  # Must reference workload registry
  if grep -q 'DATABASE_WORKLOADS' "$KIT_DOCS/DATABASE_INCIDENT_RESPONSE.md"; then
    pass "Incident response references DATABASE_WORKLOADS.yaml"
  else
    fail "Incident response missing reference to DATABASE_WORKLOADS.yaml"
  fi
else
  fail "DATABASE_INCIDENT_RESPONSE.md not found"
fi

# Check the three core governance files form a coherent set
echo ""
echo "--- Governance doc set coherence ---"
CORE_DOCS=(
  "DATABASE_GOVERNANCE.md"
  "DATABASE_OWNERSHIP.yaml"
  "DATABASE_ACCESS_POLICY.yaml"
  "DATABASE_CAPABILITIES.yaml"
  "DATABASE_WORKLOADS.yaml"
  "DATABASE_INCIDENT_RESPONSE.md"
)

for doc in "${CORE_DOCS[@]}"; do
  if [[ -f "$KIT_DOCS/$doc" ]]; then
    pass "$doc exists"
  else
    fail "$doc missing"
  fi
done

# Check the database workflow CI exists
echo ""
echo "--- CI workflow integrity ---"

CI_DIR="$KIT_DIR/.github/workflows"
CI_FILES=(
  "governance-checks.yml"
  "database-governance-checks.yml"
  "post-deploy-governance.yml"
)

for ci in "${CI_FILES[@]}"; do
  if [[ -f "$CI_DIR/$ci" ]]; then
    pass "$ci exists"
  else
    fail "$ci missing"
  fi
done

# Verify database-governance-checks.yml has runtime-impact job
if [[ -f "$CI_DIR/database-governance-checks.yml" ]]; then
  if grep -q 'runtime-impact-declaration' "$CI_DIR/database-governance-checks.yml"; then
    pass "database-governance-checks.yml has runtime-impact-declaration job"
  else
    fail "database-governance-checks.yml missing runtime-impact-declaration job"
  fi

  # Verify secret detection does NOT flag project refs
  if grep -q 'NOT secrets' "$CI_DIR/database-governance-checks.yml"; then
    pass "database-governance-checks.yml clarifies project refs are NOT secrets"
  else
    fail "database-governance-checks.yml missing project ref clarification"
  fi

  # Verify secret detection redacts findings
  if grep -qi 'redact' "$CI_DIR/database-governance-checks.yml"; then
    pass "database-governance-checks.yml redacts secret findings"
  else
    fail "database-governance-checks.yml does not redact secret findings"
  fi
fi

# Verify governance workflow didn't lose existing jobs
echo ""
echo "--- CI workflow job inventory ---"

if [[ -f "$CI_DIR/database-governance-checks.yml" ]]; then
	  # Check enforcement levels section exists (v1.5.0)
	  if grep -q "Enforcement Levels" "$KIT_DOCS/DATABASE_GOVERNANCE.md"; then
	    pass "DATABASE_GOVERNANCE.md has Enforcement Levels section (v1.5.0)"
	  else
	    warn "DATABASE_GOVERNANCE.md missing Enforcement Levels section (may be pre-v1.5.0)"
	  fi


  EXISTING_JOBS=(
    "migration-naming"
    "duplicate-timestamps-local"
    "migration-docs-impact"
    "secret-detection"
    "migration-header"
    "cross-domain-owner"
    "migration-warnings"
    "org-duplicate-timestamps"
  )
  for job in "${EXISTING_JOBS[@]}"; do
    if grep -q "$job" "$CI_DIR/database-governance-checks.yml"; then
      pass "Job preserved: $job"
    else
      fail "Job lost: $job"
    fi
  done

          NEW_JOBS=("runtime-impact-declaration" "n-plus-one-detection" "change-aware-write-detection" "access-path-enforcement" "run-health-independence-check")
  for job in "${NEW_JOBS[@]}"; do
    if grep -q "$job" "$CI_DIR/database-governance-checks.yml"; then
      pass "New job added: $job"
    else
      fail "New job missing: $job"
    fi
  done
fi
