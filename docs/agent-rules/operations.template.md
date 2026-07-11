# Operations Rules Template

Use this file for runtime, deployment, observability, and support rules.

## Environments

| Environment | Purpose | Owner |
|---|---|---|
| local | development | developer |
| staging | pre-production | `OWNER_REPLACE_ME` |
| production | live users | `OWNER_REPLACE_ME` |

## Deployment

- Deployment platform:
- Build command:
- Release process:
- Rollback process:

## Observability

- Logs:
- Metrics:
- Tracing:
- Error reporting:

## Local Ports

Parallel services in the current checkout must use coordinator-assigned ports that do not conflict. A maintainer-approved additional worktree must also receive its own ports and local-only runtime state.

| Service | Default | Agent override |
|---|---:|---:|
| app | `3000` | `3xxx` |
| api | `8000` | `8xxx` |
