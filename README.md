# rp-governance-kit

Centralized governance toolkit for Retailpulses repositories.

This repository is the central governance source for Retailpulses repositories. The organization `.github` repo may provide default GitHub templates, but governance logic, reusable workflows, agent commands, rollout scripts, and engineering standards are maintained here.

If local repo governance files and central governance conflict, agents must stop and report the conflict instead of guessing.

## What It Does

Standardizes Issue-first, architecture-aware development across Retailpulses repos:

- **Issue-first workflow** — every mergeable PR must link to a compliant GitHub Issue.
- **Architecture Change Governance** — canonical architecture SSOT, Patch/Feature/Architecture Change classification, bounded Phases, evidence states, and architecture reconciliation Definition of Done. See [`docs/ARCHITECTURE_CHANGE_GOVERNANCE.md`](docs/ARCHITECTURE_CHANGE_GOVERNANCE.md).
- **Issue governance** — normal development Issues use governed creation/templates rather than low-structure raw Issue creation.
- **Agent tooling** — `rp-issue-create`, `rp-issue-audit`, `rp-issue-work`, `rp-issue-closeout`, `rp-deploy-closeout`, `rp-repo-housekeeping`, and worktree hygiene tooling.
- **Engineering standards** — centralized templates for engineering principles, frontend, data access, platform dependencies, and Issue governance.
- **Post-deploy governance** — deploy closeout reports and repo housekeeping via GitHub-native summaries/comments/artifacts.
- **Docs impact and reconciliation** — current-state and architecture changes are reconciled rather than merely checked for any docs edit.
- **Reusable CI** — central governance checks, post-deploy closeout, and VPS immutable-release governance.
- **Portal release governance** — canonical route/capability acceptance for governed operator portals.
- **Database governance** — organization-level database policy, domain ownership, migration/access/RLS/runtime workload safety and incident response.
- **Sync Workload Governance** — central invariants for sync/batch workloads, per-repo inventories, and shared-DB workload risk controls.
- **Worktree and Session Governance** — writable-session isolation and hygiene checks.
- **Rollout tooling** — installer and upgrade scripts for lightweight repo adoption.

## Architecture Change Governance

The architecture layer exists because individually compliant Issues/PRs can still accumulate into repository-wide architecture drift.

Active business/application repos should maintain:

- `docs/00_CURRENT_STATE.md` — concise operational snapshot.
- `docs/01_ARCHITECTURE.md` — canonical current architecture SSOT.
- ADR/decision records — why material decisions were made.
- bounded Phase documents/Issues for multi-PR or architecture-changing work.

Small patches remain lightweight. Escalation is based on architecture consequence—boundary, ownership, interface, data semantics, runtime topology, workload architecture, trust boundary, or major invariant—not line count.

Architecture-affecting Phases close only after implementation/deployment evidence and canonical architecture are reconciled.

Templates:

- [`templates/docs/01_ARCHITECTURE.md`](templates/docs/01_ARCHITECTURE.md)
- [`templates/docs/PHASE.template.md`](templates/docs/PHASE.template.md)
- [`templates/github/pull_request_template.md`](templates/github/pull_request_template.md)

The first reconciliation pilot was OrderMgmt Phase 0 (#260 / PR #261).

## Issue Creation Rule

No raw low-structure Issue creation for normal development work. Use the governed repository tooling/template or an explicit approved exception. If an Issue is created outside governance format, correct it before coding begins.

See [`docs/ISSUE_GOVERNANCE.md`](docs/ISSUE_GOVERNANCE.md).

## Install

```bash
# Install into a single repo
bin/rp-governance-install retailpulses/RPagentOS

# Install a specific ref
bin/rp-governance-install retailpulses/ticket-handling --ref v1.1.0

# Batch install file
bin/rp-governance-install --repos repos.txt

# Dry run
bin/rp-governance-install retailpulses/RPagentOS --dry-run
```

The installer installs `docs/01_ARCHITECTURE.md` only when absent so upgrades do not overwrite repository-owned architecture truth.

## Database Governance

See [`docs/DATABASE_GOVERNANCE.md`](docs/DATABASE_GOVERNANCE.md) for canonical organization-level database governance policy.

## Sync Workload Governance

See [`docs/SYNC_WORKLOAD_GOVERNANCE.md`](docs/SYNC_WORKLOAD_GOVERNANCE.md).

## Worktree and Session Governance

See [`docs/WORKTREE_AND_SESSION_GOVERNANCE.md`](docs/WORKTREE_AND_SESSION_GOVERNANCE.md).

## Adoption principle

Central policy defines the invariant; repository-local declarations define repository-specific facts and may be stricter. Managed references can be upgraded centrally, while repository-owned current-state, architecture, decisions, and inventories must not be blindly overwritten.