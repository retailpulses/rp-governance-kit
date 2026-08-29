# Ops Portal Release Governance

Version: 1.0  
Effective: 2026-08-29

## Policy

`ops.homesbliss.net` is the canonical operator acceptance surface for Inquiry,
Tickets, and Orders. A successful origin deployment is not a successful
operator release until the exact canonical Portal route passes the reusable
`portal-acceptance.yml` workflow.

## Required release sequence

1. Run repository-owned build, unit, integration, and migration gates.
2. Deploy one immutable application artifact to its owned runtime.
3. Run `portal-acceptance.yml` against the exact canonical Portal path.
4. Mark the release successful only when Portal acceptance passes.
5. On failure, keep or restore the last known-good application release and do
   not describe the change as released to operators.

## Compatibility contract

- Inquiry: `https://ops.homesbliss.net/inquiry/`
- Tickets: `https://ops.homesbliss.net/tickets/`
- Orders: `https://ops.homesbliss.net/order/`
- Application APIs and capability discovery must use an owned namespace.
  Generic absolute endpoints such as `/api/health` are not allowed for
  Portal-dependent feature discovery.
- Root-relative assets must be correctly rewritten beneath the application's
  canonical prefix.
- The shared Ops navigation must be present on the canonical route.
- Feature flags required for operator controls must be asserted through the
  canonical Portal host. Ticket Share is checked through
  `/api/ticketing/health`.

## Definition of done

A Portal-facing release is done only when repository validation, deployment,
canonical-route acceptance, feature-capability assertions, and rollback
instructions are all recorded against the same commit SHA.

An HTTP redirect to Cloudflare Access proves protection and routing only. The
acceptance workflow uses a dedicated Cloudflare Access service token and
requires the application response and its contracts to pass.

## Ownership

- Application repositories own their application behavior and namespaced APIs.
- `ops-portal` owns proxy routing, shared navigation, and host integration.
- `rp-governance-kit` owns the release acceptance policy and reusable workflow.

## Rollout order

1. Publish this governance workflow.
2. Configure `CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET` as protected
   organization or repository Actions secrets for each caller.
3. Merge caller workflow changes in Inquiry, Tickets, and Orders.
4. Confirm one successful acceptance run per application before relying on the
   gate for normal releases.

## Change log

- 2026-08-29 — v1.0: Established canonical Portal acceptance and the Ticket
  Share capability assertion.
