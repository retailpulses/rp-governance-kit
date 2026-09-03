# Architecture Change, Phase, and Reconciliation Governance

Status: Canonical central policy

## Purpose

Retailpulses repositories evolve incrementally, often with agent-assisted changes. Issue/PR compliance alone does not guarantee that the repository's overall architecture remains coherent. This policy prevents individually reasonable changes from accumulating into undocumented architecture drift.

The motivating pilot was OrderMgmt Phase 0 reconciliation (#260 / PR #261), where Supabase, VPS Portal/API, multi-platform workloads and deployment boundaries had evolved while detailed top-level documents still described older Worker/Baserow-centric architecture.

## 1. Canonical architecture requirement

Active business/application repositories must maintain `docs/01_ARCHITECTURE.md` as the canonical current architecture SSOT.

It should answer, at minimum:

- What is the system for?
- What is inside/outside its boundary?
- Which repository/domain owns canonical data?
- What are the major runtime components?
- What are the major data/integration flows?
- Which dependencies are canonical versus legacy/compatibility?
- Which architecture invariants must future changes preserve?

`00_CURRENT_STATE.md` remains a concise operational snapshot. README, CLAUDE/AGENTS files, plans, audits, TRDs and historical reports must not become competing current architecture specifications.

## 2. Change classification

Classify mergeable work by architectural effect, not line count.

### Patch

A bounded correction that does not change system boundary, canonical ownership, public/internal interface contract, data model semantics, runtime topology, major workflow/invariant, or production workload architecture.

Examples: bug fix within an existing contract, copy/UI correction, safe configuration adjustment.

Patch workflow stays lightweight: Issue -> implementation -> PR -> normal closeout.

### Feature

Adds or materially changes user/system behavior while generally remaining inside established architecture boundaries.

A Feature should use a bounded Phase when it spans multiple PRs, changes a major workflow, requires staged rollout/cutover, or would otherwise become an open-ended sequence of incremental changes.

### Architecture Change

Any change that materially alters one or more of:

- system/service boundary;
- canonical data ownership or source of truth;
- API/interface contract between components/repos;
- data model semantics that affect system design;
- runtime/deployment topology;
- marketplace/platform dependency role;
- production workload ownership/scheduling model;
- security/trust boundary;
- major business workflow or invariant;
- replacement/retirement of a canonical component.

Architecture Changes require an explicit bounded Phase and a recorded architecture decision (ADR or decision log entry appropriate to the repository).

When uncertain between Feature and Architecture Change, classify based on whether future developers/agents need a changed architecture model to implement correctly. If yes, it is Architecture Change.

## 3. Bounded Phase

A Phase is a change boundary, not a release train or bureaucracy layer.

Use `docs/phases/<phase-id>/README.md` or an equivalent governed Issue when repository scale does not justify a file. The Phase must state:

- Problem / user or operational value
- Current architecture relevant to the change
- Target architecture/behavior
- Scope
- Non-goals
- Affected components/domains/interfaces
- Migration/cutover/rollback where applicable
- Verification/evidence required
- Canonical documents expected to change
- Completion/reconciliation criteria

A Phase may contain multiple Issues/PRs. Individual PRs can merge before the Phase closes, but the Phase remains open until reconciliation is complete.

## 4. Before implementation: architecture impact gate

For Feature/Architecture work, establish before coding:

1. Which canonical architecture sections apply.
2. Which components, interfaces, domains, workflows and workloads are affected.
3. Whether a new architecture decision is being made.
4. Which current-state/architecture/data/workload documents will require reconciliation.
5. What evidence will demonstrate completion.

Do not implement against a remembered or historical architecture when a canonical file exists.

If actual code/runtime contradicts the canonical architecture, report architecture drift and include reconciliation in the bounded work. Do not silently choose whichever source is convenient.

## 5. Evidence states

Use these terms when ambiguity matters:

- **Implemented** — exists in current code/schema/deployment definitions.
- **Declared** — recorded in governed inventory/configuration.
- **Deployed** — release/deployment evidence confirms delivery to an environment.
- **Runtime verified** — the live environment was directly checked.

Never infer `runtime verified` from repository declarations alone.

## 6. Reconciliation Definition of Done

An architecture-affecting Phase is not complete merely because all code PRs merged.

Before Phase close:

1. Verify implementation against approved scope/target architecture.
2. Verify deployment/runtime state to the level required by the change.
3. Reconcile `docs/01_ARCHITECTURE.md` with the resulting current architecture.
4. Update `docs/00_CURRENT_STATE.md` when operational state changed.
5. Update ADR/decision records for material decisions and mark superseded decisions where applicable.
6. Update database/workload/deployment inventories when governed facts changed.
7. Mark legacy/replaced architecture explicitly; do not leave detailed stale documents competing as current truth.
8. Record unresolved drift as follow-up with owner/scope rather than hiding it.

Only then may the Phase be closed.

## 7. Documentation roles

| Artifact | Role |
|---|---|
| `00_CURRENT_STATE.md` | concise operational snapshot |
| `01_ARCHITECTURE.md` | canonical current architecture SSOT |
| README | product/repository entry point; links to canonical docs |
| CLAUDE.md / AGENTS.md | agent instructions/read order; must consume, not duplicate architecture |
| ADR / decision log | why material decisions were made; lifecycle/history |
| Phase | bounded change from current to target state |
| design/TRD/plan | proposed/detailed change design; not automatically current state |
| audit | evidence/findings at a point in time |
| workload/data inventories | canonical narrow-domain declarations under their own governance |

## 8. ADR lifecycle

Architecture decisions should expose lifecycle where practical:

- Proposed
- Accepted
- Superseded
- Retired

A superseding decision should identify what it replaces. Current architecture belongs in `01_ARCHITECTURE.md`; ADRs explain why, not duplicate the entire current state.

## 9. Agent behavior

Agent guidance should require this reading order for architecture-affecting work:

1. Current State
2. Canonical Architecture
3. Governing Issue/Phase
4. Relevant decisions/designs
5. Applicable database/workload/deployment governance
6. Runtime evidence when activation matters

Agents must not declare completion while known architecture drift remains inside the approved Phase scope.

## 10. Governance proportionality

This policy must not turn ordinary maintenance into ceremony.

- Patch: no Phase required.
- Small Feature inside stable boundaries: Issue/PR may be sufficient.
- Multi-PR/staged Feature: Phase recommended/required when bounded coordination is needed.
- Architecture Change: Phase + decision + reconciliation required.

Escalate based on architectural consequence, not code size.