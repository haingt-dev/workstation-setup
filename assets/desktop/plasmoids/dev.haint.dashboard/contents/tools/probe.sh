#!/bin/sh
# probe.sh — fills the stat fields ksysguard's Sensor tree cannot reliably
# supply on this box (org.kde.ksystemstats1 exposes no allSensors D-Bus call
# here, so temperature/disk sensorIds are unverifiable guesses from QML).
# POSIX sh only (invoked as `sh probe.sh`, no bash assumed). Must NEVER exit
# non-zero and must ALWAYS print exactly one JSON line — StatGrid.qml's
# JSON.parse has nowhere sane to fall back to if this script dies loud.
# Every field is optional-safe: missing/unparseable data becomes JSON null.

cpu_temp=null
# k10temp's "Tctl" is the AMD package temp. `sensors -j` + jq first; if either
# is missing or the tree shape changes, fall back to the hwmon node directly.
if command -v sensors >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    val=$(sensors -j 2>/dev/null | jq -r '[.[] | select(has("Tctl")) | .Tctl.temp1_input][0] // empty' 2>/dev/null)
    case "$val" in ''|null) : ;; *) cpu_temp=$val ;; esac
fi
if [ "$cpu_temp" = "null" ]; then
    for hw in /sys/class/hwmon/hwmon*; do
        [ -r "$hw/name" ] || continue
        if [ "$(cat "$hw/name" 2>/dev/null)" = "k10temp" ] && [ -r "$hw/temp1_input" ]; then
            raw=$(cat "$hw/temp1_input" 2>/dev/null)
            case "$raw" in ''|*[!0-9]*) : ;; *) cpu_temp=$(awk -v r="$raw" 'BEGIN{printf "%.1f", r/1000}') ;; esac
            break
        fi
    done
fi

gpu_usage=null
gpu_temp=null
if command -v nvidia-smi >/dev/null 2>&1; then
    line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    if [ -n "$line" ]; then
        u=$(echo "$line" | cut -d, -f1)
        t=$(echo "$line" | cut -d, -f2)
        case "$u" in ''|*[!0-9.]*) : ;; *) gpu_usage=$u ;; esac
        case "$t" in ''|*[!0-9.]*) : ;; *) gpu_temp=$t ;; esac
    fi
fi

disk_used_pct=null
disk_used=null
disk_total=null
df_line=$(df -P -B1 /home 2>/dev/null | tail -1)
if [ -n "$df_line" ]; then
    used_b=$(echo "$df_line" | awk '{print $3}')
    total_b=$(echo "$df_line" | awk '{print $2}')
    pct=$(echo "$df_line" | awk '{print $5}' | tr -d '%')
    case "$pct" in ''|*[!0-9]*) : ;; *) disk_used_pct=$pct ;; esac
    case "$used_b$total_b" in *[!0-9]*) : ;; *)
        if [ -n "$used_b" ] && [ -n "$total_b" ]; then
            disk_used="\"$(awk -v b="$used_b" 'BEGIN{printf "%.0fG", b/1073741824}')\""
            disk_total="\"$(awk -v b="$total_b" 'BEGIN{printf "%.0fG", b/1073741824}')\""
        fi
    ;; esac
fi

cores=null
if command -v nproc >/dev/null 2>&1; then
    c=$(nproc 2>/dev/null)
    case "$c" in ''|*[!0-9]*) : ;; *) cores=$c ;; esac
fi

printf '{"cpuTemp":%s,"gpuTemp":%s,"gpuUsage":%s,"diskUsedPct":%s,"diskUsed":%s,"diskTotal":%s,"cores":%s}\n' \
    "$cpu_temp" "$gpu_temp" "$gpu_usage" "$disk_used_pct" "$disk_used" "$disk_total" "$cores"

exit 0
