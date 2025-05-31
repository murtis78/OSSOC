#!/bin/bash

# Nmap Scanner Daemon
# Performs regular network scans and generates reports

set -euo pipefail

# Configuration
REPORTS_DIR="${NMAP_OUTPUT_DIR:-/reports}"
SCAN_INTERVAL="${SCAN_INTERVAL:-21600}"  # 6 hours
DEFAULT_TARGETS="${DEFAULT_SCAN_TARGETS:-192.168.1.0/24}"
NMAP_OPTS="${NMAP_DEFAULT_OPTS:--sS -O -A --script=vuln}"
LOG_FILE="${REPORTS_DIR}/nmap-daemon.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Signal handling
cleanup() {
    log "Received termination signal, cleaning up..."
    kill $SCAN_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Initialize
log "Starting Nmap Scanner Daemon"
log "Reports directory: ${REPORTS_DIR}"
log "Scan interval: ${SCAN_INTERVAL} seconds"
log "Default targets: ${DEFAULT_TARGETS}"
log "Nmap options: ${NMAP_OPTS}"

# Create reports directory
mkdir -p "${REPORTS_DIR}"/{xml,json,html}

# Function to perform scan
perform_scan() {
    local targets="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local scan_name="nmap_scan_${timestamp}"
    
    log "Starting scan: ${scan_name}"
    log "Targets: ${targets}"
    
    # XML Report
    nmap ${NMAP_OPTS} \
        -oX "${REPORTS_DIR}/xml/${scan_name}.xml" \
        -oN "${REPORTS_DIR}/${scan_name}.nmap" \
        ${targets} &
    
    SCAN_PID=$!
    wait $SCAN_PID
    
    if [ $? -eq 0 ]; then
        log "Scan completed successfully: ${scan_name}"
        
        # Convert XML to JSON
        if [ -f "${REPORTS_DIR}/xml/${scan_name}.xml" ]; then
            python3 /scripts/xml_to_json.py \
                "${REPORTS_DIR}/xml/${scan_name}.xml" \
                "${REPORTS_DIR}/json/${scan_name}.json"
        fi
        
        # Generate HTML report
        if command -v xsltproc >/dev/null 2>&1; then
            xsltproc -o "${REPORTS_DIR}/html/${scan_name}.html" \
                /usr/share/nmap/nmap.xsl \
                "${REPORTS_DIR}/xml/${scan_name}.xml" 2>/dev/null || true
        fi
        
        # Cleanup old reports (keep last 10)
        cleanup_old_reports
        
    else
        log "Scan failed: ${scan_name}"
    fi
}

# Cleanup old reports
cleanup_old_reports() {
    local keep_count=10
    
    for dir in xml json html; do
        if [ -d "${REPORTS_DIR}/${dir}" ]; then
            find "${REPORTS_DIR}/${dir}" -type f -name "nmap_scan_*" | \
                sort -r | tail -n +$((keep_count + 1)) | \
                xargs rm -f 2>/dev/null || true
        fi
    done
    
    # Cleanup .nmap files
    find "${REPORTS_DIR}" -maxdepth 1 -name "nmap_scan_*.nmap" | \
        sort -r | tail -n +$((keep_count + 1)) | \
        xargs rm -f 2>/dev/null || true
}

# Health check function
health_check() {
    if ! command -v nmap >/dev/null 2>&1; then
        error_exit "Nmap not found"
    fi
    
    if [ ! -w "${REPORTS_DIR}" ]; then
        error_exit "Reports directory not writable: ${REPORTS_DIR}"
    fi
    
    log "Health check passed"
}

# Main daemon loop
main() {
    health_check
    
    log "Daemon initialized, starting scan loop"
    
    while true; do
        # Check for custom targets file
        if [ -f "${REPORTS_DIR}/targets.txt" ]; then
            targets=$(cat "${REPORTS_DIR}/targets.txt" | grep -v '^#' | tr '\n' ' ')
            log "Using custom targets from file"
        else
            targets="${DEFAULT_TARGETS}"
            log "Using default targets"
        fi
        
        if [ -n "${targets}" ]; then
            perform_scan "${targets}"
        else
            log "No targets specified, skipping scan"
        fi
        
        log "Sleeping for ${SCAN_INTERVAL} seconds..."
        sleep "${SCAN_INTERVAL}" &
        wait $!
    done
}

# Start the daemon
main "$@"