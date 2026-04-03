#!/bin/bash
# capture-tokens.sh — Claude Code Stop hook
# Captures token usage data from each session for agentic cost tracking.
# Installed to ~/.claude/hooks/capture-tokens.sh by the agentic installer.
#
# Claude Code calls this script automatically when a session ends, passing
# session data as JSON on stdin.

set -euo pipefail

METRICS_FILE="$HOME/.config/agentic-metrics.json"

# Require jq (agentic dependency — should always be present)
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Read hook payload from stdin
input=$(cat)

# Extract fields from Claude Code Stop hook payload
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
input_tokens=$(echo "$input" | jq -r '.usage.input_tokens // 0' 2>/dev/null || echo 0)
output_tokens=$(echo "$input" | jq -r '.usage.output_tokens // 0' 2>/dev/null || echo 0)
cache_read=$(echo "$input" | jq -r '.usage.cache_read_input_tokens // 0' 2>/dev/null || echo 0)
cache_write=$(echo "$input" | jq -r '.usage.cache_creation_input_tokens // 0' 2>/dev/null || echo 0)
model=$(echo "$input" | jq -r '.model // "unknown"' 2>/dev/null || echo "unknown")

# Defaults
input_tokens=${input_tokens:-0}
output_tokens=${output_tokens:-0}
cache_read=${cache_read:-0}
cache_write=${cache_write:-0}
session_id=${session_id:-$(date +%s)}

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
date_key=$(date -u +"%Y-%m-%d")

# Initialize metrics file if missing
if [ ! -f "$METRICS_FILE" ]; then
    mkdir -p "$(dirname "$METRICS_FILE")"
    echo '{}' > "$METRICS_FILE"
fi

# Accumulate token counts: per-session snapshot, daily rollup, and all-time totals
jq \
    --arg session_id    "$session_id" \
    --arg timestamp     "$timestamp" \
    --arg date_key      "$date_key" \
    --arg model         "$model" \
    --argjson in_tok    "$input_tokens" \
    --argjson out_tok   "$output_tokens" \
    --argjson c_read    "$cache_read" \
    --argjson c_write   "$cache_write" \
    '
    .last_session = {
        "session_id":                  $session_id,
        "timestamp":                   $timestamp,
        "model":                       $model,
        "input_tokens":                $in_tok,
        "output_tokens":               $out_tok,
        "cache_read_input_tokens":     $c_read,
        "cache_creation_input_tokens": $c_write
    } |
    .daily[$date_key].input_tokens                = ((.daily[$date_key].input_tokens                // 0) + $in_tok)  |
    .daily[$date_key].output_tokens               = ((.daily[$date_key].output_tokens               // 0) + $out_tok) |
    .daily[$date_key].cache_read_input_tokens     = ((.daily[$date_key].cache_read_input_tokens     // 0) + $c_read)  |
    .daily[$date_key].cache_creation_input_tokens = ((.daily[$date_key].cache_creation_input_tokens // 0) + $c_write) |
    .daily[$date_key].sessions                    = ((.daily[$date_key].sessions                    // 0) + 1)        |
    .totals.input_tokens                = ((.totals.input_tokens                // 0) + $in_tok)  |
    .totals.output_tokens               = ((.totals.output_tokens               // 0) + $out_tok) |
    .totals.cache_read_input_tokens     = ((.totals.cache_read_input_tokens     // 0) + $c_read)  |
    .totals.cache_creation_input_tokens = ((.totals.cache_creation_input_tokens // 0) + $c_write) |
    .totals.sessions                    = ((.totals.sessions                    // 0) + 1)
    ' "$METRICS_FILE" > "${METRICS_FILE}.tmp" \
    && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
