# Global Claude Code Instructions

## Git Discipline

- Always verify current branch, uncommitted changes, and relationship to remote before committing or pushing. Never assume — check first.
- Start from a clean branch off main. Don't accumulate changes on stale branches.
- When asked to rebase onto main, assume you will also need to force-push.

## Package Managers & Runtimes

- Use `brew` for installing system packages, not `pip3`
- Use `bun` as runtime where applicable, not `node`

## Scripting

- Prefer TypeScript for scripts. Bash/zsh scripts are also fine.
- Avoid Python scripting.

## Errors

- Fix errors immediately. Never dismiss them as "pre-existing" or "not ours."

## Working Style

- Don't fumble around. If the first approach isn't working, step back and rethink rather than trying variations blindly.
- Follow existing patterns in the codebase. Before introducing a new approach, check if there's already a convention.
- Defense in depth — when restricting behavior, use both instruction-level constraints AND runtime safeguards.
- Distinguish states precisely (e.g., "skipped" vs "failed" are not the same thing).

## Communication

- Be concise. Short responses preferred — no essays.
- Comfortable delegating work and checking back asynchronously.

## Code Hygiene

- Run lint before committing, not after every change.
- Never search inside `node_modules/.pnpm`.

## Known Repositories

All agent work happens inside `~/src/agents/`. Each repo follows the pattern `~/src/agents/<repo>/primary` (the main clone) with numbered worktrees alongside it (e.g., `~/src/agents/brain-backend/bb1`). The human clones in `~/src/` are read-only references — do not modify them.

| Repository | Agent Path | Human Clone |
|---|---|---|
| brain-backend | `~/src/agents/brain-backend/` | `~/src/brain-backend` |
| brain-app | `~/src/agents/brain-app/` | `~/src/brain-app` |
| brain-gitops | `~/src/agents/brain-gitops/` | `~/src/brain-gitops` |
| helm-chart | `~/src/agents/helm-chart/` | `~/src/helm-chart` |
| infrastructure | `~/src/agents/infrastructure/` | `~/src/Infrastructure` |
| actions | `~/src/agents/actions/` | — |
| tenant-inspector | `~/src/agents/tenant-inspector/` | — |
| authn-proxy | `~/src/agents/authn-proxy/` | — |

Check which directory you are currently in — if you are not in `primary`, you are in a **git worktree**. Keep this in mind when referencing branches or pushing.

## Common Reviewers

When asked to add a reviewer by first name, use the GitHub handle from this table:

| Name | GitHub Handle |
|---|---|
| Aditya | `maddymanu` |
| Andrew Frieze | `AFrieze` |
| Anthony | `tonytino` |
| Arek | `aszarama` |
| Ashir | `ashiramin` |
| Dan Schuman | `quicksnap` |
| Doug | `dougcpr` |
| Hanna | `hannavigil` |
| Jason | `browniefed` |
| Keith | `keithfz` |
| Kienan | `kienan` |
| Mikolaj | `mmaikel` |
| Nikhil | `nikhilunni` |
| Shawn | `shawnburke` |
| Van | `worksbyvan` |

<!-- org:tools -->
## Available CLIs

Standard tools (`gh`, `docker`, `jq`, `yq`, `kubectl`, `helm`, `terraform`, `buf`) are on the path. Notable domain-specific CLIs:

| CLI | Service | Notes |
|---|---|---|
| `acli` | Atlassian (Jira/Confluence) | Installed via brew |
| `gcloud` | Google Cloud | For GKE, Cloud SQL, etc. |
| `cortex` | Cortex API | The company's own CLI |
| `ldcli` | LaunchDarkly | Feature flag management |
| `pup` | Datadog | 200+ commands across 33 products (logs, metrics, monitors, etc.) |
| `yq` | YAML | Validate YAML with `yq '.' file.yml > /dev/null` |
| `act` | GitHub Actions | Run workflows locally; use `-P ubuntu-latest=catthehacker/ubuntu:act-latest` |
<!-- /org:tools -->
