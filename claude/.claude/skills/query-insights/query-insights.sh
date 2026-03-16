#!/usr/bin/env bash
set -euo pipefail

# Cloud SQL Query Insights via GCP Monitoring API
# Usage: query-insights.sh [options]
#   --project <id>       GCP project (default: cortex-production-268606)
#   --instance <name>    Cloud SQL instance (default: lord-voldemort-upgrade-turkey-edition)
#   --window <minutes>   Time window in minutes (default: 60)
#   --metric <type>      Metric: execution_time, io_time, lock_time, row_count, latencies, shared_blk_access_count (default: execution_time)
#   --top <n>            Number of top queries to show (default: 15)
#   --mode <mode>        aggregate | perquery | pertag (default: perquery)
#   --raw                Output raw JSON instead of formatted table

PROJECT="cortex-production-268606"
INSTANCE="lord-voldemort-upgrade-turkey-edition"
WINDOW=60
METRIC="execution_time"
TOP=15
MODE="perquery"
RAW=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT="$2"; shift 2 ;;
    --instance) INSTANCE="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --metric) METRIC="$2"; shift 2 ;;
    --top) TOP="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --raw) RAW=true; shift ;;
    -h|--help)
      echo "Usage: query-insights.sh [options]"
      echo "  --project <id>       GCP project (default: cortex-production-268606)"
      echo "  --instance <name>    Cloud SQL instance (default: lord-voldemort-upgrade-turkey-edition)"
      echo "  --window <minutes>   Time window in minutes (default: 60)"
      echo "  --metric <type>      execution_time|io_time|lock_time|row_count|latencies|shared_blk_access_count"
      echo "  --top <n>            Number of top queries (default: 15)"
      echo "  --mode <mode>        aggregate|perquery|pertag (default: perquery)"
      echo "  --raw                Output raw JSON"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TOKEN=$(gcloud auth print-access-token)
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# macOS vs GNU date
if date -v-1H &>/dev/null; then
  START=$(date -u -v-"${WINDOW}M" '+%Y-%m-%dT%H:%M:%SZ')
else
  START=$(date -u -d "${WINDOW} minutes ago" '+%Y-%m-%dT%H:%M:%SZ')
fi

RESOURCE_ID="${PROJECT}:${INSTANCE}"
METRIC_TYPE="cloudsql.googleapis.com/database/postgresql/insights/${MODE}/${METRIC}"

FILTER="metric.type=\"${METRIC_TYPE}\" AND resource.label.resource_id=\"${RESOURCE_ID}\""
ENCODED_FILTER=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$FILTER")

RESPONSE=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT}/timeSeries?filter=${ENCODED_FILTER}&interval.startTime=${START}&interval.endTime=${NOW}&pageSize=500")

if [ "$RAW" = true ]; then
  echo "$RESPONSE" | jq .
  exit 0
fi

# Format based on mode
if [ "$MODE" = "perquery" ]; then
  echo "$RESPONSE" | jq -r --argjson top "$TOP" '
    [.timeSeries // [] | .[] | {
      query: (.metric.labels.querystring // "N/A"),
      value: ((.points[0].value.int64Value // .points[0].value.doubleValue // "0") | tonumber),
      user: (.metric.labels.user // "N/A"),
      database: (.resource.labels.database // "N/A"),
      query_hash: (.metric.labels.query_hash // "N/A")
    }]
    | sort_by(-.value)
    | .[:$top]
    | to_entries[]
    | "\(.key + 1). [\(.value.value / 1000000 | . * 100 | round / 100)s] \(.value.query[:200])"
  '
elif [ "$MODE" = "aggregate" ]; then
  echo "$RESPONSE" | jq -r '
    [.timeSeries // [] | .[] | {
      user: (.metric.labels.user // "N/A"),
      database: (.resource.labels.database // "N/A"),
      value: ((.points[0].value.int64Value // .points[0].value.doubleValue // "0") | tonumber)
    }]
    | sort_by(-.value)
    | .[]
    | "[\(.value / 1000000 | . * 100 | round / 100)s] user=\(.user) db=\(.database)"
  '
else
  echo "$RESPONSE" | jq -r --argjson top "$TOP" '
    [.timeSeries // [] | .[] | {
      tag: (.metric.labels | to_entries | map(select(.key != "user" and .key != "client_addr")) | map("\(.key)=\(.value)") | join(",")),
      value: ((.points[0].value.int64Value // .points[0].value.doubleValue // "0") | tonumber),
      user: (.metric.labels.user // "N/A")
    }]
    | sort_by(-.value)
    | .[:$top]
    | to_entries[]
    | "\(.key + 1). [\(.value.value / 1000000 | . * 100 | round / 100)s] \(.value.tag)"
  '
fi
