## Linked Issue

<!-- Reference the GitHub Issue this PR addresses -->
<!-- Must use one of: Refs #..., Related to #..., Issue #..., Closes #..., Fixes #..., Resolves #... -->

## What Changed

<!-- Brief description of the changes -->

## Why

<!-- Motivation for the change -->

## Change Classification

- [ ] Patch — bounded correction inside existing architecture
- [ ] Feature — material behavior change inside established boundaries
- [ ] Feature with bounded Phase — multi-PR/staged/major workflow change
- [ ] Architecture Change — changes architecture model; Phase + decision + reconciliation required

**Phase / change boundary (if applicable):**

## User Impact

<!-- How does this affect end users? -->

- [ ] No user-facing change
- [ ] Changes user workflow — describe:

## System Impact

<!-- Does this change system structure, APIs, ownership, runtime topology, or agent workflows? -->

- [ ] No system impact
- [ ] Database migration
- [ ] Schema/types changed
- [ ] Routes/pages changed
- [ ] Interface/API contract changed
- [ ] Data/domain ownership changed
- [ ] Runtime/deployment topology changed
- [ ] Production workload/scheduling model changed
- [ ] Security/trust boundary changed
- [ ] Major workflow/invariant changed
- [ ] Agent configuration changed
- [ ] Other:

## Architecture Impact

- [ ] No architecture impact; current `docs/01_ARCHITECTURE.md` remains accurate
- [ ] Architecture affected; relevant current architecture was read before implementation
- [ ] ADR/decision record added or updated
- [ ] `docs/01_ARCHITECTURE.md` reconciled to resulting current state
- [ ] `docs/00_CURRENT_STATE.md` reconciled if operational state changed
- [ ] Replaced/legacy architecture explicitly marked
- [ ] Runtime activation was verified where required, or clearly recorded as not runtime-verified

<!-- If architecture changed, summarize current -> target/resulting architecture and link the Phase/decision. -->

## Data Model Impact

<!-- Does this require new tables, columns, or migrations? -->

- [ ] No data model changes
- [ ] Existing tables reused
- [ ] New tables/columns added — justify:

## Governance Standards Review

- [ ] Issue governance passed before work
- [ ] Engineering principles followed
- [ ] Change classification is proportional to architectural consequence
- [ ] Canonical architecture read for architecture-affecting work (or N/A)
- [ ] Frontend standards followed (or N/A)
- [ ] Frontend stack follows React + Vite + TypeScript (or N/A)
- [ ] If frontend stack differs, exception documented (or N/A)
- [ ] Supabase / secrets access safe (or N/A)
- [ ] No new Baserow dependency introduced
- [ ] No new Cloudflare-specific coupling introduced
- [ ] Existing canonical tables reused before creating new tables (or N/A)
- [ ] Documentation/reconciliation completed where needed

## Documentation Impact

- [ ] No docs changes needed
- [ ] docs/00_CURRENT_STATE.md updated
- [ ] docs/01_ARCHITECTURE.md updated/reconciled
- [ ] docs/05_DECISION_LOG.md / ADR updated
- [ ] Phase document updated/closed
- [ ] Other docs updated:

## Verification

<!-- How was this tested? Distinguish repository evidence from live-runtime evidence. -->

- [ ] Typecheck passes (or N/A)
- [ ] Build passes (or N/A)
- [ ] Tests pass (or N/A)
- [ ] Manually verified (or N/A)
- [ ] Deployment evidence captured (or N/A)
- [ ] Runtime verified where activation matters (or N/A)

## Runtime Database Impact

<!-- Does this change introduce or modify database workloads at runtime? -->
<!-- Applies to: Workers, scripts, cron jobs, syncs, imports, backfills, agent operations -->

- [ ] No runtime database impact
- [ ] Changes existing database workload — describe:
- [ ] Adds new database-writing code (Worker, script, cron, sync, import)
- [ ] Adds new scheduled/background job that touches the database
- [ ] Adds bulk insert/update/delete (>1,000 rows)
- [ ] Changes connection pooling or concurrency behavior
- [ ] Changes statement timeout or retry configuration

### Workload Declaration

<!-- Complete when this PR adds or changes a database workload. -->

- **Workload category:** imports | syncs | backfills | scheduled_jobs | agent_operations | maintenance | diagnostics
- **Affected tables:**
- **Expected row volume per invocation:**
- **Expected request count per invocation:**
- **Expected runtime (seconds):**
- **Concurrency max:**
- **Statement timeout (ms):**
- **Retry strategy:**
- **Batch size:**
- **Access path:** internal_api | supavisor | postgrest | direct_postgres
- **Source commit/release:**
- **Kill-switch method:**
- **Kill-switch identifier:**
- **Workload registry entry:**
- [ ] Workload registry updated in `docs/DATABASE_WORKLOADS.yaml` (if recurring)
- [ ] Workload declared in `docs/16_DATABASE_GOVERNANCE.local.md` (if repo-local)
- [ ] Dry-run or shadow-database test evidence attached

### N+1 Lookup Safeguard

- [ ] No N+1 lookups — all database/API calls use bulk retrieval
- [ ] N+1 is unavoidable — explicit justification and request-count budget declared:
  - **Request budget per invocation:**
  - **Max requests per 1,000 input rows:**
  - **Bulk fetch strategy:** IN-clause-batch | bulk-endpoint | pagination-cursor | none
  - **Justification:**

## Reconciliation Closeout

<!-- Required for Architecture Change / bounded architecture-affecting Phase. -->

- [ ] N/A — Patch/small Feature with no architecture change
- [ ] Implementation matches approved scope/target state
- [ ] Deployment/runtime evidence is sufficient for the change
- [ ] Canonical architecture reflects resulting current state
- [ ] Current State reflects resulting operational state
- [ ] Decision lifecycle reflects accepted/superseded/retired decisions
- [ ] Database/workload/deployment inventories reconciled where affected
- [ ] Remaining drift is explicitly tracked rather than hidden

## Risks for Human Review

<!-- What should the reviewer pay particular attention to? -->

## Suggested Review Focus

<!-- Architecture boundary, user workflow, data ownership, rollout, etc. -->
