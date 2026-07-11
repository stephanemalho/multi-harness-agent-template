# Git Workflow Rules

## Branches

`main` is the protected integration branch.

Agent branches must follow:

```txt
agent/<harness>/<ticket-or-task>/<short-slug>
```

Allowed harness names:

- `codex`
- `claude`
- `gemini`
- project-defined lowercase ids

Each task branch is owned by its harness, not by one individual agent. The harness coordinator may run multiple native agents or subagents on that branch. Parallel writers must have explicit, non-overlapping file ownership, and shared contracts or files must have one writer at a time.

A request for agents, subagents, or parallel work does not authorize a new branch, clone, or worktree. Additional worktrees require explicit approval from the human maintainer.

Harness-specific delegation and isolation behavior belongs in `docs/harness/`; do not impose one harness's agent model on another.

## Commit Messages

Proposed commit messages must use this complete format:

```txt
<type>(<optional-scope>): <concise summary>

- <path-or-file-group>: <what changed and why>
- <path-or-file-group>: <what changed and why>

Co-Authored-By: <agent name> <agent email>
```

- Use a Conventional Commits type such as `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, or `chore`.
- Write the summary in English, in the imperative mood, without a trailing period.
- Add a concise bullet for every materially changed file or coherent file group. Wrap long bullets onto indented continuation lines.
- Credit every agent that materially contributed to the change with a `Co-Authored-By` trailer. Use the agent identity exposed by the harness or approved by the maintainer; do not invent an identity.
- When asked only for a commit proposal, return the ready-to-paste message and do not run `git commit`.

Example:

```txt
feat: add init script to bootstrap the template into a new or existing repo

- scripts/init-agent-template.sh: copy template files safely, prompt for
  project identity, initialize Git, and run validation
- README.md: document the one-line quick start
- agent-template.yml: declare the init script and template repository URL

Co-Authored-By: Agent Name <agent@example.com>
```

## Main Synchronization

Agents must be up to date with `origin/main`:

- before implementation
- before opening a pull request
- before reporting completion

Use:

```bash
scripts/agent-preflight.sh
scripts/agent-sync-main.sh
scripts/agent-preflight.sh
```

## Merge Authority

Agents must not merge to `main`.

The human maintainer:

1. Reviews the PR branch against `main`.
2. Checks CI results.
3. Runs any local validation they want.
4. Merges or asks for changes.

## Conflict Policy

If syncing with `main` creates conflicts, stop and report:

- conflicted files
- likely cause
- proposed resolution

Do not invent a conflict resolution for domain logic without human review.
