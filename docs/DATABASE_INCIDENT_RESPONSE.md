# Database Incident Response

Canonical organization-level database incident response playbook for Retailpulses repositories.

This document is maintained in `retailpulses/rp-governance-kit`. Repository-local files may add stricter or domain-specific steps but may not weaken central procedures. If repo-local incident procedures and this central playbook conflict, agents must stop and report the conflict.

**Version:** v1.0.0
**Last updated:** 2026-07-16

---

## 1. Scope

This playbook covers database resource-exhaustion incidents, performance degradation, outage scenarios, and recovery for all Retailpulses-hosted PostgreSQL (Supabase) databases. It does not cover application-layer incidents, network outages upstream of the database, or third-party API failures unless the database is directly affected.

## 2. Incident Classification

| Severity | Definition | Example |
|----------|-----------|---------|
| **P1 – Critical** | Database unavailable; queries fail; writes blocked | Connection pool exhausted, disk full, deadlock cascade |
| **P2 – High** | Degraded performance; elevated latency; intermittent errors | CPU sustained >95%, statement timeouts >30%, connection count near limit |
| **P3 – Medium** | Performance concern not yet user-visible; threshold breach on warning metrics | CPU sustained >70%, slow query log growth, replication lag >5s |
| **P4 – Low** | Capacity planning concern; trend detected | Disk usage growing faster than baseline, connection count trend upward |

## 3. Resource-Exhaustion Triage

### 3.1 Immediate Triage (First 5 Minutes)

When a resource-exhaustion alert fires or an operator notices database unresponsiveness:

1. **Verify the alert.** Check Supabase Dashboard → Database → Performance or direct `psql` `SELECT 1` to confirm connectivity.
2. **Identify the resource.** Determine which resource is exhausted:
   - **CPU**: Check Supabase Dashboard CPU graph or `SELECT * FROM pg_stat_activity WHERE state = 'active'`.
   - **Connections**: `SELECT count(*) FROM pg_stat_activity`.
   - **Disk**: `SELECT pg_database_size(current_database())`.
   - **Memory**: Check Supabase Dashboard memory usage.
   - **Locks**: `SELECT * FROM pg_locks WHERE NOT granted`.
3. **Identify the source.** Find the responsible query, connection, or Worker:
   - `SELECT pid, usename, application_name, client_addr, state, query_start, query FROM pg_stat_activity WHERE state != 'idle' ORDER BY query_start`.
   - Cross-reference `application_name` with known Workers and scheduled jobs.
4. **Declare severity** (P1–P4) based on user impact.

### 3.2 Evidence Capture Before Mitigation

Before killing sessions, restarting, or resizing, capture:

```sql
-- Active queries with runtime
SELECT pid, now() - query_start AS duration, state, wait_event_type, wait_event, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Lock tree
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.query AS blocked_query,
       blocking_activity.query AS blocking_query
FROM pg_locks blocked_locks
JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
  AND blocked_locks.database IS NOT DISTINCT FROM blocking_locks.database
  AND blocked_locks.relation IS NOT DISTINCT FROM blocking_locks.relation
  AND blocked_locks.page IS NOT DISTINCT FROM blocking_locks.page
  AND blocked_locks.tuple IS NOT DISTINCT FROM blocking_locks.tuple
  AND blocked_locks.virtualxid IS NOT DISTINCT FROM blocking_locks.virtualxid
  AND blocked_locks.transactionid IS NOT DISTINCT FROM blocking_locks.transactionid
  AND blocked_locks.classid IS NOT DISTINCT FROM blocking_locks.classid
  AND blocked_locks.objid IS NOT DISTINCT FROM blocking_locks.objid
  AND blocked_locks.objsubid IS NOT DISTINCT FROM blocking_locks.objsubid
  AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocked_activity ON blocked_locks.pid = blocked_activity.pid
JOIN pg_stat_activity blocking_activity ON blocking_locks.pid = blocking_activity.pid
WHERE NOT blocked_locks.granted;

-- Connection count by source
SELECT application_name, client_addr, count(*) AS connections
FROM pg_stat_activity
GROUP BY application_name, client_addr
ORDER BY connections DESC;

-- Disk usage
SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

Copy all output to the incident tracking Issue before proceeding. Do not rely on the database being available for evidence retrieval after mitigation.

### 3.3 Decision Matrix

| Symptom | First Action |
|---------|-------------|
| Connection pool exhausted | Terminate idle-in-transaction sessions first; then oldest idle sessions |
| CPU saturated | Cancel or terminate the most expensive query |
| Disk full | Identify and truncate or archive large tables/logs; do NOT VACUUM FULL until space is recovered |
| Deadlock cascade | Terminate the blocking transaction |
| Replication lag growing | Check WAL sender status; consider pausing heavy write workloads |

## 4. Emergency Shutdown

### 4.1 When to Shut Down

Emergency shutdown (terminating all database access at the application layer) is warranted when:

- The database is unresponsive and cannot be accessed to cancel individual queries.
- A destructive operation (e.g., unintended DROP, mass DELETE) is in progress and cannot be cancelled at the database level.
- The Supabase Dashboard is also unresponsive, and only the application layer can be stopped.

### 4.2 Shutdown Procedure

1. **Stop all Cloudflare Workers** that connect to the affected database (via Wrangler or Cloudflare Dashboard).
2. **Pause all cron triggers** that may start new database sessions.
3. **Kill remaining direct connections** from the Supabase Dashboard → Database → Sessions.
4. **Document** the shutdown decision with timestamp and reason.
5. **Notify stakeholders** (per §8).

### 4.3 Restart Authority

Only the infra authority (designated in `DATABASE_OWNERSHIP.yaml` or declared in the repo-local `docs/16_DATABASE_GOVERNANCE.local.md`) may restart or restore the database service. Agents and automated scripts must not attempt unsupervised restart.

## 5. Compute Resize (Emergency)

### 5.1 When to Resize

Compute resize in response to an incident is authorized when:

- CPU is sustained above 95% for 10+ minutes and query cancellation is insufficient.
- Connection limits are hit repeatedly after draining idle sessions.
- Disk I/O is the bottleneck (consider plan with higher IOPS).

### 5.2 Resize Authority

Emergency compute resize requires approval from the infra authority. If the infra authority is unavailable and the database is P1-critical, a designated backup authority (documented in `docs/16_DATABASE_GOVERNANCE.local.md`) may authorize the resize. Any resize performed without formal authority must be documented in the incident Issue within 1 hour.

### 5.3 Resize Procedure

1. Capture pre-resize evidence (§3.2).
2. Perform the resize through Supabase Dashboard or API.
3. Monitor for 15 minutes post-resize.
4. Capture post-resize metrics.
5. Document the resize in the incident Issue.

## 6. Recovery Validation

After the incident is mitigated and the database is responsive:

### 6.1 Connectivity

- Confirm `SELECT 1` from the application Worker(s).
- Verify connection pool is healthy and at expected levels.
- Confirm no idle-in-transaction sessions remain.

### 6.2 Data Integrity

- Run affected domain's smoke-test queries (reads on key tables).
- Verify recent writes (check last inserted row timestamps).
- Check for partial/rolled-back transactions that may have left inconsistent state.

### 6.3 Application Recovery

- Re-enable Workers in reverse order: read-heavy first, write-heavy last.
- Re-enable cron triggers one at a time, observing metrics for 5 minutes each.
- Verify all scheduled jobs that were suppressed during the incident have either caught up or been explicitly skipped.

### 6.4 Post-Recovery Baseline

Capture the same metrics as §3.2 and compare to pre-incident baseline. File both in the incident Issue.

## 7. Downgrade Gates

After an emergency compute resize, return to the original plan tier when:

1. 24 hours have passed without recurrence of the incident trigger.
2. Current load is confirmed within the target tier's documented limits.
3. Connection count, CPU, memory, and disk are all below 60% of the target tier's limits.
4. The downgrade is approved by the same authority that approved the resize (or infra authority if the original was emergency).

### 7.1 Downgrade Procedure

1. Schedule the downgrade during a low-traffic window.
2. Capture pre-downgrade metrics.
3. Perform the downgrade.
4. Monitor for 15 minutes.
5. Capture post-downgrade metrics.
6. Close the incident Issue with the downgrade confirmation.

## 8. Communication and Post-Incident

### 8.1 During Incident

- Create a tracking Issue in the affected repository within 30 minutes of incident declaration.
- Post status updates in the Issue as comments, at least every 30 minutes for P1/P2.
- Use the Issue to coordinate between responders.

### 8.2 Post-Incident Requirements

Within 5 business days of recovery:

1. **Root cause analysis** — a documented explanation of what caused the incident.
2. **Timeline** — a chronological log of events from detection to recovery.
3. **Impact summary** — affected services, duration, data loss (if any).
4. **Mitigations** — what was done to stop the incident.
5. **Prevention** — at least one concrete action to prevent recurrence (e.g., connection limit increase, query optimization, workload declaration update).
6. **Workload registry update** — if a workload contributed to the incident, its entry in `docs/DATABASE_WORKLOADS.yaml` must be updated with revised safety controls.
7. **Governance doc update** — if the incident revealed a gap in this policy, propose an amendment via an Issue in `rp-governance-kit`.

### 8.3 Post-Mortem Template

```markdown
## Database Incident Post-Mortem: [Date] — [Summary]

**Severity:** P1 / P2 / P3 / P4
**Database:** [project name]
**Detected:** [timestamp]
**Resolved:** [timestamp]
**Duration:** [minutes]
**Responders:** [names/roles]

### Timeline
- [HH:MM] — Alert/Detection
- [HH:MM] — Triage complete, severity declared
- [HH:MM] — Mitigation started
- [HH:MM] — Service restored
- [HH:MM] — Recovery validated

### Root Cause

### Impact

### What Went Well

### What Went Wrong

### Action Items
- [ ] ...
```

## 9. Training and Drills

- The incident response playbook must be reviewed quarterly by the infra authority.
- A tabletop drill covering a P1 incident scenario must be run at least once per six months.
- The drill result must be documented as an Issue for process improvement tracking.

---

## References

- `docs/DATABASE_GOVERNANCE.md` — canonical database governance policy
- `docs/DATABASE_WORKLOADS.yaml` — workload registry (safety controls per workload)
- `docs/DATABASE_OWNERSHIP.yaml` — domain ownership registry
- `docs/16_DATABASE_GOVERNANCE.local.md` (repo-local) — infra authority designation

## Governance

This document is part of `retailpulses/rp-governance-kit`. Changes must follow the governance repository's Issue-first workflow. The canonical GitHub URL is:

```
https://github.com/retailpulses/rp-governance-kit/blob/v1.3.0/docs/DATABASE_INCIDENT_RESPONSE.md
```
