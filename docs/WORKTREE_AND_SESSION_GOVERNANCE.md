# Worktree and Session Governance

**Status:** Canonical policy
**Owner:** `retailpulses/rp-governance-kit`
**Governance version:** v1.7.0
**Issue:** retailpulses/inbox#65

## Purpose

Multiple agent sessions and engineers can operate on the same Retailpulses repository at the same time. Without a shared convention for worktree isolation, two sessions can write to the same branch or the same working tree, corrupt each other's state, and produce commits that are impossible to attribute.

This policy defines the invariant that keeps concurrent work safe: **one writable session per Issue / branch / worktree**.

## Scope

- Applies to all Retailpulses repositories that adopt the governance kit.
- Applies to any session that performs mergeable engineering work: Claude Code sessions, Codex sessions, OpenCode sessions, and human engineers working in a terminal.
- Applies to git worktrees created for a single unit of work (one Issue).

## Definitions

| Term | Meaning |
|------|---------|
| **Session** | A single agent conversation or terminal process doing engineering work. One session = one writable unit of work. |
| **Issue** | The GitHub Issue that authorizes the work (Issue-first development). |
| **Branch** | The named git branch the session works on. |
| **Worktree** | A git working tree (the main checkout or a linked `git worktree`) where the session reads and writes files. |
| **Session ownership record** | A small key/value file stored in the worktree's git metadata that records which session, Issue, and branch own the worktree. |
| **Start gate** | The `rp-worktree-hygiene --strict` check run before work begins. |
| **Closeout gate** | The `rp-worktree-hygiene --strict` check run before opening a PR / finishing work. |

## Core Invariant

**One writable session per Issue / branch / worktree.**

Concretely:

1. Each unit of work (Issue) is owned by exactly one session at a time.
2. Each session works on exactly one branch.
3. Each branch is checked out in at most one worktree.
4. Each worktree has at most one session writing to it.
5. While two or more active worktrees exist, the primary checkout is coordination-only; writable sessions must use dedicated linked worktrees.

The same Issue may be worked by a later session only after the previous session has closed out and its worktree ownership has been released.

## Central vs Local Responsibility

This policy follows the central-vs-local boundary established in [ADR-002](adr/002-central-vs-local-governance.md).

### Central (`rp-governance-kit`)

- The invariants in this document (one writable session per Issue / branch / worktree).
- The session ownership record schema (section below).
- The `rp-worktree-hygiene` checker and its start/closeout semantics.
- The installable local reference (`docs/18_WORKTREE_AND_SESSION_GOVERNANCE.md` in each repo).

### Local (each business repository)

- The repository's own stricter session/worktree rules, if any, declared in `governance/local.yaml`.
- The choice of base ref used for the merge check (usually the default branch).
- The concrete workflow the team uses to start and close out a session.

Local declarations may be **stricter** than central invariants. They must never weaken them. If a local declaration contradicts central invariants, agents must stop and report the conflict.

## Session Start

Before beginning work on an Issue, a session MUST:

1. Confirm the Issue exists and is compliant (see `docs/ISSUE_GOVERNANCE.md`).
2. Confirm no other session owns the Issue / branch.
3. Create or enter a worktree dedicated to this Issue. The primary checkout may be writable only while it is the repository's sole active worktree; once concurrent work exists, it is coordination-only.
4. Record the session ownership (see "Session ownership record" below).
5. Run the start gate:

```bash
bin/rp-worktree-hygiene --strict --base-ref main
```

A start gate that reports a violation means the session MUST NOT begin. Resolve the violation (switch to a fresh branch/worktree based on the current canonical base, clean the tree, or set an upstream) and re-run. A branch already merged into the canonical base is closed work and must not be reused.

## Session Closeout

Before opening a PR or otherwise finishing work, a session MUST:

1. Commit all intended work.
2. Run the closeout gate:

```bash
bin/rp-worktree-hygiene --strict --base-ref main
```

3. Confirm the branch is merged (or explicitly reviewed as intentionally unmerged).
4. Release the session ownership record for the worktree.

Cleanup of a worktree after closeout is **ownership-gated**: see "Ownership-gated cleanup".

## Ownership-Gated Cleanup

A worktree may only be removed by:

1. The session that owns it (as recorded in the session ownership record), or
2. A human operator who has first read the ownership record and confirmed the owning session is finished.

Before removing a worktree, verify:

- The branch is merged or explicitly abandoned.
- No session is still writing to the worktree.
- The ownership record identifies the same Issue/branch being cleaned up.

The `rp-worktree-hygiene` checker is **read-only**. It never removes worktrees, prunes metadata, checks out, resets, or deletes branches. Cleanup is a separate, human- or owner-driven step.

## Session Ownership Record (design)

Because worktrees live outside the repository's tracked files, the ownership record must be **scoped to the worktree** and stored where git keeps per-worktree metadata — never in a tracked file.

### Location

The record lives in the worktree's git directory:

```
$(git rev-parse --git-dir)/rp-session-owner
```

For the main worktree this is `<repo>/.git/rp-session-owner`. For a linked worktree it is `<repo>/.git/worktrees/<name>/rp-session-owner`. Each worktree therefore has its own record; none of them are committed.

### Schema

A plain-text, line-oriented key/value file. Keys and values are separated by `=`. Comments start with `#`.

```text
issue=65
branch=feat/issue-65-worktree-isolation
session=claude-code-12345
started_at=2026-08-31T09:00:00Z
base_ref=main
```

| Key | Required | Meaning |
|-----|----------|---------|
| `issue` | yes | The GitHub Issue number this worktree is working on. |
| `branch` | yes | The branch checked out in this worktree. |
| `session` | yes | An identifier for the owning session (agent name + a process/host hint). Never a credential. |
| `started_at` | yes | ISO-8601 UTC timestamp when the session started. |
| `base_ref` | no | The base ref used for merge checks (default: repository default branch). |

### Rules

- The record is advisory metadata, not a lock file. It does not by itself prevent concurrent writes; the `--strict` gate and the multi-worktree check are what surface conflicts.
- A session creates the record at start and removes it at closeout (or marks it `released=yes`).
- The record never contains secrets, tokens, or credentials. It is never committed; add `rp-session-owner` under `.git/` (already untracked) and, for safety, ensure `.gitignore` covers any stray copy.

### Enforcement status (v1)

In v1 the record is **informational**. The `rp-worktree-hygiene` checker reports whether a record exists but redacts its values; it does not block on a missing or stale record. The strict start/closeout gate blocks on structural violations (detached HEAD, dirty tree, missing upstream, branch checked out in multiple worktrees), not on the presence of the record.

## The Checker: `rp-worktree-hygiene`

`bin/rp-worktree-hygiene` is a read-only, macOS-bash-compatible script that reports worktree/session hygiene. See `templates/bin/rp-worktree-hygiene` for the implementation.

| Mode | Behavior |
|------|----------|
| Default (informational) | Prints a full report. Exits 0 for repository findings; invalid usage or a non-Git path exits 2. |
| `--strict` | Exits 1 when any structural violation is found; 0 otherwise. |

Reported conditions (each is handled explicitly):

| Condition | Informational | Strict gate |
|-----------|---------------|-------------|
| Detached HEAD (no branch) | reported | **violation** |
| Dirty working tree (tracked or untracked changes) | reported | **violation** |
| Missing upstream | reported | **violation** |
| Branch checked out in more than one worktree | reported | **violation** |
| Primary checkout used while 2+ non-prunable worktrees exist | reported | **violation** — use a dedicated linked worktree |
| Prunable worktree metadata present | reported | warning (non-blocking) |
| Canonical base cannot be resolved | reported | **violation** |
| Branch merged into base ref (with ahead/behind counts) | reported | **violation** — create a fresh branch |

### CI limitation (explicit)

`rp-worktree-hygiene` inspects the **local** git repository: branch state, working tree, upstream, worktrees, and session record. None of this state exists on a GitHub Actions runner in a meaningful way (CI checks out a single detached commit with no worktrees and no session ownership).

Therefore:

- The start/closeout gate is a **local, agent-side** check. It runs in the agent's terminal or worktree, not as a GitHub Action.
- `rp-worktree-hygiene` is **not** installed as a blocking CI check in v1.
- CI remains limited to the existing blocking checks (issue-link, docs-impact) plus advisory governance warnings. Worktree/session isolation cannot be enforced in CI and is out of scope for CI enforcement.

## Exceptions

- A short-lived throwaway worktree used purely for exploration (no commits) does not require a session ownership record, but must still not collide with another session's branch.
- A human operator may explicitly authorize a second session on the same Issue after the first session has closed out.

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| v1.7.0 | 2026-09-01 | Make the primary checkout coordination-only during concurrent work and enforce the rule in the strict local gate. |
| v1.0.0 | 2026-08-31 | Initial worktree/session governance — one writable session per Issue/branch/worktree, read-only checker, session ownership record design, v1 strict start/closeout gate, explicit CI limitation. |
