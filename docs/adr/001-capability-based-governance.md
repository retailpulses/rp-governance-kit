# ADR-001: Capability-Based Database Governance

**Status:** Accepted
**Date:** 2026-07-17
**Governance version:** v2.0.0
**Issue:** [#22](https://github.com/retailpulses/rp-governance-kit/issues/22)

## Context

The previous database governance (v1.x) prescribed specific architectural choices:
- Consumer repositories must use `internal_api` (Worker API) rather than direct Supabase/PostgREST access.
- Specific repository-to-repository call paths were mandated (e.g., CatalogSync must call RPagentOS at runtime).
- Full workload approval records were required for all workloads regardless of risk.
- Central governance edits could block ordinary implementation changes.

This created friction:
1. Each architecture decision required a governance exception or amendment.
2. Business repositories were locked into specific transports.
3. Governance synchronization burden across repositories was high.
4. Low-risk read-only work was subject to the same controls as destructive production writes.

## Decision

Adopt capability-based governance with risk-based workload controls.

### Principles

1. **Governance defines ownership, capabilities, privilege boundaries, and production risk controls.** Business repositories choose implementation details (transport, access path, internal architecture) within those approved boundaries.

2. **Enforcement levels.** Every rule carries an explicit level: `MUST`, `MUST BEFORE PRODUCTION`, `SHOULD`, or `ADVISORY`. Pending declarations, registry updates, and credential provisioning do not block local development, tests, code review, or PR merge unless the PR itself activates a production database workload.

3. **Governance gates.** Distinct gates (code-development, code-merge, production-activation, destructive-operation) clarify when each rule is enforced.

4. **Risk-based workload controls.** Standard declaration for all workloads; extended `safety_profile` only when risk conditions apply (writes, high volume, frequent cron, privileged credentials, destructive operations, large blast radius, prior incidents).

5. **Implementation-path flexibility.** Consumer repositories may use any explicitly approved server-side access path (PostgREST, Supabase client, RPC, Supavisor, direct Postgres, or internal API), provided the access is least-privilege, declared, observable where required, and consistent with the workload's capability.

6. **Minimal synchronization.** Business repositories contain a minimal local declaration pointing to the canonical policy. Central prose edits do not require downstream repo updates. Only machine-readable contract-version changes require downstream review.

### What Changed

| Old rule | New rule |
|----------|----------|
| Consumer repos must use `internal_api` | Consumer repos may use any approved server-side access path |
| CatalogSync must call RPagentOS at runtime | CatalogSync may use approved PostgREST/Supabase access |
| All workloads need full declaration | Risk-based: standard minimum for all; extended `safety_profile` only for higher risk |
| No enforcement levels (all rules treated as blocking) | `MUST`, `MUST BEFORE PRODUCTION`, `SHOULD`, `ADVISORY` |
| Architecture-prescriptive access rules | Capability-based access rules |
| `catalog_sync` listed as a schema domain | Reclassified as `consumer_capability` domain |
| Access path enforcement: blocking check | Advisory at code-merge; blocking at production-activation |
| `internal_api` as first/default access path | `postgrest` as first access path; all paths equal citizens |
| Fixed IPs, batch sizes in ownership registry | Moved to workload registry; ownership tracks capabilities only |

### What Did Not Change

- Migration authority: only the owning repository may create/modify migrations for its domain (`MUST`).
- Migration-ledger mismatch protection: remains blocking (`MUST`).
- Historical migration integrity: no silent rewriting of deployed migrations (`MUST`).
- Secret exposure: blocking at code-merge gate (`MUST`).
- Frontend credential safety: no privileged database credentials in frontend code (`MUST`).
- N+1 amplification prohibition: remains prohibited for bulk jobs (`MUST`).
- Production activation: remains distinct from code development and code merge (`MUST BEFORE PRODUCTION`).
- High-risk/destructive operations: require dry-run and explicit review (`MUST`).
- Credential privilege must match workload capability (`MUST`).
- Incident response procedures: unchanged.

## Consequences

### Positive

- Business repositories can choose the access path that best fits their workload without governance exceptions.
- Low-risk read-only workloads require minimal declaration overhead.
- Central governance edits no longer require downstream repo synchronization.
- Clear enforcement levels prevent agents from treating all rules as universally blocking.
- CI checks are classified (BLOCKING / PRODUCTION_GATE / ADVISORY) with clear semantics.

### Risks

- More implementation freedom means more responsibility on business repos to choose correctly.
- The `SHOULD` and `ADVISORY` levels could be ignored if team culture doesn't reinforce them.
- Risk-based workload classification relies on accurate self-assessment by workload owners.

### Mitigation

- Production-activation gate catches missing controls before any workload goes live.
- CI advisory checks escalate repeated deviations to Issues.
- Periodic audits remain as a backstop.

## References

- [DATABASE_GOVERNANCE.md v2.0.0](../DATABASE_GOVERNANCE.md)
- [DATABASE_OWNERSHIP.yaml v4](../DATABASE_OWNERSHIP.yaml)
- [DATABASE_WORKLOADS.yaml v4](../DATABASE_WORKLOADS.yaml)
- [Issue #22](https://github.com/retailpulses/rp-governance-kit/issues/22)
