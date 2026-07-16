# Governance Rigidity Audit — PR #3 / Issue #4 / PR #5 Follow-Up

**Date:** 2026-07-17  
**Audit ref:** fix/audit-issue-governance-access-rigidity  
**Canonical policy version after corrections:** v1.5.0  
**Status:** Active audit — corrections applied and validated  

---

## Executive Conclusion

PR #3 and Issue #4/PR #5 introduced a lightweight Issue-governance framework. The
intent was correct. The problem was not the introduction of governance but specific
wording choices and later interpretations that conflated **schema ownership** with
**runtime access path**, introduced an ambiguous "stricter" rule-evaluation heuristic,
and allowed heuristic keyword findings to be treated as factual architecture conclusions.

The corrections in this PR:
1. Explicitly separate schema ownership from runtime access in central policy.
2. Replace the ambiguous "stricter" language with clear conflict-detection rules.
3. Mark all heuristic keyword findings as `[heuristic]` and `[advisory]`.
4. Add local-vs-central conflict detection to `rp-issue-audit`.
5. Add silent-fallback prohibition to central policy.
6. Fix DATABASE_OWNERSHIP.yaml to not imply API-only for consumer repos.
7. Add 27 focused regression tests covering all corrections.

---

## PR #3 and Issue #4 / PR #5 Intent

| Dimension | PR #3 | Issue #4 / PR #5 |
|-----------|-------|-------------------|
| **What** | Issue governance tooling (rp-issue-create, rp-issue-audit, rp-issue-work, rp-issue-closeout), installer, reusable CI | Centralized engineering standards (templates/docs/10-14), expanded Issue fields, governance warnings |
| **Intent** | Prevent raw `gh issue create --body` from becoming the normal workflow | Add cross-cutting standards so agents consider architecture, data access, frontend, and platform dependencies before coding |
| **Correct?** | Yes — Issue-first workflow is a sound practice | Yes — standards ahead of code is the right direction |
| **Problem introduced** | "Central policy wins unless repo rules are stricter" phrase — ambiguous | DATABASE_OWNERSHIP.yaml notes describing current implementation as if it were a governance rule ("not direct Supabase client access") |

---

## Traceability of Problematic Behavior

| Problematic wording | File (current) | Originating commit | Type | Intended risk | Actual effect | Central policy supports? |
|---|---|---|---|---|---|---|
| "CatalogSync reads from these tables through an internal Worker API, not direct Supabase client access" | `docs/DATABASE_OWNERSHIP.yaml` product_catalog notes | `804d7fc` (PR #5) then updated in `f9a14c4` (PR #16) | Documentation — notes field (not binding) | Describe current architecture | Agents inferred API-only is _required_, not just current state | No — §2b now explicitly separates |
| "Central policy wins unless this repository's rules are stricter" | `docs/DATABASE_GOVERNANCE.md` line 5, `templates/docs/16_DATABASE_GOVERNANCE.md` line 39 | `55cd938` (PR #5) | Policy rule | Allow repos to narrow scope | Ambiguously allowed API-only claims to override central policy | No — corrected to clarify that "stricter" != conflict-free |
| "API-only consumers" exemption language in generated-types section | `docs/DATABASE_GOVERNANCE.md` §9 | `804d7fc` | Policy | Skip generated-types requirement for non-client paths | Implied API-only is the only valid path for non-owners | Corrected to reference "non-Supabase-client access path" |
| "repository is a database consumer only" | CatalogSync `CLAUDE.md` line 146 | Manually authored in CatalogSync (not from template) | Local documentation | Accurate description of current role | Reductive — implied consumer = read-only + API-only | No locally corrected in AGENTS.md + .local.md |
| Keyword heuristic warnings without source annotation | `templates/bin/rp-issue-audit` | `55cd938` (PR #5) | Audit tool | Flag potential impacts | Treated as factual conclusions | Corrected — tagged `[heuristic]` and `[advisory]` |

### Distinction: Framework vs. Over-Rigid Interpretation

PR #3 and PR #5 introduced the governance *framework*. The over-rigid behavior
came from:

1. **The "stricter" phrasing** — first appeared in PR #5's
   `templates/docs/16_DATABASE_GOVERNANCE.md` and was copied into the central
   `docs/DATABASE_GOVERNANCE.md`. This phrasing allowed agents to conclude that
   "API-only" was a valid stricter rule even when central policy permits
   alternative approved paths.

2. **The ownership registry notes** — `DATABASE_OWNERSHIP.yaml` notes field
   described current implementation as if it were a governance boundary
   ("not direct Supabase client access"). Later PRs (#14, #16) corrected this
   for the product_catalog domain but the catalog_sync domain retained
   API-only language until this audit.

3. **Heuristic warnings without provenance** — the audit tool's keyword-matching
   warnings did not carry source-file annotations or disclaimers, so they appeared
   as factual governance conclusions rather than heuristic pointers.

4. **Template propagation without conflict detection** — the installer copied
   the "stricter" template into business repositories, but neither the template
   nor the installer included version-skew or conflict detection.

---

## Affected Central Files

| File | Change |
|------|--------|
| `docs/DATABASE_GOVERNANCE.md` | Added §2b (schema ownership vs. runtime access), fixed "stricter" language, added silent-fallback prohibition, fixed generated-types exemption language |
| `docs/DATABASE_OWNERSHIP.yaml` | Clarified catalog_sync and product_catalog notes to not imply API-only; updated generated_types exemption language |
| `templates/docs/16_DATABASE_GOVERNANCE.md` | Fixed "stricter" language, fixed generated-types quick-ref entry |
| `templates/bin/rp-issue-audit` | Added `[heuristic]` tags, added source annotations, added local-vs-central conflict detection, added "stricter" pattern detection |
| `templates/bin/rp-issue-work` | Added work-brief note about schema-ownership vs. runtime-access separation |
| `tests/test_governance_rigidity_corrections.sh` | New — 27 tests covering all corrections |

---

## Affected Business Repositories

### CatalogSync (retailpulses/CatalogSync)

| File | Status | Action required |
|------|--------|-----------------|
| `AGENTS.md` | Partially corrected — references multiple access paths correctly | Re-sync central template after this PR merges; no manual change needed from this PR |
| `CLAUDE.md` line 146 | Still says "database consumer only" | Manual update recommended in a follow-up PR |
| `docs/16_DATABASE_GOVERNANCE.local.md` | Correctly separates schema ownership from runtime access | No action needed |
| `docs/16_DATABASE_GOVERNANCE.md` | Installed template — will be updated on next re-sync | Re-sync after this PR merges |

### Other Business Repositories

No other business repositories were modified in this PR. The impact inventory
for accessible repos is:

| Repository | Governance files | Problematic wording found | Source | Action required |
|---|---|---|---|---|
| CatalogSync | AGENTS.md, CLAUDE.md, 16_DATABASE_GOVERNANCE.md, .local.md | "database consumer only" in CLAUDE.md; "stricter" in AGENTS.md and 16_DATABASE_GOVERNANCE.md | Manual (CLAUDE.md) + template-generated (others) | Follow-up: correct CLAUDE.md, re-sync templates |
| RPagentOS | Not inspected in this audit | Unknown | Unknown | Recommend audit after this PR merges |
| ticket-handling | Not inspected in this audit | Unknown | Unknown | Recommend audit after this PR merges |

---

## CatalogSync Case Study

CatalogSync was the triggering example of the rigidity problem. Key observations:

1. **Correct local declarations already exist** — `AGENTS.md` (lines 149-158) and
   `16_DATABASE_GOVERNANCE.local.md` correctly separate schema ownership from
   runtime access and list all valid access paths.
2. **Stale CLAUDE.md** — Still says "database consumer only" (line 146), which is
   reductive but not blocking.
3. **The root cause was NOT in CatalogSync** — it was in the central policy's
   "stricter" language and the DATABASE_OWNERSHIP.yaml notes that agents used
   as justification for API-only conclusions.
4. **Workload registry entries exist** — both `catalogsync_product_mirror`
   (internal_api) and `catalogsync_mercari_shop4_read` (postgrest) are registered
   in DATABASE_WORKLOADS.yaml with appropriate access paths, credential contracts,
   and rollout gates.

Suggested CatalogSync follow-up in a separate PR:
- Update CLAUDE.md line 146 to match AGENTS.md database governance section
- Re-sync the 16_DATABASE_GOVERNANCE.md after this PR merges
- Verify workload registry entries are complete

---

## Changes Made

### Phase 2 — Issue-Governance Behavior

**`templates/bin/rp-issue-audit`:**
- All keyword-based warnings tagged `[heuristic]`
- Added explicit disclaimer: "All keyword-based findings below are HEURISTIC —
  they flag possible mismatches but are NOT factual architecture conclusions"
- Added `[advisory]` tag to schema-change warnings
- Added note: "Schema ownership does not determine runtime access path"
- Added local-vs-central conflict detection: checks `16_DATABASE_GOVERNANCE.local.md`
  for API-only implications without workload declaration exceptions
- Added "stricter" pattern detection: scans `AGENTS.md` and `CLAUDE.md` for the
  ambiguous "central governance wins unless repo rules are stricter" phrasing

**`templates/bin/rp-issue-work`:**
- Added work-brief note: "Schema ownership controls schema change authority. It
  does NOT automatically determine runtime access path"
- Added reference to `DATABASE_WORKLOADS.yaml` for registered workloads

### Phase 3 — Data-Access Governance

**`docs/DATABASE_GOVERNANCE.md`:**
- Added §2b: "Schema Ownership Does Not Determine Runtime Access Path" — 10 rules
  explicitly separating schema ownership from runtime access
- Fixed §1 "stricter" language: "Repository-local files may add narrower scope
  or repository-specific declarations but may not contradict central rules"
- Fixed §1 ambiguity: "'More restrictive' ... is not automatically valid — the
  local rule must be compatible with central policy"
- Fixed §9 generated-types exemption: "non-Supabase-client access path" instead
  of "internal API"
- Fixed §13.11 access-path table: `internal_api` description now says "default
  expected path" not "Consumer repos that do not own the domain tables"
- Added silent-fallback prohibition to §13.11 rules
- Fixed §2 non-owner wording: "may read through any access path declared and
  approved per workload"

**`docs/DATABASE_OWNERSHIP.yaml`:**
- Updated `catalog_sync` domain `generated_types` from "Accesses Supabase through
  internal Worker API only" to "No direct Supabase client; see workload registry"
- Updated `catalog_sync` notes: removed "not direct Supabase client access"
  language; clarified API-only applies only to the disabled product-mirror
  workload; noted shop4 PostgREST workload as approved alternative
- Updated `product_catalog` notes: removed specific CatalogSync access-path
  restrictions; generalized to "Consumer workloads declare access paths per
  DATABASE_WORKLOADS.yaml"

**`templates/docs/16_DATABASE_GOVERNANCE.md`:**
- Fixed "stricter" language in agent instruction #7
- Fixed generated-types quick-reference entry

### Phase 4 — Workload Declaration

No changes needed to `DATABASE_WORKLOADS.yaml` — the registry schema already
includes `access_path`, `credential_owner`, `credential_contract`, `service_role_forbidden`,
rollout gates, request budgets, and change-aware write fields. The PostgREST workload
for CatalogSync shop4 was already registered.

### Phase 5 — Installer

Installer audit: no changes needed. The installer already:
- Has `--dry-run` mode
- Detects up-to-date repos
- Preserves local declarations (never overwrites `16_DATABASE_GOVERNANCE.local.md`)
- Records governance ref for upgrade detection
- Uses `is_up_to_date()` function to skip up-to-date repos

### Phase 7 — Tests

Added `tests/test_governance_rigidity_corrections.sh` with 27 tests covering:

1. Schema ownership ≠ API-only access
2. Schema consumer may be authorized runtime reader
3. Schema consumer may be authorized workload-specific writer
4. Direct PostgREST accepted when explicitly active/approved
5. Direct PostgREST rejected when undeclared
6. Internal API accepted when explicitly declared
7. Multiple adapters allowed while only one authorized
8. Silent fallback rejected
9. Consumer-owned migrations in another domain rejected
10. Stricter local rule conflict reported
11. Heuristic keyword findings remain advisory
12. Stale generated templates reported
13. Installer audit preserves local modifications
14. Unsupported service-role usage rejected
15. Existing Issue-link and documentation checks preserved

---

## Validation Evidence

| Check | Result |
|-------|--------|
| Shell syntax (`bash -n`) | PASS |
| YAML parsing (Python yaml.safe_load) | PASS - both DATABASE_OWNERSHIP.yaml and DATABASE_WORKLOADS.yaml |
| Rigidity correction tests (27 tests) | 27/27 PASS |
| Full existing test suite (162 tests) | 162/162 PASS |
| `git diff --check` | No whitespace errors |
| Secret scan | No secrets detected |
| Working tree | Clean - 9 modified files + 1 new file |

All existing test suites continue to pass with zero regressions.

---

## Compatibility Implications

- **Backward compatible** — all corrections are clarifications and additions.
  No existing governance rule is removed.
- **Breaking for agents that relied on "stricter" ambiguity** — agents that
  previously concluded "API-only is required because the repo has no schema
  ownership" will now see conflict warnings from `rp-issue-audit`. This is
  intentional.
- **Template re-sync recommended** — repositories installed with the old
  "stricter" template should re-run `rp-governance-install` after this PR merges.

---

## Repositories Requiring Re-Sync

After this PR merges, the following repositories should re-run
`rp-governance-install` to update their local templates:

- All repositories previously installed via `rp-governance-install` with
  ref <= v1.4.0

The installer will detect the version skew via `.github/governance-ref.txt`
and update `docs/16_DATABASE_GOVERNANCE.md` with the corrected language.
Repository-specific `docs/16_DATABASE_GOVERNANCE.local.md` files are never
overwritten.

---

## Recommended Follow-Up PR Order

| Order | Scope | Description |
|-------|-------|-------------|
| 1 | This PR | Central policy corrections, audit tool improvements, tests |
| 2 | CatalogSync | Fix CLAUDE.md "database consumer only" language |
| 3 | RPagentOS | Audit governance files for "stricter" pattern |
| 4 | ticket-handling | Audit governance files for "stricter" pattern |
| 5 | Other repos | Batch re-sync after central fix has settled |
| 6 | Scheduled audit | Add org-wide cross-repo governance audit workflow |

---

## Unresolved Decisions

1. **Whether `rp-issue-audit` should have a `--blocking` mode** for CI.
   Current design: the tool warns but CI does not block on heuristic findings.
   This is intentional per the v1 lightweight enforcement design. Revisit in v2.

2. **Whether the installer should have an explicit `audit` mode** separate from
   `--dry-run`. Current `--dry-run` shows what would be installed but does not
   show the diff. A separate `--audit` mode could show central-vs-local diffs.
   This is deferred as a future enhancement.

3. **CatalogSync CLAUDE.md** — should be corrected in a follow-up CatalogSync PR,
   not from this central governance PR.

---

## Version Change Log

| Version | Date | Change |
|---------|------|--------|
| v1.5.0 | 2026-07-17 | Added §2b (schema ownership vs runtime access); fixed "stricter" language; added conflict detection to rp-issue-audit; added rigidity-correction tests |
| v1.4.0 | 2026-07-16 | Added runtime workload safety, workload registry, incident response |
| v1.1.0 | 2026-07-15 | Database governance v1 baseline |
| v1.0.0 | 2026-07-10 | Issue governance and engineering standards baseline |

---

## References

- PR #3: https://github.com/retailpulses/rp-governance-kit/pull/3
- Issue #4: https://github.com/retailpulses/rp-governance-kit/issues/4
- PR #5: https://github.com/retailpulses/rp-governance-kit/pull/5
- This PR: fix/audit-issue-governance-access-rigidity
- Central policy: docs/DATABASE_GOVERNANCE.md
- Workload registry: docs/DATABASE_WORKLOADS.yaml
- Ownership registry: docs/DATABASE_OWNERSHIP.yaml
