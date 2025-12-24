#!/bin/bash
# Usage: ./save_offending_ips.sh [override_window]

set -euo pipefail

# 1. Load Configuration
CONFIG_FILE="/etc/nginx/abuse_shield/abuse_shield.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# 2. Set defaults if config is missing
TIME_WINDOW=${1:-${TIME_WINDOW:-6000}}
LOG_FILES=${LOG_FILES:-"/var/log/nginx/concise.log /var/log/nginx/concise.log.1"}
OUTPUT_FILE=${OUTPUT_FILE:-"/home/apps/nginx-apache-config/offending-ips.conf"}
# Default Tuning
THRESH_IP_DIV=${THRESH_IP_DIV:-2}
THRESH_3PART_NUM=${THRESH_3PART_NUM:-2}
THRESH_3PART_DEN=${THRESH_3PART_DEN:-3}
THRESH_2PART_NUM=${THRESH_2PART_NUM:-5}
THRESH_2PART_DEN=${THRESH_2PART_DEN:-6}

# Calculate Thresholds
THRESH_IP=$(( TIME_WINDOW / THRESH_IP_DIV ))
THRESH_3PART=$(( (THRESH_3PART_NUM * TIME_WINDOW) / THRESH_3PART_DEN ))
THRESH_2PART=$(( (THRESH_2PART_NUM * TIME_WINDOW) / THRESH_2PART_DEN ))

GEN_SCRIPT="$(dirname "$0")/range_checker.sh"

TMP=$(mktemp)
trap 'rm -f "$TMP" "$TMP".*' EXIT

touch "$OUTPUT_FILE"

timestamp() {
    echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] $*"
}

timestamp "Running analysis... Window: ${TIME_WINDOW}s"

# 1. Find candidate 2-part prefixes
$GEN_SCRIPT "$TIME_WINDOW" 2 \
    | awk -v thr="$(( THRESH_IP / 4 ))" '$2 >= thr {print $1}' > "$TMP"

if [[ ! -s "$TMP" ]]; then
    timestamp "No candidate prefixes found."
    exit 0
fi

added_any=false

while IFS= read -r prefix; do
    # Extract IPs
    awk -v now=$(date +%s) -v pre="$prefix" -v TW="$TIME_WINDOW" '
        $1 >= now-TW && $5 != 429 && $2 ~ ("^" pre "\\.") {print $2}
    ' $LOG_FILES > "$TMP.ips"

    [[ -s "$TMP.ips" ]] || continue

    sort "$TMP.ips" | uniq -c | sort -n > "$TMP.counts"

    num_unique_ips=$(wc -l < "$TMP.counts")
    mid_idx=$(( (num_unique_ips + 1) / 2 ))
    median=$(sed -n "${mid_idx}p" "$TMP.counts" | awk '{print $1}')
    median=${median:-1}

    # Decision Logic
    awk -v median="$median" \
        -v t_ip="$THRESH_IP" \
        -v t_3="$THRESH_3PART" \
        -v t_2="$THRESH_2PART" \
        -v pre="$prefix" '
    BEGIN { OFS="=" }
    {
        count = $1
        ip = $2

        split(ip, a, ".")
        s_key = a[1]"."a[2]"."a[3]

        raw_subnet_counts[s_key] += count
        raw_prefix_total += count

        cutoff = median / 2
        if (cutoff < 10) cutoff = 10

        if (count >= cutoff) {
            subnet_counts[s_key] += count
            total_abusive_reqs += count
            if (count >= t_ip) bad_ips[ip] = count
        }
    }
    END {
        hard_t_3 = t_3 * 2
        hard_t_2 = t_2 * 2

        for (s_key in raw_subnet_counts) {
            if (subnet_counts[s_key] >= t_3 || raw_subnet_counts[s_key] >= hard_t_3) {
                final_count = (raw_subnet_counts[s_key] > subnet_counts[s_key]) ? raw_subnet_counts[s_key] : subnet_counts[s_key]
                print "BAN_3PART", s_key, final_count
                total_abusive_reqs -= subnet_counts[s_key]
                raw_prefix_total -= raw_subnet_counts[s_key]
            }
        }

        if (total_abusive_reqs >= t_2 || raw_prefix_total >= hard_t_2) {
             final_count = (raw_prefix_total > total_abusive_reqs) ? raw_prefix_total : total_abusive_reqs
             print "BAN_2PART", pre, final_count
        } else {
            for (ip in bad_ips) {
                split(ip, a, ".")
                s_key = a[1]"."a[2]"."a[3]
                if (subnet_counts[s_key] < t_3 && raw_subnet_counts[s_key] < hard_t_3) {
                    print "BAN_IP", ip, bad_ips[ip]
                }
            }
        }
    }' "$TMP.counts" > "$TMP.decisions"

    # Process Decisions
    while IFS="=" read -r type target count; do
        esc=$(sed 's/\./\\./g' <<< "$target")

        if [[ "$type" == "BAN_3PART" ]]; then
            label="heavily_limited_range_${target//./_}"
            entry="    ~^${esc}\\.    \"$label\";"
            parent="${target%.*}"; parent_esc=$(sed 's/\./\\./g' <<< "$parent")

            if grep -qE "^[[:space:]]*~\^${parent_esc}\\." "$OUTPUT_FILE"; then
                timestamp "SKIP /24 $target - Parent /16 is already banned."
                continue
            fi
            if ! grep -qF "$entry" "$OUTPUT_FILE"; then
                echo "$entry" >> "$OUTPUT_FILE"
                added_any=true
                timestamp "ADDED /24: $target ($count reqs)"
            fi

        elif [[ "$type" == "BAN_2PART" ]]; then
            label="heavily_limited_range_${target//./_}"
            entry="    ~^${esc}\\.    \"$label\";"
            if ! grep -qF "$entry" "$OUTPUT_FILE"; then
                echo "$entry" >> "$OUTPUT_FILE"
                added_any=true
                timestamp "ADDED /16: $target ($count reqs)"
            fi

        elif [[ "$type" == "BAN_IP" ]]; then
            label="heavily_limited_ip_${target//./_}"
            entry="    ~^${esc}$    \"$label\";"
            sub="${target%.*}"; sub_esc=$(sed 's/\./\\./g' <<< "$sub")
            parent="${target%.*.*}"; parent_esc=$(sed 's/\./\\./g' <<< "$parent")

            if grep -qE "^[[:space:]]*~\^${sub_esc}\\." "$OUTPUT_FILE" || \
               grep -qE "^[[:space:]]*~\^${parent_esc}\\." "$OUTPUT_FILE"; then
               continue
            fi
            if ! grep -qF "$entry" "$OUTPUT_FILE"; then
                echo "$entry" >> "$OUTPUT_FILE"
                added_any=true
                timestamp "ADDED IP: $target ($count reqs)"
            fi
        fi
    done < "$TMP.decisions"

done < "$TMP"

if $added_any; then
    if nginx -t; then
        systemctl reload nginx
        timestamp "Nginx configuration reloaded successfully."
    else
        timestamp "Nginx test failed – no reload performed."
    fi
else
    timestamp "No new rules added."
fi
