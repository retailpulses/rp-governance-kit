# Sync Workload Governance

Canonical organization-level sync workload governance policy for Retailpulses repositories.

This document is maintained in `retailpulses/rp-governance-kit`. Repository-local files may add stricter rules but may not weaken central rules. If repo-local governance files and this central policy conflict, agents must stop and report the conflict instead of guessing.

**Version:** v1.0.0
**Last updated:** 2026-07-19

---

## Governance Principle: Invariants, Not Implementations

Governance defines **invariants** — conditions that must always hold true for every production sync workload. It does not prescribe **implementations** — how a repository satisfies those conditions.

| Invariant (governance concern) | Implementation (repository concern) |
|-------------------------------|-------------------------------------|
| Every production job must have a stable workload ID | `catalogsync_mercari_shop1_full` |
| No accidental duplicate writer to an external system | Mercari Full and Priority coordinate through a shared `flock` |
| Every effectful workload must have a kill switch | Environment variable, lock file, or cron comment-out |
| Runtime source must be traceable to a reviewed commit | VPS symlink to `/opt/catalogsync/releases/<sha>/` |

When a rule mixes invariant and implementation, the invariant binding applies. The implementation is advisory unless the invariant cannot be satisfied any other way.

---

## Enforcement Levels

| Level | Meaning | Agent behavior |
|-------|---------|---------------|
| `MUST` | Universally binding. No exceptions without explicit approval. | Blocking at code-merge gate. |
| `MUST BEFORE PRODUCTION` | Binding before production activation. Does not block local development, tests, code review, or PR merge. | Blocking at production-activation gate only. |
| `SHOULD` | Strong recommendation. Deviations require documented justification. | Advisory; repeated deviations escalate. |
| `ADVISORY` | Best-practice guidance. Informational. | Non-blocking; informational. |

### Governance Gates

| Gate | When it applies | What it blocks |
|------|----------------|-----------------|
| **Code-development** | Local development, testing, code review | Nothing — advisory only. Pending inventory updates do not block development. |
| **Code-merge** | At PR merge time | Rules labeled `MUST` that are verifiable from the PR diff. |
| **Production-activation** | Before a workload goes live | Rules labeled `MUST BEFORE PRODUCTION` and all `MUST` rules requiring runtime context. |

**Principle:** A pending inventory update does not block local development, tests, code review, or PR merge unless the PR itself activates a production workload. Declarations must be complete before production activation.

---

## 1. Scope

This policy applies to recurring or event-driven jobs that move or reconcile data between systems:

- Marketplace order imports
- Inventory and price pushes
- Shipment confirmation
- Ticket/email ingestion
- Internal projections (e.g., Baserow → Supabase)
- Scheduled reconciliation
- Recurring maintenance that changes business state

**Excluded:**

- Ordinary HTTP request handlers
- Local development scripts
- CI validation with no production side effects
- One-off read-only investigations

---

## 2. Workload Classification

### Kind

| Kind | Description |
|------|-------------|
| `pull` | Ingest data from an external system into internal stores |
| `push` | Send internal data to an external system |
| `reconcile` | Compare two systems and report or fix discrepancies |
| `projection` | Transform data from one internal store to another |
| `maintenance` | Recurring housekeeping that changes business state |

### Effect

| Effect | Description |
|--------|-------------|
| `read_only` | No writes to any system |
| `internal_write` | Writes only to internal databases/stores |
| `external_write` | Writes to external platforms (marketplaces, carriers, payment providers) |

### Risk Derivation

| Effect | Default risk | Examples |
|--------|-------------|----------|
| `read_only` | Low | Reconciliation, reporting, read-only API pulls |
| Idempotent, bounded `internal_write` | Medium | Order import, message sync, internal projection |
| `external_write` | High | Shipment confirmation, cancellation push, payment submission |
| Destructive or difficult-to-reverse | High + explicit approval | Bulk close, data purge, price overwrite |

Repositories may override the default risk with a documented explanation in the local inventory.

---

## 3. Workload Identity

### `MUST` — Stable Workload ID

Every production sync workload must have a permanent, unique ID using `lower_snake_case`:

```
catalogsync_mercari_shop1_full
ordermgmt_rakuten_order_pull
ordermgmt_giga_shipment_build
ticket_share_event_api
```

The ID must not change across releases, deployments, or runtime migrations. Retired IDs must not be reused.

### `MUST` — Canonical Implementation

Every workload must declare:

- Owner repository
- Canonical source path within that repository
- Deployment entrypoint (Worker route, VPS script path, systemd unit)

Agents must not edit production files directly under runtime directories (e.g., `/opt/.../releases/`). All changes must flow through the canonical source path.

---

## 4. Inventory

### `MUST` — Inventory Update

A change to a production sync workload must update the local inventory (`docs/SYNC_JOB_INVENTORY.md`) when it changes any of these governed facts:

- Trigger or schedule
- Source or target system
- Production entrypoint
- Write behavior (read_only → internal_write, internal_write → external_write, new target field)
- Concurrency relationship (new overlapping writer)
- Kill switch mechanism
- Lifecycle state (active → migrating → retiring → retired)
- Replacement or retirement of another workload

Bug fixes that do not change governed facts do **not** require an inventory update.

### `MUST` — Overlapping Writers

A new writer to a business field that already has another writer must declare:

- Existing writer workload IDs
- Why coexistence is safe (e.g., disjoint time windows, shared lock, different field subsets)
- Locking or idempotency mechanism
- Retirement plan where the new writer replaces an existing one

---

## 5. Production Safety

### `MUST BEFORE PRODUCTION` — Effectful Workload Safety

For every `internal_write` and `external_write` workload:

- **Kill switch:** documented mechanism to disable the workload without code deployment
- **Bounded concurrency:** no unbounded parallel execution
- **Bounded retry:** retries must be capped with backoff; no infinite retry loops
- **Idempotency or duplicate prevention:** the workload must be safe to run more than once, or must detect and skip already-processed items
- **Traceable source:** runtime code must be traceable to a reviewed commit or release

### `MUST BEFORE PRODUCTION` — External Business Commands

Workloads that send business commands to external platforms (shipment confirmation, cancellation, order acceptance, payment) must additionally declare:

- **Idempotency key:** the field or composite key used for safe retry
- **Unknown-result handling:** a timeout after submission must not automatically mean "failed" — the result may be unknown and require marketplace-state reconciliation
- **Reconciliation path:** how to detect and correct mismatches between submitted commands and actual platform state

### `MUST BEFORE PRODUCTION` — New High-Risk Workload

Before production activation of a new high-risk workload:

1. Dry-run or compare-only evidence (no side effects)
2. Bounded canary (limited scope, verified before full run)
3. Rollback or disable procedure

The full five-stage database rollout sequence (dry-run → ≤100-row canary → manual full run → two scheduled cycles) is required only for genuinely high-risk broad database writers. Low-volume idempotent order pulls or read-only projections do not require the full sequence.

---

## 6. Observability

### `SHOULD`

Each production workload should produce:

- Run summary (start time, end time, outcome)
- Request count (API calls to external systems)
- Rows or items processed
- Errors and retries (count, not full payloads)
- Checkpoint or cursor description (so the next run knows where to resume)
- Expected freshness (maximum acceptable staleness for the data this workload produces)
- Dead-letter or quarantine mechanism for items that fail repeatedly

### `ADVISORY`

Exact numeric thresholds are repository-controlled, not centrally mandated. The invariant is **bounded and observable**:

- Retry count, connection pool size, batch size, warning thresholds, and evidence retention periods should be declared in the local inventory with a rationale
- Universal numbers (e.g., "3 retries for every workload") are anti-patterns — a 30-minute full sync and a 30-second priority sync have different failure characteristics

---

## 7. Database Governance Boundary

This policy governs sync workload identity, external-platform side effects, scheduler inventory, and workload lifecycle. Database-specific concerns (access paths, credentials, schema ownership, migration discipline, connection limits, query safety) are governed by `docs/DATABASE_GOVERNANCE.md`.

Workloads registered in `docs/DATABASE_WORKLOADS.yaml` for shared-database risk governance must reference their local inventory. The central database workload registry is a **database-risk registry**, not a master inventory of all sync behavior.

---

## 8. Agent Preflight Checklist

`MUST`

Before creating, changing, replacing, enabling, disabling, or deleting a production sync workload, the agent must:

1. Read `docs/SYNC_JOB_INVENTORY.md`.
2. Identify the existing workload ID, or confirm that this is a new job.
3. Search for existing jobs with the same source, target, or write scope.
4. Inspect the canonical source and deployment entrypoint.
5. Identify overlapping writers and concurrency controls.
6. Confirm idempotency, retry, checkpoint, and kill-switch behavior.
7. Verify runtime state when production behavior may be affected.
8. Update the inventory in the same PR when governed facts change.
9. Report repository/runtime mismatches as governance drift — do not auto-remediate.
10. Include cutover and retirement steps when replacing another job.

---

## 9. Governance Drift

A difference between the local inventory and runtime observed reality is **governance drift**. Drift is a signal to investigate, not automatic permission to modify either side.

When drift is detected:

1. Report it (in the PR, issue, or closeout).
2. Determine which side is authoritative for each fact:
   - **Schedule, entrypoint, kill switch:** the inventory is the intended state; runtime should match.
   - **Current release SHA, runtime host:** runtime is the truth; inventory should be updated.
3. Do not resolve drift by silently editing runtime configuration or by silently updating the inventory to match observed-but-unapproved runtime state.

---

## References

- `docs/DATABASE_GOVERNANCE.md` — Database-specific workload risk governance
- `docs/DATABASE_WORKLOADS.yaml` — Shared-database risk registry
- `docs/SYNC_JOB_INVENTORY.md` (per-repo) — Authoritative local workload inventory
- `templates/docs/SYNC_JOB_INVENTORY.template.md` — Inventory template for new repos
- `templates/docs/17_SYNC_WORKLOAD_GOVERNANCE.md` — Installable local reference
