---
name: query-insights
description: Query Cloud SQL Query Insights from GCP Monitoring API. Shows top queries by execution time, IO time, lock time, etc. for production database analysis and debugging.
---

# Cloud SQL Query Insights

Pull query performance data from Google Cloud SQL Query Insights for the production database.

## Usage

```
/query-insights [natural language request]
```

## Instructions

When the user invokes `/query-insights`, translate their request into the appropriate flags and run:

```bash
bash ~/.claude/skills/query-insights/query-insights.sh [options]
```

### Available Options

| Flag | Description | Default |
|------|-------------|---------|
| `--project <id>` | GCP project ID | `cortex-production-268606` |
| `--instance <name>` | Cloud SQL instance name | `lord-voldemort-upgrade-turkey-edition` |
| `--window <minutes>` | Time window to query | `60` |
| `--metric <type>` | Metric type (see below) | `execution_time` |
| `--top <n>` | Number of results | `15` |
| `--mode <mode>` | `perquery`, `aggregate`, or `pertag` | `perquery` |
| `--raw` | Output raw JSON for further analysis | - |

### Metrics

- `execution_time` — Total CPU + IO + lock + scheduling time (default, best for "slowest queries")
- `io_time` — IO wait time only (best for "disk-bound queries")
- `lock_time` — Lock wait time only (best for "contention issues")
- `row_count` — Rows affected (best for "biggest queries by data volume")
- `latencies` — Latency distribution
- `shared_blk_access_count` — Shared buffer access (best for "cache pressure")

### Known Instances

| Instance | Project | Description |
|----------|---------|-------------|
| `lord-voldemort-upgrade-turkey-edition` | `cortex-production-268606` | Main production DB |
| `brain-db-eu` | `cortex-production-268606` | EU production DB |
| `brain-restore-pre-prod-clone-hdd` | `cortex-production-268606` | Pre-prod clone |
| `brain-backend-15` | `cortex-staging-354021` | Staging DB |

### Interpreting Results

- Values are cumulative over the time window (not per-execution)
- For `execution_time`: output is in seconds, represents total CPU+IO+lock time across all executions
- Query strings are parameterized (`$1`, `$2`, etc.) — this is normal, Cloud SQL normalizes them
- Use `--raw` to get full JSON when you need query hashes or exact label values

## Examples

```bash
# Top queries by execution time (last hour, default)
bash ~/.claude/skills/query-insights/query-insights.sh

# Top queries by IO time over last 4 hours
bash ~/.claude/skills/query-insights/query-insights.sh --metric io_time --window 240

# Lock contention in the last 30 minutes
bash ~/.claude/skills/query-insights/query-insights.sh --metric lock_time --window 30

# Aggregate stats per user/database
bash ~/.claude/skills/query-insights/query-insights.sh --mode aggregate

# Top 5 queries on staging
bash ~/.claude/skills/query-insights/query-insights.sh --project cortex-staging-354021 --instance brain-backend-15 --top 5

# Raw JSON for a specific query investigation
bash ~/.claude/skills/query-insights/query-insights.sh --raw --top 3
```

## Troubleshooting

- **Auth errors**: Run `gcloud auth login` to refresh credentials
- **Empty results**: Try a larger `--window` or check that the instance name is correct
- **"Cannot iterate over null"**: The API returned no time series — the instance may not have Query Insights enabled
