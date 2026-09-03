# Canonical Architecture

Status: **Canonical current architecture**  
Last reconciled: YYYY-MM-DD

This document is the repository's architecture source of truth. If implementation or runtime evidence contradicts it, treat the mismatch as architecture drift and reconcile explicitly.

## 1. System purpose

<!-- What user/business/operational problem does this system own? -->

## 2. System boundary and ownership

<!-- What is inside/outside this system? Which domains/data does it own or consume? -->

## 3. Runtime topology

```text
<!-- Major runtime components and connections only. Keep implementation detail elsewhere. -->
```

## 4. Major components

<!-- Component, responsibility, runtime/deployment location, important boundary. -->

## 5. Canonical data and integration flows

<!-- Major end-to-end flows. Do not reproduce every endpoint/table/job. -->

## 6. Data/domain ownership

<!-- Sources of truth, cross-domain contracts, prohibited duplicate canonical entities. -->

## 7. Architecture invariants

<!-- Rules future changes must preserve unless an Architecture Change explicitly replaces them. -->

## 8. Legacy and compatibility boundaries

<!-- What still exists but must not be mistaken for canonical architecture? -->

## 9. Evidence status

Use these terms where relevant:

- **Implemented** — present in code/schema/deployment definitions.
- **Declared** — recorded in governed inventory/configuration.
- **Deployed** — deployment evidence confirms delivery to an environment.
- **Runtime verified** — live environment directly checked.

## 10. Canonical reading order

1. `docs/00_CURRENT_STATE.md`
2. `docs/01_ARCHITECTURE.md` (this file)
3. Governing Issue/Phase
4. Relevant ADR/decision/design documents
5. Applicable database/workload/deployment governance
6. Runtime evidence when activation matters
