# ADR-002: Central Governance vs Local Repository Governance

**Status:** Accepted
**Date:** 2026-07-17
**Governance version:** v1.5.0
**Issue:** [#22](https://github.com/retailpulses/rp-governance-kit/issues/22)

## Context

The governance kit (v1.4.0) installed a canonical policy reference (`16_DATABASE_GOVERNANCE.md`) and a local declaration (`16_DATABASE_GOVERNANCE.local.md`) into each business repository. However, the boundary between central and local governance was unclear:

- Central policy contained architecture-prescriptive rules (e.g., "must use `internal_api`") that dictated implementation choices in business repos.
- Business repos sometimes duplicated central policy wording, creating drift.
- Central prose edits could trigger perceived downstream synchronization obligations.
- Workload declarations were fully centralized in `DATABASE_WORKLOADS.yaml`, requiring governance-repo edits for every new workload.

This ADR defines what belongs centrally and what belongs locally.

## Decision

### What belongs centrally (`rp-governance-kit`)

1. **Ownership.** Who owns each database domain and what schema objects belong to it. (`DATABASE_OWNERSHIP.yaml`)
2. **Capabilities.** What each repository may do with each domain — read, write, schema_change. (`DATABASE_CAPABILITIES.yaml`)
3. **Access policy.** What access paths and credential classes are permitted per consumer per domain. (`DATABASE_ACCESS_POLICY.yaml`)
4. **Invariants.** Rules that must always hold: migration authority, migration-ledger integrity, secret safety, N+1 prohibition, production write controls, credential privilege matching capability. (`DATABASE_GOVERNANCE.md`)
5. **Enforcement levels and gates.** When rules are enforced and who enforces them.
6. **Incident response.** How to handle database incidents.
7. **Workload index.** A central index of production workloads, with safety profiles for high-risk workloads. (`DATABASE_WORKLOADS.yaml`)

Central governance changes that do not alter machine-readable contracts (YAML schema changes, new invariant rules) do not require downstream repository updates.

### What belongs locally (each business repository)

1. **Local declaration.** A minimal YAML or markdown file declaring:
   - Which governance version is referenced
   - Which domains this repo owns (if any)
   - Which domains this repo consumes (if any)
   - Any repository-specific constraints stricter than central policy
2. **Workload manifests.** If the repo hosts database workloads, a local manifest per workload. The central registry indexes these rather than being the sole source of truth.
3. **Runtime configuration.** Kill-switch identifiers, credential references (never values), schedule configuration, runtime host.

Local declarations are authoritative for repo-specific details. They must not weaken central invariants.

### What should never be duplicated

1. The full central governance policy text.
2. Ownership declarations that belong in `DATABASE_OWNERSHIP.yaml`.
3. Access policy rules that belong in `DATABASE_ACCESS_POLICY.yaml`.
4. Capability declarations that belong in `DATABASE_CAPABILITIES.yaml`.
5. Incident response procedures.
6. Enforcement level definitions.

If a business repo contains the same rule as central governance, one of them is in the wrong place.

### Central repo as index, not sole source

For workload declarations, the design evolves toward:

```
rp-governance-kit/
    docs/
        DATABASE_WORKLOADS.yaml          # index of all workloads

CatalogSync/
    governance/
        local.yaml                       # repo declaration
        workloads/
            shop4_read.yaml              # workload manifest
            marketplace_projection.yaml  # workload manifest
```

The central `DATABASE_WORKLOADS.yaml` entries reference the repo-local manifest. Repo-local manifests are the primary source; the central registry is the consolidated view.

This reduces governance-repo edits for new workloads: a repo can add a local workload manifest first, then register it centrally as a separate step (at the production-activation gate).

### Minimal business repo pattern

Each business repo should contain:

```
governance/
    local.yaml
```

Example:

```yaml
governance_version: "v1.5.0"

references:
  database:
    owner: retailpulses/rp-governance-kit

domains_owned:
  - ticketing              # only if this repo owns migrations

domains_consumed:
  - product_catalog        # from DATABASE_CAPABILITIES.yaml

workloads:
  - catalogsync_shop4_read
  - catalogsync_marketplace_projection_api_read

# Repository-specific constraints (stricter than central, if any)
constraints:
  service_role_forbidden: true
  database_writes_forbidden: true
```

Everything else — ownership, capabilities, access policy, invariants, incident response — comes from the governance repo.

## Consequences

### Positive

- Clear separation prevents central governance from creeping into implementation territory.
- Business repos carry minimal governance weight.
- Central prose edits don't require downstream synchronization.
- Workload manifests can be added locally without central-repo edits for every workload.

### Risks

- The "central as index" model requires tooling to validate consistency between local manifests and the central registry. Without validation, drift is possible.
- Repos that add workloads locally without central registration could evade production-activation gates.

### Mitigation

- The production-activation gate requires a central workload registry entry before production activation.
- A scheduled or manual drift check compares local workload manifests against the central index.
- CI checks in business repos verify that local manifests are consistent with central capabilities and access policy.

## References

- [ADR-001: Capability-Based Database Governance](001-capability-based-governance.md)
- [DATABASE_GOVERNANCE.md v1.5.0](../DATABASE_GOVERNANCE.md)
- [Issue #22](https://github.com/retailpulses/rp-governance-kit/issues/22)
