# Migration Note: v1.4.0 → v2.0.0

**Date:** 2026-07-17
**Issue:** [#22](https://github.com/retailpulses/rp-governance-kit/issues/22)

## What changed

### 1. Enforcement levels added

Every governance rule now carries an explicit enforcement level:
- `MUST` — universally binding, blocking at code-merge gate
- `MUST BEFORE PRODUCTION` — binding before production activation, does not block development/merge
- `SHOULD` — strong recommendation, deviations require documented justification
- `ADVISORY` — best-practice guidance, non-blocking

A pending workload declaration, ownership registry update, credential issuance, or production rollout record does **not** block local development, tests, code review, or PR merge unless the PR itself activates a production database workload.

### 2. Governance gates distinguished

| Gate | When | What it blocks |
|------|------|---------------|
| Code-development | Local dev, testing, review | Nothing — advisory only |
| Code-merge | PR merge time | `MUST` rules verifiable from PR diff |
| Production-activation | Before production workload | `MUST BEFORE PRODUCTION` + runtime `MUST` rules |
| Destructive-operation | Before DROP/TRUNCATE/data rewrite | All `MUST` + domain owner + infra authority approval |

### 3. Consumer access paths relaxed

**Before:** Consumer repositories of a domain must use `internal_api`. Direct Supabase/PostgREST access was treated as inherently exceptional.

**After:** A consumer repository may use any explicitly approved server-side access path (PostgREST, Supabase client, RPC, Supavisor, direct Postgres, or internal API), provided the access is least-privilege, declared, observable where required, and consistent with the workload's read/write capability.

Governance approves the capability and risk boundary. Business repositories choose the transport within those boundaries.

### 4. Why direct Supabase/PostgREST access is no longer treated as inherently exceptional

- PostgREST is the default transport for Supabase's own client libraries.
- Server-side PostgREST access with scoped credentials is architecturally equivalent to an internal API for most read workloads.
- The risks that drove the old rule (credential exposure, N+1 amplification, connection exhaustion) are addressed by the capability-based rules: credential class, access path declaration, request budgets, and kill switches.
- The Supabase platform manages PostgREST-to-database connection pooling server-side.

### 5. How production activation remains protected

- `MUST BEFORE PRODUCTION` rules gate production activation without blocking development.
- High-risk workloads still require: workload declaration, dry-run evidence, canary, kill switch, monitoring thresholds, and rollout gates.
- Credential provisioning and deployment remain separate from code merge.
- The production-activation gate catches missing controls before any workload goes live.

### 6. How business repositories should reference central governance

Each business repo should contain a minimal local declaration:

```markdown
## Database governance

Canonical policy: `retailpulses/rp-governance-kit`

This repository:
- does not own migrations for the `<domain>` domain;
- may use approved server-side read paths declared in the central registry;
- must not expose privileged database credentials to frontend code;
- must follow production activation controls for writing or high-risk workloads.

Repository-specific details are documented locally.
```

Do **not** copy the complete governance document into each repository. Central prose edits do not require downstream repo updates.

### 7. YAML schema changes

**DATABASE_OWNERSHIP.yaml** (v3 → v4):
- Added `domain_type` field (`schema` | `consumer_capability`)
- Consumer entries now include `capabilities` (read/write/schema_change) and `permitted_access_classes`
- Removed implementation details from notes (fixed IPs, batch sizes, kill-switch procedures)
- `catalog_sync` reclassified as `consumer_capability` domain

**DATABASE_WORKLOADS.yaml** (v3 → v4):
- Standard declaration (minimum for all workloads): `workload_id`, `owner_repo`, `domain`, `mode`, `access_path`, `credential_class`, `trigger`, `status`, `kill_switch`
- Extended `safety_profile` only required when: writes, high volume, frequent cron, privileged credential, destructive operations, large blast radius, or prior incident
- Removed excessive per-field documentation; replaced with risk-based schema header

### 8. CI check classification

All CI checks now display their classification:
- `BLOCKING` — migration naming, duplicate timestamps, migration docs impact, secret detection, migration headers, cross-domain owner
- `PRODUCTION_GATE` — runtime impact declaration
- `ADVISORY` — N+1 detection, change-aware write detection, access path enforcement, run health independence, migration warnings, org-wide duplicate timestamps

Advisory checks do not block merge. They inform. Production-gate checks block production activation, not merge.

The `runtime-impact-declaration` job no longer classifies files as high-risk based on filename patterns (`sync`, `import`, `backfill`). Classification is based on actual DB operations detected in the code.

The `access-path-enforcement` job no longer requires `internal_api` for consumer repositories. It advises declaring an access path consistent with permitted access classes.

## What did not change

- Migration authority (only owning repo creates/modifies migrations for its domain)
- Migration-ledger mismatch protection (remains blocking)
- Historical migration integrity (no silent rewriting)
- Secret exposure (blocking at code-merge)
- Frontend credential safety (no privileged credentials in frontend code)
- N+1 amplification prohibition
- Production activation distinct from code development/merge
- High-risk/destructive operations require dry-run and explicit review
- Credential privilege must match workload capability
- Incident response procedures

## Downstream repo action

No downstream action is **required**. Business repositories with local copies of the governance reference will receive updates through the standard `rp-governance-install` upgrade process.

Business repos that contain conflicting local wording (e.g., "must use internal Worker API", "not direct Supabase client") should be updated when convenient, but this is not blocking.

### Classification for related repositories

| Repository | Status | Action |
|-----------|--------|--------|
| `retailpulses/RPagentOS` | Not inspected locally | Should adopt capability-based language in local governance docs when convenient |
| `retailpulses/CatalogSync` | Not inspected locally | May now use scoped read-only PostgREST without architecture exception; update local declaration |
| `retailpulses/ticket-handling` | Not inspected locally | No required changes; check for stale `internal_api`-only language |
| `retailpulses/OrderMgmt` | Not inspected locally | No required changes |

None of these repositories were available locally during this change. A follow-up inspection is recommended.
