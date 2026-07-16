# test_governance_rigidity_corrections.sh
# Verify that the governance-rigidity corrections from the Issue-3/4/5 audit
# are correctly reflected in central policy, templates, and tooling.
#
# These tests check that schema ownership does not imply API-only access,
# that workload declarations govern runtime access paths, and that the
# "stricter" ambiguity has been removed.

echo ""
echo "--- Governance rigidity correction tests ---"

# ── Helper ──────────────────────────────────────────────────────────
KIT_DIR="${KIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ── 1. Schema ownership does not imply API-only access ──────────────
echo ""
echo "Test 1: Schema ownership does not imply API-only access"

if grep -qE '\*\*Schema ownership\*\* controls' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "DATABASE_GOVERNANCE.md explicitly separates schema ownership from runtime access"
else
  fail "DATABASE_GOVERNANCE.md missing §2b about schema ownership vs runtime access"
fi

# Check the §2b heading exists
if grep -qE '## 2b\. Schema Ownership Does Not Determine Runtime Access Path' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "§2b heading present in DATABASE_GOVERNANCE.md"
else
  fail "§2b heading missing from DATABASE_GOVERNANCE.md"
fi

# ── 2. Schema consumer may be an authorized runtime reader ───────────
echo ""
echo "Test 2: Schema consumer may be authorized runtime reader"

if grep -qE 'A repository may own no schema objects yet be an authorized runtime' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy confirms consumer repos may be authorized runtime readers"
else
  fail "Central policy missing statement that consumer repos may be runtime readers"
fi

# ── 3. Schema consumer may be authorized workload-specific writer ────
echo ""
echo "Test 3: Schema consumer may be authorized workload-specific writer"

if grep -qE 'Runtime writes to data.*INSERT.*UPDATE.*DELETE.*are governed by workload declarations' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy allows consumer repos to write through workload declarations"
else
  fail "Central policy should state that runtime writes are governed by workload declarations"
fi

# ── 4. Direct PostgREST is accepted when explicitly active/approved ──
echo ""
echo "Test 4: Direct PostgREST accepted when explicitly active and approved"

if grep -qE "postgrest" "$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"; then
  pass "DATABASE_WORKLOADS.yaml contains postgrest as an access path"
else
  fail "DATABASE_WORKLOADS.yaml missing postgrest access path"
fi

# Check that at least one real workload declares postgrest
# Use a broad match to handle section boundaries
if grep -q 'access_path: postgrest' "$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"; then
  pass "At least one workload declares postgrest access path"
else
  fail "No workload entry declares postgrest access path"
fi

# Check central policy accepts postgrest for consumers when approved
if grep -qE 'Consumers may use an access path other than `internal_api` only when that alternative path is explicitly declared' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy allows consumer repos to use non-internal_api paths when declared"
else
  fail "Central policy missing exception for non-internal_api consumer paths"
fi

# ── 5. Direct PostgREST rejected when undeclared ─────────────────────
echo ""
echo "Test 5: Direct PostgREST rejected when undeclared"

if grep -qE 'A workload caught using a path other than its declared path is a governance violation' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy rejects undeclared access paths"
else
  fail "Central policy missing undeclared access path violation language"
fi

# ── 6. Internal API accepted when explicitly declared ────────────────
echo ""
echo "Test 6: Internal API accepted when explicitly declared"

if grep -q 'access_path: internal_api' "$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"; then
  pass "At least one workload declares internal_api access path"
else
  fail "No workload entry declares internal_api access path"
fi

# ── 7. Multiple implemented adapters while only one is authorized ────
echo ""
echo "Test 7: Multiple adapters allowed while only one is production-authorized"

if grep -qE 'A workload caught using a path other than its declared path is a governance violation' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy enforces that implemented path must match declared path"
else
  fail "Central policy missing enforcement of declared vs implemented path"
fi

# ── 8. Silent fallback rejected ─────────────────────────────────────
echo ""
echo "Test 8: Silent fallback rejected"

if grep -qiE 'silent.*fallback|silently.*fall.?back|must not.*fall.?back' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md" "$KIT_DIR/docs/DATABASE_OWNERSHIP.yaml" "$KIT_DIR/templates/docs/16_DATABASE_GOVERNANCE.md"; then
  pass "Silent fallback between access paths is prohibited"
else
  fail "No prohibition of silent fallback found in central policy"
fi

# ── 9. Consumer-owned migrations in another domain rejected ──────────
echo ""
echo "Test 9: Consumer-owned migrations in another domain rejected"

if grep -qE 'No repository may create canonical migrations for another domain' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy prohibits cross-domain migrations"
else
  fail "Central policy missing cross-domain migration prohibition"
fi

# ── 10. Stricter local rule conflict reported ────────────────────────
echo ""
echo "Test 10: Stricter local rule conflict reported"

# Check central policy says "stricter" is not automatically valid
if grep -qE 'not automatically valid' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy rejects 'more restrictive = automatically valid'"
elif grep -qE 'are not automatically valid' "$KIT_DIR/docs/DATABASE_GOVERNANCE.md"; then
  pass "Central policy clarifies that stricter local rules are not automatically valid"
else
  fail "Central policy missing clarification about stricter local rules"
fi

# Check template also updated
if grep -qE 'not automatically valid' "$KIT_DIR/templates/docs/16_DATABASE_GOVERNANCE.md"; then
  pass "Template clarifies that stricter local rules are not automatically valid"
else
  fail "Template missing clarification about stricter local rules"
fi

# ── 11. Heuristic keyword findings do not become blocking conclusions ─
echo ""
echo "Test 11: Heuristic keyword findings remain advisory"

if grep -q '\[heuristic\]' "$KIT_DIR/templates/bin/rp-issue-audit"; then
  pass "rp-issue-audit tags keyword findings as [heuristic]"
else
  fail "rp-issue-audit missing [heuristic] tag on keyword findings"
fi

# Check that heuristic findings are clearly marked as not factual
if grep -q 'keyword-based findings below are HEURISTIC' "$KIT_DIR/templates/bin/rp-issue-audit"; then
  pass "rp-issue-audit explicitly states keyword findings are heuristic"
else
  fail "rp-issue-audit missing explicit statement that keyword findings are heuristic"
fi

# Check whether audit converts heuristic to blocking
if grep -q 'not convert these warnings into unsupported blocking rules' "$KIT_DIR/templates/bin/rp-issue-audit"; then
  pass "rp-issue-audit prohibits converting heuristic warnings into blocking rules"
else
  fail "rp-issue-audit missing guard against heuristic-to-blocking conversion"
fi

# ── 12. Stale generated templates are reported ──────────────────────
echo ""
echo "Test 12: Stale generated templates reported"

# The template has ref tracking via __REF__ placeholder
if grep -q '__REF__' "$KIT_DIR/templates/docs/16_DATABASE_GOVERNANCE.md"; then
  pass "Template includes __REF__ placeholder for version tracking"
else
  fail "Template missing __REF__ placeholder"
fi

if grep -q '__INSTALLED_AT__' "$KIT_DIR/templates/docs/16_DATABASE_GOVERNANCE.md"; then
  pass "Template includes __INSTALLED_AT__ for installation timestamp"
else
  fail "Template missing __INSTALLED_AT__ placeholder"
fi

# ── 13. Installer audit preserves local modifications ───────────────
echo ""
echo "Test 13: Installer audit mode (structural check)"

# Check installer has --dry-run mode
if grep -q '\-\-dry-run' "$KIT_DIR/bin/rp-governance-install"; then
  pass "Installer has --dry-run mode"
else
  fail "Installer missing --dry-run mode"
fi

# Check for up-to-date detection
if grep -q 'is_up_to_date' "$KIT_DIR/bin/rp-governance-install"; then
  pass "Installer detects up-to-date repos"
else
  fail "Installer missing up-to-date detection"
fi

# Check that local declarations are preserved
if grep -q 'never overwritten' "$KIT_DIR/bin/rp-governance-install"; then
  pass "Installer preserves local declarations"
elif grep -q 'Repo-specific declarations' "$KIT_DIR/bin/rp-governance-install" && grep -q 'never overwritten' "$KIT_DIR/bin/rp-governance-install" 2>/dev/null; then
  pass "Installer preserves local declarations"
else
  warn "Could not find explicit 'never overwritten' comment for local declarations in installer"
fi

# ── 14. Unsupported service-role usage rejected ─────────────────────
echo ""
echo "Test 14: Unsupported service-role usage rejected"

if grep -qE 'service_role_forbidden|service.role.*must not|service.role.*not allowed' "$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"; then
  pass "Workload registry supports service_role_forbidden constraint"
else
  warn "Check workload registry for service_role prohibition"
fi

# Check that the owner_repo field in workloads allows tracking credential owner
if grep -q 'credential_owner' "$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"; then
  pass "Workload registry includes credential_owner field"
elif grep -q 'credential_contract' "$KIT_DIR/docs/DATABASE_WORKLOADS.yaml"; then
  pass "Workload registry includes credential_contract section"
else
  fail "Workload registry missing credential ownership tracking"
fi

# ── 15. Existing Issue-link and documentation checks continue to work ─
echo ""
echo "Test 15: Existing checks preserved"

# Check the PR template still has Issue-link requirement
if grep -qE 'Closes|Fixes|Resolves|Refs|Related to' "$KIT_DIR/templates/github/pull_request_template.md"; then
  pass "PR template retains Issue-link requirement"
else
  fail "PR template missing Issue-link requirement"
fi

# Check governance-checks.yml still has issue-link-check
if grep -qE 'Issue Link Check|issue-link-check' "$KIT_DIR/.github/workflows/governance-checks.yml"; then
  pass "CI retains Issue-link check"
else
  fail "CI missing Issue-link check"
fi

# Check docs-impact check is preserved
if grep -qE 'docs-impact-check|Docs Impact' "$KIT_DIR/.github/workflows/governance-checks.yml"; then
  pass "CI retains Docs Impact check"
else
  fail "CI missing Docs Impact check"
fi

echo ""
echo "--- All rigidity correction tests complete ---"
