#!/bin/bash
# Usage: ./range_checker.sh [override_window] [override_parts]

set -euo pipefail

# 1. Load Configuration
CONFIG_FILE="/etc/nginx/abuse_shield/abuse_shield.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# 2. Allow CLI overrides or defaults if config is missing
TIME_WINDOW=${1:-${TIME_WINDOW:-6000}}
IP_PARTS=${2:-${IP_PARTS:-2}}
LOG_FILES=${LOG_FILES:-"/var/log/nginx/concise.log /var/log/nginx/concise.log.1"}

# Known good ranges
skip_ranges=(
    "2.204" "8.160" "18.97" "20.171" "27.63" "39.58" "40.77" "49.37"
    "51.222" "52.167" "57.141" "66.249" "85.208" "102.8" "103.197"
    "103.244" "106.8" "120.50" "136.243" "185.191" "206.213" "97.246"
)

skip_list=$(printf "%s|" "${skip_ranges[@]}"); skip_list=${skip_list%|}
now=$(date +%s)

# Pass LOG_FILES directly to awk
awk -v now="$now" -v skip="$skip_list" -v window="$TIME_WINDOW" -v parts="$IP_PARTS" '
    $1 >= now - window && $5 != 429 {
        split($2, a, ".")
        key = a[1]
        for (i = 2; i <= parts && i <= 4; i++) key = key "." a[i]
        if (key !~ "^(" skip ")$") count[key]++
    }
    END {
        for (k in count) print k, count[k]
    }
' $LOG_FILES | sort -k2 -nr
