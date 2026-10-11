# Engineering Principles

Retailpulses engineering follows these principles to preserve system context while moving fast with agents.

## Issue-First Development

All mergeable engineering work must start from a compliant GitHub Issue. Exploration and local investigation can happen before an Issue, but mergeable coding cannot start without a compliant Issue.

MVP is allowed, but system context must be preserved. Every change should explain what it does, why it matters, and what impact it has.

## Change Proportionality

Classify work by architectural consequence rather than code size:

- **Patch** — bounded correction inside existing architecture; keep the process lightweight.
- **Feature** — material behavior change; use a bounded Phase when multi-PR, staged, or workflow-level coordination is required.
- **Architecture Change** — changes boundaries, ownership, interfaces, data-model semantics, runtime topology, workload architecture, trust boundaries, or major invariants; requires a bounded Phase, decision record, and reconciliation.

Canonical policy: `retailpulses/rp-governance-kit` → `docs/ARCHITECTURE_CHANGE_GOVERNANCE.md`.

## Canonical Architecture

Active business/application repositories maintain `docs/01_ARCHITECTURE.md` as current architecture SSOT. README and agent instruction files should link to and consume it rather than duplicate a second detailed architecture description.

Architecture-affecting work must begin from the current architecture and reconcile it after implementation/deployment before the Phase closes.

## Subscription-Independent Repository Governance

Retailpulses baseline repository governance must remain effective on **GitHub Free for Organizations**. Required safety, auditability, and production controls must not depend on GitHub Team, Enterprise, or another paid subscription tier.

Paid GitHub capabilities such as organization rulesets, private-repository rulesets or branch protection, merge queues, or similar server-side controls may be used as **defense in depth while available**, but they must not be the sole enforcement mechanism for a critical invariant.

In particular:

- Production safety must be enforced at durable boundaries such as CI validation, deployment workflows, production credentials, runtime permissions, and explicit release procedures.
- A direct push to a source branch must not, by itself, grant the ability to deploy or mutate production.
- Repository workflow should be proportional to risk. Lab, prototype, migration, and operator-tool repositories without production authority may use direct pushes and optional PRs when that materially improves iteration speed.
- Production repositories may use stricter review and merge conventions, but the minimum safe operating model must continue to work if paid GitHub governance features disappear.
- When adopting a paid-plan GitHub control, document the portable fallback or equivalent control before treating it as required governance.

The target is **portable governance first, subscription features second**.

## PR Requirements

Every PR must explain:

- **User impact** — who is affected and how
- **Data impact** — does the data model change
- **Architecture impact** — does the system structure change
- **Documentation/reconciliation impact** — what canonical docs must be updated

## Business Logic Separation

Core business logic should be reusable and not marketplace-specific. Marketplace-specific behavior belongs in adapters.

## Auditability

Agent-created changes must be auditable. Humans review:

- System impact
- Business logic
- Data naming
- Workflow assumptions
- Architecture drift and reconciliation for bounded changes

Do not call repository declarations `runtime verified` without direct live-environment evidence.

## Avoid Duplication

Avoid duplicated functionality and duplicate canonical entities. Prefer shared services, shared workflows, and shared data models over isolated agents.

Avoid duplicate architecture truth as well: current architecture belongs in `docs/01_ARCHITECTURE.md`; decisions explain why; plans describe proposed change.

## Automation Boundaries

AI should automate routine operational work, while humans supervise exceptions and strategic decisions.
