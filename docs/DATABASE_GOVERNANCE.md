# Database Governance

Canonical organization-level database governance policy for Retailpulses repositories.

This document is maintained in `retailpulses/rp-governance-kit`. Repository-local files may add stricter rules but may not weaken central rules. If repo-local governance files and this central policy conflict, agents must stop and report the conflict instead of guessing.

**Version:** v1.1.0
**Last updated:** 2026-07-15

---

## 1. Scope and Source of Truth

This document is the canonical organization-level database governance policy. It applies to every Retailpulses repository that:

- contains a `supabase/` directory with migrations;
- connects to a shared or dedicated Supabase project;
- generates or consumes Supabase database types; or
- queries a Retailpulses-hosted PostgreSQL database.

Repository-local `docs/16_DATABASE_GOVERNANCE.local.md` may add stricter rules specific to that repository's domain. They may not weaken or contradict central rules. Conflicts require the agent to stop and report them.

## 2. Database Domain Ownership

Every schema object (table, view, function, type, trigger, RLS policy, storage bucket) has exactly one owning repository/domain. Ownership is declared in `docs/DATABASE_OWNERSHIP.yaml` in `rp-governance-kit`.

- **Owner repositories** are authoritative for their domain's schema. They create and maintain canonical migrations.
- **Non-owner repositories** may read or reference shared objects through views, functions, or the Supabase client, but may not alter them without an explicit cross-domain declaration in `DATABASE_OWNERSHIP.yaml`.
- **Shared-table changes** require an impact analysis that names every known consumer repository. The `DATABASE_OWNERSHIP.yaml` `consumers` field is the authoritative consumer list.
- **New shared objects** must be proposed through an Issue that identifies the owning domain and known consumers before the first migration is written.

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
- **Repositories accessing Supabase only through an internal API** (e.g., a Cloudflare Worker that is the sole database client) may declare a generated-types exemption in `docs/16_DATABASE_GOVERNANCE.local.md`.

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

---

## References

- `docs/DATABASE_OWNERSHIP.yaml` — machine-readable domain ownership registry
- `docs/16_DATABASE_GOVERNANCE.md` (repo-local) — installed reference pointing to this canonical policy
- `docs/16_DATABASE_GOVERNANCE.local.md` (repo-local) — repository-specific declarations
- `docs/12_DATA_ACCESS_AND_SECRETS.md` (repo-local) — secrets handling and data access patterns
- `.github/workflows/database-governance-checks.yml` — reusable CI enforcement

## Governance

This document is part of `retailpulses/rp-governance-kit`. Changes must follow the governance repository's Issue-first workflow. The canonical GitHub URL is:

```
https://github.com/retailpulses/rp-governance-kit/blob/v1.1.0/docs/DATABASE_GOVERNANCE.md
```
