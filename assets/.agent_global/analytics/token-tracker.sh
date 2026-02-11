#!/usr/bin/env bash
# Simple token usage tracker for Claude
# Extracts token stats from Claude's session history

CLAUDE_DIR="$HOME/.claude"
LOG_FILE="$HOME/.agent_global/analytics/token-usage.log"
HISTORY_FILE="$CLAUDE_DIR/history.jsonl"

show_help() {
    cat << 'EOF'
Token Usage Tracker

Usage: token-tracker.sh [command]

Commands:
  log             Log current session stats (run after Claude session)
  today           Show today's usage
  week            Show this week's usage
  month           Show this month's usage
  project <name>  Show usage for specific project
  summary         Show overall summary
  export          Export to CSV

Examples:
  token-tracker.sh today
  token-tracker.sh project Wildtide
  token-tracker.sh summary

EOF
}

# Initialize log file if doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,project,session_id,input_tokens,output_tokens,total_tokens,cost_usd" > "$LOG_FILE"
fi

# Estimate cost (rough approximation for Claude Sonnet)
calculate_cost() {
    local input_tokens=$1
    local output_tokens=$2

    # Claude 3.5 Sonnet pricing (approximate)
    # Input: $3 per million tokens
    # Output: $15 per million tokens
    local input_cost=$(echo "scale=6; $input_tokens * 3 / 1000000" | bc)
    local output_cost=$(echo "scale=6; $output_tokens * 15 / 1000000" | bc)
    local total_cost=$(echo "scale=6; $input_cost + $output_cost" | bc)

    echo "$total_cost"
}

# Log current session (parse from Claude history)
log_session() {
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "No Claude history found"
        return 1
    fi

    # Get the last session from history
    # This is simplified - actual implementation would need proper JSON parsing
    echo "⚠️  Manual logging required. Claude history format is complex."
    echo "   Use Claude's built-in stats or manually add to $LOG_FILE"
    echo ""
    echo "Format: timestamp,project,session_id,input_tokens,output_tokens,total_tokens,cost_usd"
}

# Show today's usage
show_today() {
    TODAY=$(date +%Y-%m-%d)
    echo "📊 Token Usage - Today ($TODAY)"
    echo "════════════════════════════════"

    if grep -q "^$TODAY" "$LOG_FILE"; then
        grep "^$TODAY" "$LOG_FILE" | awk -F',' '
            BEGIN {
                printf "%-20s %12s %12s %12s %10s\n", "Project", "Input", "Output", "Total", "Cost (USD)"
                printf "%-20s %12s %12s %12s %10s\n", "-------", "-----", "------", "-----", "---------"
                total_input=0
                total_output=0
                total_cost=0
            }
            NR>1 {
                project=$2
                input=$4
                output=$5
                total=$6
                cost=$7
                printf "%-20s %12d %12d %12d $%9.4f\n", project, input, output, total, cost
                total_input+=input
                total_output+=output
                total_cost+=cost
            }
            END {
                printf "%-20s %12s %12s %12s %10s\n", "-------", "-----", "------", "-----", "---------"
                printf "%-20s %12d %12d %12d $%9.4f\n", "TOTAL", total_input, total_output, total_input+total_output, total_cost
            }
        '
    else
        echo "No usage recorded for today"
    fi
}

# Show week's usage
show_week() {
    WEEK_AGO=$(date -d '7 days ago' +%Y-%m-%d)
    TODAY=$(date +%Y-%m-%d)

    echo "📊 Token Usage - Last 7 Days"
    echo "════════════════════════════════"

    awk -F',' -v start="$WEEK_AGO" -v end="$TODAY" '
        BEGIN {
            total_input=0
            total_output=0
            total_cost=0
        }
        NR>1 && $1 >= start && $1 <= end {
            total_input+=$4
            total_output+=$5
            total_cost+=$7
            count++
        }
        END {
            if (count > 0) {
                printf "Sessions:      %d\n", count
                printf "Input tokens:  %s\n", total_input
                printf "Output tokens: %s\n", total_output
                printf "Total tokens:  %s\n", total_input+total_output
                printf "Estimated cost: $%.4f\n", total_cost
                printf "\nAverage per session:\n"
                printf "  Tokens: %d\n", (total_input+total_output)/count
                printf "  Cost: $%.4f\n", total_cost/count
            } else {
                print "No usage recorded for last 7 days"
            }
        }
    ' "$LOG_FILE"
}

# Show project usage
show_project() {
    PROJECT="$1"
    if [ -z "$PROJECT" ]; then
        echo "Usage: token-tracker.sh project <project-name>"
        return 1
    fi

    echo "📊 Token Usage - Project: $PROJECT"
    echo "════════════════════════════════"

    awk -F',' -v proj="$PROJECT" '
        BEGIN {
            total_input=0
            total_output=0
            total_cost=0
        }
        NR>1 && $2 == proj {
            total_input+=$4
            total_output+=$5
            total_cost+=$7
            count++
        }
        END {
            if (count > 0) {
                printf "Sessions:      %d\n", count
                printf "Input tokens:  %s\n", total_input
                printf "Output tokens: %s\n", total_output
                printf "Total tokens:  %s\n", total_input+total_output
                printf "Estimated cost: $%.4f\n", total_cost
            } else {
                printf "No usage recorded for project: %s\n", proj
            }
        }
    ' "$LOG_FILE"
}

# Show summary
show_summary() {
    echo "📊 Token Usage - Overall Summary"
    echo "════════════════════════════════"

    awk -F',' '
        BEGIN {
            printf "%-20s %10s %12s\n", "Project", "Sessions", "Cost (USD)"
            printf "%-20s %10s %12s\n", "-------", "--------", "---------"
        }
        NR>1 {
            projects[$2]++
            costs[$2]+=$7
            total_sessions++
            total_cost+=$7
        }
        END {
            for (proj in projects) {
                printf "%-20s %10d $%11.4f\n", proj, projects[proj], costs[proj]
            }
            printf "%-20s %10s %12s\n", "-------", "--------", "---------"
            printf "%-20s %10d $%11.4f\n", "TOTAL", total_sessions, total_cost
        }
    ' "$LOG_FILE"
}

# Export to CSV
export_csv() {
    EXPORT_FILE="$HOME/.agent_global/analytics/token-usage-export-$(date +%Y%m%d).csv"
    cp "$LOG_FILE" "$EXPORT_FILE"
    echo "✅ Exported to: $EXPORT_FILE"
}

# Main command dispatcher
case "${1:-help}" in
    log)
        log_session
        ;;
    today)
        show_today
        ;;
    week)
        show_week
        ;;
    month)
        # TODO: Implement monthly view
        echo "Monthly view not yet implemented"
        ;;
    project)
        show_project "$2"
        ;;
    summary)
        show_summary
        ;;
    export)
        export_csv
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
