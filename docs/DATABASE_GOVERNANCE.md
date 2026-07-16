# Database Governance

Canonical organization-level database governance policy for Retailpulses repositories.

This document is maintained in `retailpulses/rp-governance-kit`. Repository-local files may add narrower scope or repository-specific declarations but may not contradict central rules. "More restrictive" (e.g., API-only for a consumer that central policy allows to use any approved path) is not automatically valid — the local rule must be compatible with central policy. If repo-local governance files and this central policy conflict, agents must stop and report the conflict instead of guessing.

**Version:** v1.4.0
**Last updated:** 2026-07-16

---

## 1. Scope and Source of Truth

This document is the canonical organization-level database governance policy. It applies to every Retailpulses repository that:

- contains a `supabase/` directory with migrations;
- connects to a shared or dedicated Supabase project;
- generates or consumes Supabase database types; or
- queries a Retailpulses-hosted PostgreSQL database.

Repository-local `docs/16_DATABASE_GOVERNANCE.local.md` may add narrower scope or repository-specific declarations specific to that repository's domain. They may not contradict central rules, and a local rule that is merely "more restrictive" (e.g., API-only without central policy support) is not automatically valid. Conflicts require the agent to stop and report them.

## 2. Database Domain Ownership

Every schema object (table, view, function, type, trigger, RLS policy, storage bucket) has exactly one owning repository/domain. Ownership is declared in `docs/DATABASE_OWNERSHIP.yaml` in `rp-governance-kit`.

- **Owner repositories** are authoritative for their domain's schema. They create and maintain canonical migrations.
- **Non-owner repositories** may read or reference shared objects through any access path declared and approved per workload in `DATABASE_WORKLOADS.yaml` or the originating Issue. They may not alter schema objects without an explicit cross-domain declaration in `DATABASE_OWNERSHIP.yaml`. Runtime writes to data (INSERT, UPDATE, DELETE) are governed by workload declarations — schema ownership does not itself grant or prohibit them.
- **Shared-table changes** require an impact analysis that names every known consumer repository. The `DATABASE_OWNERSHIP.yaml` `consumers` field is the authoritative consumer list.
- **New shared objects** must be proposed through an Issue that identifies the owning domain and known consumers before the first migration is written.

## 2b. Schema Ownership Does Not Determine Runtime Access Path

Schema ownership and runtime access are two distinct governance dimensions. The
following rules apply:

- **Schema ownership** controls who may create, alter, or delete schema objects
  (tables, views, functions, triggers, indexes, RLS policies, storage buckets).
- **Runtime authorization** controls which workload may read or write which data
  at runtime. A repository may own no schema objects yet be an authorized runtime
  reader or writer — this is valid by design.
- **Access path** (`internal_api`, `postgrest`, `supavisor`, `direct_postgres`)
  is a per-workload decision, declared in `DATABASE_WORKLOADS.yaml` or the
  originating Issue. Schema ownership does not automatically determine the
  allowed access path.
- **A consumer repository** (listed in `DATABASE_OWNERSHIP.yaml` `consumers`)
  may use any access path that is explicitly declared and approved per workload.
  The default expectation is `internal_api`, but `postgrest`, `supavisor`, or
  `direct_postgres` are valid when:
  - the access path is declared in the workload entry;
  - the credential uses a least-privilege role provisioned by the domain owner;
  - the domain owner has approved the access path in the ownership registry or
    an Issue; and
  - service-role credentials are not used for consumer workloads.
- **Direct access is not inherently a bypass.** An undeclared or excessive
  direct-access path is a governance violation. A declared, approved, least-privilege
  direct access path is compliant.
- **"More restrictive" is not automatically "more compliant."** A local rule
  that claims API-only access is required because the repository lacks schema
  ownership is incorrect if central policy allows declared alternative paths.
  Such a local rule must be reported as a conflict, not silently accepted.
- **Business logic should remain independent of the selected source adapter**
  where practical, so that the access path can be changed without rewriting the
  workload.

## 3. Migration Authority

- Migrations remain in their domain-owning repositories. Do not move migration files between repositories merely to consolidate them.
- No repository may create canonical migrations for another domain by pulling the remote schema with `supabase db pull`. `db pull` produces a local snapshot for development; it does not transfer ownership.
- `_remote.sql` files and `remote_history_baseline.sql` files are history alignment artifacts. They document migrations that exist in the shared project but were authored in another repository. They are not ownership claims and must not contain new DDL.
- Never delete or rewrite historical migration files without a reviewed reconciliation plan that explains: why the rewrite is safe, which repos are affected, and how replay consistency is preserved.

## 4. Migration Naming

### New migrations

Use UTC timestamp names:

```
YYYYMMDDHHMMSS_description.sql
```

Examples:

```
20260715093000_add_customer_notes.sql
20260715120000_create_order_archive_view.sql
```

Timestamps must be unique across all participating Retailpulses repositories. Before creating a new migration, check `DATABASE_OWNERSHIP.yaml` for known timestamps in other repos that share the same database project.

### Historical migrations

Existing sequential names (`0001_...`, `0002_...`) and legacy timestamp formats are grandfathered. Do not rename them casually. A rename requires a reviewed reconciliation plan and must preserve the migration history chain.

## 5. Migration Quality

### Every migration file must include a header comment

```sql
-- Domain: <domain-name>
-- Owner: <owner-repo>
-- Affected: <table/view/function names>
-- Change class: additive | destructive | data
-- Hosted write required: yes | no
-- Consumers: <known consumer repos or "none">
```

### Change class definitions

| Class | Definition | Requirements |
|-------|-----------|-------------|
| `additive` | New objects, columns with defaults, or backward-compatible alterations | Standard review |
| `destructive` | DROP, rename, column removal, type change that may break consumers | Rollback plan required; consumer impact analysis required |
| `data` | INSERT, UPDATE, DELETE, or data-rewriting operations | Forward-recovery notes required; dry-run on shadow database required |

### Compatibility

- Prefer additive and backward-compatible migrations.
- A migration that requires another repository's schema objects to exist must declare those external dependencies in its header.
- Destructive or data-rewriting changes require rollback and forward-recovery notes in the migration file or an accompanying Issue comment.

### Replay and drift

- Migration replay and drift checks must run against local or shadow databases, never against the hosted production database.
- A repository that cannot replay its migration set independently from zero must declare that in `docs/16_DATABASE_GOVERNANCE.local.md` with a list of external dependencies.

## 6. Hosted Write Safety

### Read-only audit

Read-only inspection of the hosted database (schema introspection, row counts, drift detection) is permitted when credentials and project linkage have been approved.

### Hosted write operations

The following operations require explicit approval and documented deployment gates:

- `supabase db push`
- `supabase migration repair`
- `supabase db reset` (on hosted projects)
- Direct DDL or DML against the hosted database (Dashboard SQL Editor, `psql`, or any client)
- Point-in-time recovery (PITR) restore
- Storage bucket policy changes

### Pre-migration checklist

Before any production migration:

1. Confirm recent backup/PITR is available.
2. Confirm object-size prerequisites (e.g., `ALTER TABLE` on large tables may need `statement_timeout` adjustments).
3. Verify the migration replays cleanly against a shadow database.
4. Confirm all known consumers have been assessed.

### Separation of audit and remediation

Never combine read-only audit and hosted write remediation in a single automated step. Audit reports must be reviewed by a human before any remediation is applied.

## 7. Supabase CLI Policy

### Workstations

Workstations may use a globally installed Supabase CLI (e.g., Homebrew `supabase`). The installed version should be recorded in the repository's `docs/16_DATABASE_GOVERNANCE.local.md`.

### CI

CI must use an explicitly pinned Supabase CLI version. Do not use `latest` or a floating version tag for any workflow that touches migrations.

### Version mismatch

Agents must report local/CI CLI version mismatch before starting migration work. A mismatch is not automatically a failure unless:

- the repository declares a required version in `docs/16_DATABASE_GOVERNANCE.local.md`; or
- the migration uses features known to be incompatible across the detected versions.

Never use a floating CLI version for production deployment.

### Version recording

The pinned CI version and local workstation version should be recorded in `docs/16_DATABASE_GOVERNANCE.local.md`.

## 8. Access Classes and RLS

Every owned table must declare one access class in `DATABASE_OWNERSHIP.yaml`:

| Access class | Meaning | RLS requirement |
|-------------|---------|----------------|
| `worker_only` | Accessed exclusively by server-side Workers using `service_role` | RLS may be enabled with no client-visible policies. Service-role bypass is intentional. |
| `authenticated_user` | Accessed by authenticated end users through the Supabase client | Must have RLS policies granting appropriate per-user access. Must have tests. |
| `public_read` | Readable by anyone; writes restricted | Must have RLS policies. `SELECT` may use `USING (true)`. Writes must be restricted. |
| `internal_admin` | Admin dashboard or internal tool access only | Must have RLS policies restricting to admin roles. |

### Rules

- `worker_only` tables may intentionally have RLS enabled with no client-visible policies. The `service_role` key bypasses RLS. This is valid by design.
- Service-role keys must never appear in frontend code, client bundles, or public configuration.
- Direct client access (anon or authenticated Supabase client) requires explicit RLS policies and tests that verify row-level access.
- RLS findings in audits must be evaluated against the declared access class. A `worker_only` table with no policies is compliant, not a finding.
- Storage buckets require equivalent access classification in `DATABASE_OWNERSHIP.yaml`.
- Do not create meaningless `USING (false)` policies solely to satisfy a policy-count check. If a table is genuinely inaccessible to clients, document it as `worker_only` and leave policies empty.

## 9. Generated Types

### Requirement

Repositories that directly query Supabase from TypeScript/JavaScript (via `@supabase/supabase-js` or equivalent) must generate and commit database types, or reproducibly consume them from a published source.

- **Type regeneration is required** when affected schema objects (tables, views, functions) change in a migration.
- **The owner repository decides the generation path** (e.g., `src/types/database.ts`, `supabase/types.ts`).
- **Repositories accessing Supabase only through a non-Supabase-client access path** (e.g., a Cloudflare Worker that is the sole database client) may declare a generated-types exemption in `docs/16_DATABASE_GOVERNANCE.local.md`. The exemption must identify which access path applies and must remain valid: a workload that uses a direct Supabase client (supabase-js, supabase-py) through any access path is not exempt.

### Generation command

The canonical generation command should be documented in `docs/16_DATABASE_GOVERNANCE.local.md` and should use the pinned project reference (never expose the project ref in committed files).

## 10. Dashboard and Emergency Changes

### Normal operations

No normal schema changes through the Supabase Dashboard. All schema changes go through migration files in the owning repository.

### Emergency changes

Emergency Dashboard changes (e.g., fixing a production incident) are permitted but require:

1. An Issue created within 24 hours documenting the change.
2. A migration backfill committed to the owning repository within 5 business days.
3. The migration backfill must be written so it is idempotent against the already-applied change (e.g., `CREATE OR REPLACE`, `ALTER ... IF EXISTS`, or a PL/pgSQL guard).

### Migration ledger repair

If the Supabase migration ledger (`.supabase/migration_*.txt` or remote `supabase_migrations.schema_migrations`) becomes inconsistent with repository migrations, do not attempt repair without explicit authorization. Report the inconsistency and wait for guidance.

## 11. Environment Separation

### Target architecture

Production and staging should use separate Supabase projects (or separate PostgreSQL databases). Staging workloads must not write to production databases.

### Current state

Existing shared-database use (multiple repositories connecting to one hosted project) is documented technical debt. It is not an automatic blocking failure for existing repositories or existing workflows.

### New systems

New systems, new repositories, and new staging/test workloads must not be added to the production database without an explicit exception documented in an Issue and recorded in `DATABASE_OWNERSHIP.yaml`.

### Local development

Local development should use `supabase start` (local Supabase stack) where practical. Repositories that cannot run a full local stack must document the limitation in `docs/16_DATABASE_GOVERNANCE.local.md`.

## 12. Audit Cadence

The following organization-level checks should run periodically (target: monthly, or per governance release):

| Check | Description |
|-------|------------|
| Duplicate timestamps | Scan all participating repos for migration timestamps used in more than one repo with different SQL |
| Schema ownership | Verify every schema object in the hosted database has a declared owner in `DATABASE_OWNERSHIP.yaml` |
| Drift detection | Compare hosted schema against the union of all repository migrations |
| Remote-only migrations | Flag `_remote.sql` files that have no corresponding real migration in any repo |
| Generated-type drift | Flag repos where generated types are stale relative to their declared schema objects |
| CLI version divergence | Report local/CI/pinned version mismatches across repos |
| Secret exposure | Scan all repos for likely database URLs, service-role keys, or database passwords |
| Access class coverage | Flag tables in the hosted database that have no declared access class |

Audit results are non-blocking warnings by default. Repeated findings across multiple audit cycles should be escalated to Issues.

## 13. Runtime Workload Safety

Every automated or agent-driven operation that writes to, syncs with, or bulk-loads into a Retailpulses database must follow these runtime workload rules. Code review and CI can flag structural issues (migration naming, headers, ownership); runtime workload rules govern how that code executes against a live database.

### 13.1 Workload Categories

| Category | Examples | Risk level |
|----------|----------|------------|
| **Imports** | CSV/XLSX/API bulk insert into hosted tables | High — can exhaust connections, fill disk, or lock tables |
| **Syncs** | External→internal data mirroring, platform listing refresh | High — sustained load, retry storms on upstream errors |
| **Backfills** | Historical data population, schema migration data rewrites | High — long-running transactions, WAL pressure |
| **Scheduled jobs** | Cron-triggered Workers, nightly aggregation, cleanup | Medium — silent failures accumulate, cascade at scale |
| **Agent operations** | LLM→database write loops, multi-step transactional workflows | Medium — variable latency, connection holding |
| **Maintenance** | VACUUM, ANALYZE, index rebuild, connection draining | Low-to-Medium — some operations are resumable, others block writes |
| **Diagnostics** | EXPLAIN (non-ANALYZE), row count estimation, drift detection against shadow | Low — read-only but can cause contention on large tables |
| **Diagnostics (DML ANALYZE)** | EXPLAIN ANALYZE with INSERT/UPDATE/DELETE — executes mutations | High — DML ANALYZE runs the statement, not just inspects it; requires hosted-write approval |

`EXPLAIN (ANALYZE ...)` on a read-only `SELECT` is a diagnostics operation and does not mutate data. `EXPLAIN (ANALYZE INSERT ...)`, `EXPLAIN (ANALYZE UPDATE ...)`, or `EXPLAIN (ANALYZE DELETE ...)` executes the DML statement and writes to the database — these require hosted-write approval per §6. Diagnostics tools and CI checks must distinguish between the two.

### 13.2 Pre-Workload Declaration

Before running any category High or Medium workload against a hosted database, the operator (human or agent) must declare:

1. **Workload category** — from the table above.
2. **Affected domains** — which `DATABASE_OWNERSHIP.yaml` domains are touched.
3. **Expected row/byte volume** — estimated number of rows or data volume.
4. **Concurrency limit** — maximum concurrent connections this workload may open.
5. **Statement timeout** — explicit `statement_timeout` in milliseconds.
6. **Retry strategy** — exponential backoff, max retries, jitter.
7. **Kill switch** — how to abort safely (e.g., cancel a Worker invocation, SIGTERM, Supabase dashboard query cancel).
8. **Dry-run result** — evidence that a dry-run or shadow-database test completed successfully.
9. **Monitoring plan** — which metrics will be watched and through which dashboard or command.

Declarations should be recorded in `docs/DATABASE_WORKLOADS.yaml` (the workload registry) or in the work-brief Issue comment for one-off operations.

### 13.3 Batching and Pagination

- Bulk writes must be batched. No single statement should affect more than 10,000 rows without explicit approval documented in the workload declaration.
- Paginated reads (syncs, exports) must use cursor-based pagination. OFFSET-based pagination on tables over 100,000 rows is prohibited.
- Batch size and cursor strategy must be documented in the workload declaration.

### 13.4 Connection Pooling and Concurrency

Connection pooling rules depend on the access path, not the client library:

| Access path | Transport | Pooling mechanism |
|-------------|-----------|-------------------|
| `postgrest` | HTTP (PostgREST via Supabase client) | Supabase manages connection pooling server-side; no client-side pooler needed |
| `supavisor` | PostgreSQL wire protocol (port 6543) | PgBouncer / Supavisor transaction-mode pooling |
| `direct_postgres` | PostgreSQL wire protocol (port 5432) | No built-in pooling; operator must configure a connection pooler or keep connections short-lived |

- `supabase-js` (the Supabase JavaScript client) uses HTTP/PostgREST by default. This path does **not** use PgBouncer directly — the Supabase platform manages PostgREST-to-database connection pooling server-side. Do not describe `supabase-js` as connecting through PgBouncer.
- `supavisor`/PgBouncer pooling applies to **direct PostgreSQL connections** (e.g., `pg`, `psycopg2`, or Supabase client configured with `db.schema` and `db.url` pointing to port 6543).
- Direct `psql` sessions must be short-lived (under 60 seconds of idle time).
- No workload may open more than 5 concurrent database connections without explicit approval in the workload declaration.
- Connection-held transactions (idle-in-transaction) exceeding 30 seconds must be killed. Timeout enforcement is the operator's responsibility.

### 13.5 Timeouts and Retries

- Every database query must have an explicit `statement_timeout`. The default Supabase statement timeout is not a substitute for workload-level timeout configuration.
- Retries must use exponential backoff with jitter. Maximum retries: 3 per unit of work.
- Retry budgets must be tracked. A workload that exceeds 50% retries within its declared retry budget must be paused for human review.
- Dead-letter or error-recording mechanism: every Medium or High workload must have a durable retry/dead-letter/error-recording mechanism. The mechanism must be owned through the workload's approved access path (e.g., a Worker log, a CI artifact, or a structured Issue comment). Non-owner consumer repositories must not create dead-letter tables in another domain's schema. Lost rows without audit trail is unacceptable.

### 13.6 Kill Switches

Every Medium or High workload must have at least one documented kill-switch mechanism:

- **Worker-based**: cancel the Cloudflare Worker invocation (Wrangler dispatch namespace or durable object alarm cancel).
- **Dashboard-based**: terminate the session from Supabase Dashboard → Database → Sessions.
- **SQL-based**: `SELECT pg_terminate_backend(pid)` for the target session. Requires explicit production operational approval and precise target verification (pid, query, connection source) before execution. Do not terminate backends without confirming the target.
- **Deploy-based**: a rollback deploy that removes the offending trigger, cron schedule, or Worker route.

The kill-switch method must be documented in the workload declaration and tested (dry-run) before the workload goes live.

### 13.7 Approval Boundaries

All row-count thresholds below refer to **total expected rows written per invocation/run**, not per individual SQL statement. A workload that writes 5,570 single-row upserts totals 5,570 rows written and is classified accordingly. Batch-size safety (max rows per statement) is a separate concern covered in §13.3.

| Operation | Requires |
|-----------|----------|
| Total rows written ≤ 1,000 per invocation | Code review |
| Total rows written 1,001–10,000 per invocation | Workload declaration + code review |
| Total rows written > 10,000 per invocation | Workload declaration + explicit approval from domain owner + code review |
| Background/scheduled job touching database (any write volume) | Workload declaration + code review |
| Sync/external import (any volume) | Workload declaration + code review |
| Schema migration with data rewrite | Workload declaration + dry-run evidence + code review |
| Compute resize (scale-up or scale-down) | Workload declaration + explicit approval from infra authority |
| Database maintenance (VACUUM FULL, REINDEX, etc.) | Workload declaration + schedule window + code review |
| New cron/background Worker that writes to database | Workload declaration + code review + monitoring dashboard setup |
| Emergency Dashboard write (incident response) | Post-incident Issue within 24h (as per §10) |

### 13.8 Evidence Capture

After any High-category workload completes, the operator must capture and retain for 30 days:

- Start/end timestamps
- Row counts (expected vs. actual)
- Error count and sample errors
- Connection pool metrics (max used, idle timeouts)
- Statement timeout violations
- Retry budget consumed
- Kill-switch activation record (if triggered)

Evidence may be stored as a CI artifact, a Worker log entry, or a structured comment on the workload's Issue.

### 13.9 N+1 Lookup Prohibition

Per-record N+1 database or API lookups in catalog or bulk processing loops are prohibited when a bounded bulk retrieval is possible. This is one of the most common and severe resource-exhaustion patterns — a loop that fetches one record at a time for thousands of inputs can silently consume orders of magnitude more database capacity than the declared workload budget.

**Rule:** Any loop that iterates over input items and performs a database query or API call per item must instead use a bounded bulk retrieval (e.g., a single query with `IN (...)` filter, a batch GET endpoint, or cursor-paginated bulk fetch). If bulk retrieval is genuinely impossible, the workload declaration must justify why and include a request-count budget expressed against the input size.

**Request-count budget:** Every workload touching catalog or bulk processing must declare:

- `max_requests_per_invocation` — absolute ceiling on database/API requests per run.
- `max_requests_per_1000_input_rows` — maximum database/API requests per 1,000 input rows. This must scale with input size. A workload with 5,570 inputs and a target of 10–100 total requests would set `max_requests_per_invocation: 100` and `max_requests_per_1000_input_rows: 18` (i.e., 100 / 5.57 thousand ≈ 18). The formula or bound relating these two fields must be documented in the workload declaration.
- `bulk_fetch_strategy` — the method used to avoid N+1 (e.g., `IN-clause-batch`, `bulk-endpoint`, `pagination-cursor`). If `none`, the workload is rejected.

**CI contract check:** Changed code that contains a `for`/`while` loop or `.map()`/`.forEach()` containing a database client call or `fetch()` will trigger a non-blocking warning that the N+1 prohibition must be addressed or declared exempt with explicit justification in the workload declaration.

### 13.10 Change-Aware Writes

Periodic scans (scheduled syncs, reconciliation jobs, health-check writes) must not rewrite unchanged business rows solely for per-row freshness timestamps unless explicitly justified and budgeted in the workload declaration.

**Rule:** A workload that periodically scans a set of rows and writes back to them must compare incoming data against existing business columns and skip writes where no business-visible change has occurred. A "business-visible change" excludes per-row freshness timestamps, run identifiers, or scan counters unless those fields are consumed by another system that depends on per-row freshness.

**Preferred pattern:** Use a run-level freshness marker (a single metadata row or log entry recording the run timestamp and scope) rather than touching every scanned row.

**Unchanged-write ratio reporting:** Every workload that performs writes after a periodic scan must report the following change-aware metrics:

- `business_rows_changed` — rows where one or more business columns changed (a genuine business-visible update).
- `rows_written` — total rows that the workload wrote to the database (INSERT, UPDATE, or UPSERT statements). Rows that were evaluated and skipped (no write) are **not** counted in `rows_written`.
- `unchanged_rows_written` — rows written where zero business columns changed (e.g., a write triggered by a per-row freshness timestamp only). This must be zero for compliant change-aware workloads.
- `unchanged_write_ratio = unchanged_rows_written / max(rows_written, 1)`
- `write_amplification_ratio = rows_written / max(business_rows_changed, 1)` (optional)

A `unchanged_write_ratio` above 0.0 requires an explanation in the post-run evidence. A ratio above 0.1 requires explicit re-approval of the workload design. For CatalogSync's product mirror, the target is `unchanged_rows_written = 0` and `unchanged_write_ratio = 0`.

**CI contract check:** Changed code that combines a database read (`.select()` or `SELECT`) followed within the same function by a database write (`.upsert()`, `.update()`, `INSERT`, `UPDATE`) where the code path is inside a cron/scheduled trigger will flag a non-blocking warning if no change-aware write strategy is declared.

### 13.11 Access Path Declaration

Every workload must declare and follow its approved database access path. Consumer repositories must not bypass a declared internal API boundary or introduce owner-domain RPC, schema migrations, or direct client access to another domain's tables.

**Valid access paths:**

| Path | Description | When to use |
|------|------------|------------|
| `internal_api` | Accesses data through an owner-repo Worker API endpoint | Default expected path for consumer repos; alternative paths must be explicitly declared and approved |
| `supavisor` | Connects via Supabase transaction-mode pooler (port 6543) | Direct database access with PgBouncer connection pooling |
| `postgrest` | Uses Supabase REST API (PostgREST) | Lightweight queries through the Supabase client |
| `direct_postgres` | Connects directly to PostgreSQL (port 5432) | Schema operations, migrations, maintenance; requires explicit approval |

**Rules:**

- Consumer repositories of a domain (listed in `DATABASE_OWNERSHIP.yaml` as `consumers`) must follow the domain's declared approved access boundary. The binding rule is the repository/domain's approved access boundary as declared in `DATABASE_OWNERSHIP.yaml` and its workload entries in `DATABASE_WORKLOADS.yaml`. Consumers may use an access path other than `internal_api` only when that alternative path is explicitly declared and approved by the owning domain in the ownership registry or workload entry.
- CatalogSync's disabled product-mirror workload must use `internal_api`, per
  incident #23. The separately declared, read-only Mercari shop4 projection may
  use `postgrest` only with the owner-approved dedicated role, column-limited
  SELECT grants, shop-isolation policies, request limits, and workload entry.
- Owner repositories may use any path appropriate to their operation type.
- The declared access path in `DATABASE_WORKLOADS.yaml` is binding. A workload caught using a path other than its declared path is a governance violation.
- Silent fallback between access paths is prohibited. A workload that implements multiple adapters may not silently switch between them at runtime; the active path must be the declared and approved path. If a failover path is needed, it must be declared, approved, and recorded in the workload entry.
- VPS-hosted scripts that connect directly to the database must declare `direct_postgres` and include the VPS hostname in the workload declaration.

**CI contract check:** Changed code that imports a Supabase client
(`.createClient()`, `createClient`) or a PostgreSQL driver (`pg`, `postgres`,
`psycopg2`) will trigger a check that the workload declaration includes an
access path. If the importing repository is a declared consumer of another
domain in `DATABASE_OWNERSHIP.yaml`, the check verifies `internal_api` or an
explicit owner-approved exception recorded in both the ownership registry and
workload registry.

### 13.12 Scheduled Workload Release Mapping

Every scheduled production workload must be traceable to a reproducible, reviewed Git commit or release. Untracked VPS-only production source that cannot be mapped to a repository commit is prohibited.

**Rules:**

- The commit SHA or release tag that produced the currently running workload must be recorded in the workload declaration or run evidence.
- VPS-hosted scripts must be deployed from a repository branch/tag, not edited in place on the server.
- Ad-hoc `psql` scripts or hand-maintained cron entries on a VPS that interact with the shared database must be replaced by repository-tracked, reviewed code.
- The workload registry entry must include `deployed_from` (commit SHA or release tag) and `source_repo` fields.

### 13.13 Rollout Gates for High-Risk Workloads

High-risk workloads (those classified as `high` in the workload registry or any workload that performs writes to production tables in a new code path) must pass through sequenced rollout gates before being treated as operational.

**Required gates (in order):**

1. **Zero-write dry-run** — The workload executes against the production database with all write operations disabled (reads only, or writes redirected to a shadow/staging database). Evidence must be captured showing the workload logic completes without errors and produces expected read results.
2. **Bounded live canary** — A single execution against production with writes enabled but with a strict row limit (≤ 100 rows or 1% of expected volume, whichever is smaller). Must be explicitly approved by the domain owner before execution. Metrics must be captured and reviewed.
3. **Manual full run** — A full-volume execution triggered manually and monitored in real time. Must not be scheduled or automated at this stage.
4. **Scheduled cycles (minimum two)** — At least two healthy, unattended scheduled cycles must complete before the incident or feature-request Issue is closed and the workload is considered operational. "Healthy" means: no statement timeouts, no retry budget exhaustion, no kill-switch activation, zero unexpected errors, and all evidence-capture metrics within declared thresholds.
5. **Re-enable gate** — If the workload was previously disabled due to an incident (see §13.14), explicit re-approval from the infra authority is required to re-enable it. The kill switch must remain documented and testable.

**CI contract check:** PRs that add new scheduled/cron database-writing code paths trigger a non-blocking check that the PR body or linked Issue includes a rollout gate plan.

### 13.14 Current-Run Health Independence

The finalization and health assessment of the current run must be independent from stale historical-run alerts. Historical debt, prior-run failures, or unresolved audit findings must not falsely fail a successful current run.

**Rules:**

- Current-run health is determined by the metrics captured during the current invocation only: statement timeouts within this run, retry budget consumed this run, rows processed this run, errors this run.
- Historical alerts (e.g., "migration timestamp collision from 6 months ago", "stale generated types") must be tracked as separate governance Issues or audit findings and must not block current-run completion or mark it as failed.
- A current-run finalization report must clearly separate "this run" metrics from "known historical debt" items.
- Monitoring dashboards and alerting must distinguish "current run failure" from "historical governance finding" so that operators are not woken up for pre-existing, reviewed issues.

**Run finalization report template:**

```markdown
## Run Finalization: [workload_id] — [timestamp]

### This Run
- Rows read: N
- Rows compared: N
- Business rows changed: N
- Rows written: N
- Unchanged rows written: N
- Unchanged-write ratio: N
- Write amplification ratio: N
- Batch count: N (failures: N)
- Runtime: N seconds
- Retries: N / budget N
- Dead letters: N
- API requests: N (path: [access_path])
- Errors: N (sample: ...)
- Statement timeouts: N
- Kill-switch activated: yes / no

### Historical Debt (does not affect this run's pass/fail)
- [List of known, pre-existing issues with Issue refs]

### Status: PASS / FAIL (based on this run only)
```

## 14. Resource Management

### 14.1 Compute Resize

Supabase compute (e.g., micro → small → medium) changes require:

1. A workload declaration documenting the reason, expected duration, and downgrade plan.
2. Explicit approval from the infra authority (not self-serve by agents or automated scripts).
3. A documented rollback window: the resize must be reversed within the declared window unless re-approved.
4. Evidence of pre-resize baseline metrics captured (CPU, memory, connections, query latency).

### 14.2 Downgrade Gates

Before downgrading compute:

1. Verify no scheduled High-category workloads are active or imminent.
2. Confirm current connection count and query load are within the target plan's documented limits.
3. Capture a post-resize baseline within 1 hour of the downgrade.
4. File a workload declaration recording the downgrade with pre/post metrics.

### 14.3 Monitoring Thresholds

Workloads must define monitoring thresholds. At minimum:

| Metric | Warning threshold | Critical threshold |
|--------|-------------------|---------------------|
| Active connections | 80% of plan limit | 95% of plan limit |
| CPU utilization (sustained 5 min) | 70% | 90% |
| Statement timeout rate | >5% of queries | >15% of queries |
| Retry budget consumed | >30% | >50% |
| Disk usage | 80% | 90% |
| Replication lag (if applicable) | >5 seconds | >30 seconds |
| **Per-workload request budget consumed** | >70% of `max_requests_per_invocation` | >100% of `max_requests_per_invocation` |
| **Per-workload rows written** | >80% of declared `expected_volume_rows` | >150% of declared `expected_volume_rows` |
| **Per-workload unchanged-write ratio** | >0.0 (any unchanged rows written) | >0.1 |

The last three thresholds (request budget, rows written, unchanged-write ratio) are required because incident #23 was triggered by request/write amplification without connection saturation. Connection-pool and CPU metrics alone would not have caught the 5,570 single-row upserts that exhausted database capacity through request volume rather than connection count.

Thresholds should be declared in `docs/DATABASE_WORKLOADS.yaml` for recurring workloads or in the workload declaration for one-off operations.

## 15. Reporting and Governance

### 15.1 Workload Registry

All recurring database workloads must be registered in `docs/DATABASE_WORKLOADS.yaml`. One-off workloads must be declared in their originating Issue or work brief. The registry is the authoritative inventory of what runs against which database and with what safety controls.

### 15.2 Incident Escalation

See `docs/DATABASE_INCIDENT_RESPONSE.md` for resource-exhaustion, outage, and recovery procedures. Any workload that triggers a critical monitoring threshold must be escalated per the incident response playbook.

### 15.3 Compliance

- CI checks (database-governance-checks.yml) verify workload declarations exist when code changes introduce new database-writing paths.
- Periodic audits (§12) include workload-registry completeness checks.
- Unregistered workloads discovered during audits are treated as governance violations and must be remediated.

---

## References

- `docs/DATABASE_OWNERSHIP.yaml` — machine-readable domain ownership registry
- `docs/DATABASE_WORKLOADS.yaml` — machine-readable workload registry
- `docs/DATABASE_INCIDENT_RESPONSE.md` — incident response playbook
- `docs/16_DATABASE_GOVERNANCE.md` (repo-local) — installed reference pointing to this canonical policy
- `docs/16_DATABASE_GOVERNANCE.local.md` (repo-local) — repository-specific declarations
- `docs/12_DATA_ACCESS_AND_SECRETS.md` (repo-local) — secrets handling and data access patterns
- `.github/workflows/database-governance-checks.yml` — reusable CI enforcement

## Governance

This document is part of `retailpulses/rp-governance-kit`. Changes must follow the governance repository's Issue-first workflow. The canonical GitHub URL is:

```
https://github.com/retailpulses/rp-governance-kit/blob/v1.4.0/docs/DATABASE_GOVERNANCE.md
```
