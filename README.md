# dotfiles

Personal configuration managed by [GNU Stow](https://www.gnu.org/software/stow/). Works on macOS and WSL.

## Setup

```bash
git clone https://github.com/akwirick/dotfiles.git ~/src/dotfiles
cd ~/src/dotfiles
bash install.sh
```

`install.sh` will install Stow if needed (`brew` on macOS, `apt` on Linux/WSL), back up any existing files that would conflict, and symlink everything into `~`.

## Packages

Each top-level directory is a Stow package. The directory structure inside mirrors `~/`.

### `claude/`

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration:

| File | Purpose |
|---|---|
| `settings.json` | Permissions, plugins, statusline, effort level |
| `CLAUDE.md` | Global instructions loaded into every session |
| `statusline.sh` | Two-line status bar (session name, model, context usage, git info) |
| `skills/lfg/` | Create a fresh branch from main for new work |
| `skills/query-insights/` | Query Cloud SQL Query Insights via GCP Monitoring API |
| `skills/roborev-address/` | Fetch and fix roborev code review findings |
| `skills/roborev-respond/` | Comment on and address roborev reviews |
| `skills/weekly-wrap/` | Generate weekly progress reports from GitHub, Jira, Linear, Slack, Calendar, Granola, Notion, and Claude session history |

## Adding a new package

Create a directory that mirrors the home directory structure, then re-run the installer:

```
mkdir -p git/.gitconfig
# ... add files ...
bash install.sh
```

Or stow individually:

```bash
stow -d ~/src/dotfiles -t ~ git
```

## Unstowing

Remove symlinks for a package without deleting the source files:

```bash
stow -d ~/src/dotfiles -t ~ -D claude
```
