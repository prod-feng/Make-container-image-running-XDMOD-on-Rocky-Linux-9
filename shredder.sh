#!/bin/bash

# Function to print usage instructions
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Extracts Slurm accounting data within a specified UTC time range."
    echo ""
    echo "Options:"
    echo "  -s, --starttime TIMESTAMP  Start time in ISO 8601 format (YYYY-MM-DDTHH:MM:SS)"
    echo "                             Default: 30 days ago at midnight"
    echo "  -e, --endtime   TIMESTAMP  End time in ISO 8601 format (YYYY-MM-DDTHH:MM:SS)"
    echo "                             Default: End of the current day"
    echo "  -h, --help                 Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  $(basename "$0") -s 2025-05-01T00:00:00 -e 2026-08-26T23:59:59"
    exit 0
}

# Calculate default values
DEFAULT_START=$(date -u -d "30 days ago" +"%Y-%m-%dT00:00:00")
DEFAULT_END=$(date -u +"%Y-%m-%dT23:59:59")

# Initialize variables with defaults
START_TIME="$DEFAULT_START"
END_TIME="$DEFAULT_END"

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -s|--starttime)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option '$1' requires an argument." >&2
                exit 1
            fi
            START_TIME="$2"
            shift 2
            ;;
        -e|--endtime)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option '$1' requires an argument." >&2
                exit 1
            fi
            END_TIME="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Use -h or --help for usage instructions." >&2
            exit 1
            ;;
    esac
done

# Helper to validate ISO 8601 format (YYYY-MM-DDTHH:MM:SS)
validate_date() {
    local date_str="$1"
    local opt_name="$2"
    if ! [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo "Error: Invalid format for $opt_name: '$date_str'." >&2
        echo "Please use ISO 8601 format: YYYY-MM-DDTHH:MM:SS" >&2
        exit 1
    fi
}

# Run validations
validate_date "$START_TIME" "starttime"
validate_date "$END_TIME" "endtime"

echo "Extracting Slurm data from $START_TIME to $END_TIME (UTC)..."

# Run sacct command
TZ=UTC sacct \
  --clusters all \
  -a \
  --parsable2 \
  --noheader \
  --allocations \
  --duplicates \
  --format=jobid,jobidraw,cluster,partition,qos,account,group,gid,user,uid,submit,eligible,start,end,elapsed,exitcode,state,nnodes,ncpus,reqcpus,reqmem,reqtres,alloctres,timelimit,nodelist,jobname \
  --starttime "$START_TIME" \
  --endtime "$END_TIME" \
  > ./slurm_data.txt

echo "Data extraction complete. Saved to ./slurm_data.txt"
