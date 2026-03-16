---
name: weekly-wrap
description: Generate a weekly progress report by gathering GitHub PRs/reviews, Jira updates, Linear issues, Granola meeting notes, Notion docs/comments, Slack messages, Claude session history, and calendar events, then synthesizing into a structured markdown summary.
---

# Weekly Wrap

Generate a comprehensive weekly progress report.

## Usage

```
/weekly-wrap              # Current week (Mon–today)
/weekly-wrap Mar 7        # Week of March 7 (Mon–Fri)
/weekly-wrap 2026-02-24   # Week of Feb 24
```

## Step 1: Date Handling

Parse `$ARGUMENTS` to determine the target week:

- **No argument**: Current week. Start = most recent Monday, End = today.
- **Date argument** (e.g., `Mar 7`, `2026-03-07`, `March 7`): Find the Monday of the week containing that date. Start = that Monday, End = the following Sunday (or today if it's the current week).

Compute these values before launching agents:
- `START_DATE` — YYYY-MM-DD (Monday)
- `END_DATE` — YYYY-MM-DD (Friday or today)
- `END_DATE_PLUS_1` — YYYY-MM-DD (day after END_DATE, for exclusive `--before`)
- `BUCKET` — absolute path to `config.output_dir/data-START_DATE` (expand `~` to `$HOME`)
- `SKILL_DIR` — absolute path to `~/.claude/skills/weekly-wrap` (expand `~` to `$HOME`)

## Step 2: Read Config

Read `~/.claude/skills/weekly-wrap/config.json` and extract:
- **GitHub username**: `config.github.username`
- **GitHub orgs**: `config.github.orgs[]`
- **Jira projects**: `config.jira.projects[]`

## Step 3: Launch Data-Gathering Agents

Launch **all 9 gathering agents simultaneously** in a single message. Each agent is defined in its own file under `~/.claude/skills/weekly-wrap/agents/`.

For each agent file:
1. Read the file to get its instructions
2. Use the `model` from its YAML frontmatter
3. Substitute all `{{PLACEHOLDER}}` values with computed/config values
4. Spawn via the Agent tool with the substituted content as the prompt

### Placeholder Substitutions

| Placeholder | Value |
|---|---|
| `{{GITHUB_USERNAME}}` | `config.github.username` |
| `{{GITHUB_ORG}}` | Run commands once per org in `config.github.orgs[]` |
| `{{JIRA_PROJECT}}` | Run commands once per project in `config.jira.projects[]` |
| `{{START_DATE}}` | Computed start date |
| `{{END_DATE}}` | Computed end date |
| `{{END_DATE_PLUS_1}}` | Day after end date |
| `{{BUCKET}}` | Absolute bucket path |
| `{{SKILL_DIR}}` | Absolute skill directory path |

### Agents

| # | File | Bucket File |
|---|------|-------------|
| 1 | `agents/github-prs.md` | `{{BUCKET}}/01-github-prs.md` |
| 2 | `agents/github-reviews.md` | `{{BUCKET}}/02-github-reviews.md` |
| 3 | `agents/jira.md` | `{{BUCKET}}/03-jira.md` |
| 4 | `agents/session-history.md` | `{{BUCKET}}/04-session-history.md` |
| 5 | `agents/calendar.md` | `{{BUCKET}}/05-calendar.md` |
| 6 | `agents/granola.md` | `{{BUCKET}}/06-granola.md` |
| 7 | `agents/linear.md` | `{{BUCKET}}/07-linear.md` |
| 8 | `agents/notion.md` | `{{BUCKET}}/08-notion.md` |
| 9 | `agents/slack.md` | `{{BUCKET}}/09-slack.md` |

## Step 4: Synthesize

After ALL gathering agents return, launch the synthesizer defined in `agents/synthesizer.md`. Use its `model` (opus). Substitute `{{BUCKET}}` in its instructions. It reads all bucket files and writes the draft to `{{BUCKET}}/draft.md`.

## Step 5: Output

Read `BUCKET/draft.md` and write it to `~/weekly-wraps/wrap-START_DATE.md` using the Write tool. Display the report in the conversation. Open it: `zed ~/weekly-wraps/wrap-START_DATE.md`

## Important Notes

- All 9 gathering agents MUST launch in a single message (parallel)
- Use absolute paths (no `~`) in agent prompts — expand `~` to `$HOME`
- Synthesizer runs AFTER all gathering agents return
- If any agent fails, note it in the report and continue
- Historical weeks may have less data — that's expected
