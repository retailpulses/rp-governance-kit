# Sync Job Inventory

Baseline status: reconstructed | verified
Last runtime verification: YYYY-MM-DD
Inventory owner: <repo-owner>

## Authority

This file is the authoritative repository record of intended and known production sync workloads. Runtime infrastructure (VPS crontab, systemd timers, Cloudflare Cron Triggers, GitHub Actions schedules) is the source of truth for what is currently executing. Differences between this inventory and runtime are **governance drift** — a signal to investigate, not automatic permission to modify either side.

Governance invariants are defined in the canonical `SYNC_WORKLOAD_GOVERNANCE.md` policy in `retailpulses/rp-governance-kit`.

## Workloads

| Workload ID | Purpose | Kind / Effect | Runtime | Trigger | Source → Target | Entrypoint | Lifecycle | Deployment | Operational |
|---|---|---|---|---|---|---|---|---|---|
| <id> | <one-line> | pull / internal_write | ConoHa VPS | `*/10 * * * *` | Supabase → Mercari | `/opt/<repo>/releases/<sha>/scripts/<file>` | active | deployed | healthy |

## Workload Details

### <workload_id>

- **Purpose:**
- **Kind / Effect / Risk:**
- **Runtime host:**
- **Trigger / Schedule:**
- **Canonical source:** `scripts/<path>`
- **Deployment entrypoint:** `/opt/<repo>/releases/<sha>/scripts/<file>` or Worker route
- **Source system(s):**
- **Target system(s):**
- **Kill switch:** <mechanism and how to activate>
- **Idempotency / deduplication:** <strategy>
- **Checkpoint / replay:** <how to resume or replay from a known state>
- **Overlapping writers:** <none | list of workload IDs and coordination mechanism>
- **Upstream dependencies:** <workloads or services this job depends on>
- **Downstream consumers:** <workloads or services that depend on this job's output>
- **Known limitations:**
- **Runtime verification:** <command to verify current runtime state>

---

## State Definitions

### Lifecycle State

| State | Meaning |
|-------|---------|
| `active` | Intended to run in production |
| `migrating` | Moving between runtimes, repos, or schedules |
| `retiring` | Scheduled for removal; still running during transition |
| `retired` | No longer running; retained for historical reference |

### Deployment State

| State | Meaning |
|-------|---------|
| `scheduled` | Registered in scheduler (cron, timer, CF trigger) |
| `deployed` | Code is present on the runtime host |
| `disabled` | Scheduler entry exists but is commented out or stopped |
| `absent` | No scheduler entry or deployed code on the runtime host |

### Operational State

| State | Meaning |
|-------|---------|
| `healthy` | Running successfully within expected parameters |
| `degraded` | Running with known issues; output still usable |
| `broken` | Failing; output unreliable or absent |
| `paused` | Intentionally stopped by operator |
| `unknown` | Runtime state has not been verified recently |

---

## Drift Log

| Date | Workload ID | Drift description | Resolution |
|------|-------------|-------------------|------------|
| | | | |

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| v0.1.0 | YYYY-MM-DD | Initial template — baseline reconstructed |
