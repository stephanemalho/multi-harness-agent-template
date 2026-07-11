---
topic: multi-agent-workflow
last_reviewed: 2026-07-11
source_policy: official-docs-first
staleness_limit_days: 30
---

# Multi-Agent Workflow

## Goal

Allow each harness to coordinate multiple native agents on its task branch without stale branches, overlapping writes, unnecessary worktrees, or duplicated rule ownership.

## Branches

Use:

```txt
agent/<harness>/<ticket-or-task>/<short-slug>
```

Do not use long-running generic branches such as only `codex`, `claude`, or `gemini` for real tasks. They drift too easily.

Seed branches may exist only as examples:

```txt
agent/codex/template
agent/claude/template
agent/gemini/template
```

The harness segment owns the branch. It does not limit the branch to one agent session.

## Native Agent Coordination

The harness coordinator may run multiple agents or subagents using that harness's native capabilities. Codex, Claude Code, and Gemini CLI do not need to expose identical delegation, isolation, nesting, or tool behavior.

Parallel writing is allowed only when the coordinator:

- assigns explicit, non-overlapping files to each writer
- keeps one writer responsible for shared contracts and shared files
- integrates and validates the combined result on the harness branch

Read-heavy exploration, review, and validation can be delegated without granting write ownership.

## Worktrees

Agent or subagent delegation stays in the current project checkout by default. A request for parallel work never implies creating a branch, clone, or worktree.

Additional worktrees are exceptional and require explicit maintainer approval. When approved, the maintainer may use `scripts/create-agent-worktree.sh <harness> <ticket-or-task> <short-slug> <explicit-path>`. The helper must not be treated as the default agent startup path.

## Sync Contract

Agents must run preflight:

```bash
scripts/agent-preflight.sh
```

If behind main:

```bash
scripts/agent-sync-main.sh
```

## Human Gate

Only the human maintainer merges into `main`.

CI verifies:

- branch naming
- branch is not behind `origin/main`
- required files exist
- no local settings or obvious secrets are committed
- project-specific checks if configured
