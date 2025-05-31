#!/bin/bash

# OpenVAS Scan Scheduler
# Automatically schedules and manages vulnerability scans

set -euo pipefail

# Configuration
OPENVAS_HOST="${OPENVAS_HOST:-openvas}"
OPENVAS_PORT="${OPENVAS_PORT:-9390}"
OPENVAS_USER="${OPENVAS_USER:-admin}"
OPENVAS_PASS="${OPENVAS_ADMIN_PWD:-ChangeMe!}"
SCAN_INTERVAL="${SCAN_INTERVAL:-21600}"  # 6 hours
LOG_FILE="/tmp/scheduler.log"
MAX_CONCURRENT_SCANS="${MAX_CONCURRENT_SCANS:-3}"
DEFAULT_TARGETS="${DEFAULT_SCAN_TARGETS:-192.168.1.0/24}"

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
    exit 0
}

trap cleanup SIGTERM SIGINT

# Wait for OpenVAS to be ready
wait_for_openvas() {
    log "Waiting for OpenVAS to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "http://${OPENVAS_HOST}:9392" >/dev/null 2>&1; then
            log "OpenVAS is ready"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log "Attempt $attempt/$max_attempts - OpenVAS not ready yet"
        sleep 10
    done
    
    error_exit "OpenVAS failed to become ready after $max_attempts attempts"
}

# Get scan configs via GMP
get_scan_configs() {
    # This would typically use gvm-tools or direct GMP protocol
    # For simplicity, we'll use curl to check API availability
    log "Retrieving scan configurations..."
    
    # Return default config ID (this would be dynamic in real implementation)
    echo "daba56c8-73ec-11df-a475-002264764cea"  # Full and fast scan config
}

# Create scan target
create_scan_target() {
    local target_name="$1"
    local target_hosts="$2"
    
    log "Creating scan target: $target_name"
    log "Target hosts: $target_hosts"
    
    # In real implementation, this would use GMP protocol
    # For now, we'll simulate the creation
    local target_id="target_$(date +%s)"
    log "Created target with ID: $target_id"
    echo "$target_id"
}

# Start vulnerability scan
start_scan() {
    local scan_name="$1"
    local target_id="$2"
    local config_id="$3"
    
    log "Starting scan: $scan_name"
    log "Target ID: $target_id"
    log "Config ID: $config_id"
    
    # In real implementation, this would use GMP protocol to start scan
    local scan_id="scan_$(date +%s)"
    log "Started scan with ID: $scan_id"
    echo "$scan_id"
}

# Check scan status
check_scan_status() {
    local scan_id="$1"
    
    # In real implementation, this would query scan status via GMP
    # For simulation, we'll randomly return status
    local statuses=("Running" "Done" "Stopped" "Requested")
    local random_index=$((RANDOM % ${#statuses[@]}))
    echo "${statuses[$random_index]}"
}

# Get running scans count
get_running_scans_count() {
    # In real implementation, this would query active scans
    # For simulation, return random number between 0 and MAX_CONCURRENT_SCANS
    echo $((RANDOM % (MAX_CONCURRENT_SCANS + 1)))
}

# Perform scheduled scan
perform_scheduled_scan() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local scan_name="scheduled_scan_${timestamp}"
    
    # Check if we can start new scan
    local running_scans=$(get_running_scans_count)
    if [ "$running_scans" -ge "$MAX_CONCURRENT_SCANS" ]; then
        log "Maximum concurrent scans reached ($running_scans/$MAX_CONCURRENT_SCANS), skipping"
        return
    fi
    
    log "Starting scheduled scan: $scan_name"
    
    # Get scan configuration
    local config_id=$(get_scan_configs)
    
    # Create target
    local target_id=$(create_scan_target "$scan_name" "$DEFAULT_TARGETS")
    
    # Start scan
    local scan_id=$(start_scan "$scan_name" "$target_id" "$config_id")
    
    log "Scan started successfully - ID: $scan_id"
    
    # Store scan info for monitoring
    echo "$scan_id|$scan_name|$(date +%s)" >> /tmp/active_scans.log
}

# Monitor active scans
monitor_scans() {
    if [ ! -f /tmp/active_scans.log ]; then
        return
    fi
    
    log "Monitoring active scans..."
    
    while IFS='|' read -r scan_id scan_name start_time || [ -n "$scan_id" ]; do
        if [ -n "$scan_id" ]; then
            local status=$(check_scan_status "$scan_id")
            local current_time=$(date +%s)
            local duration=$((current_time - start_time))
            
            log "Scan $scan_name ($scan_id): $status (running for ${duration}s)"
            
            if [ "$status" = "Done" ] || [ "$status" = "Stopped" ]; then
                log "Scan completed: $scan_name"
                # Remove from active scans
                grep -v "^$scan_id|" /tmp/active_scans.log > /tmp/active_scans.log.tmp || true
                mv /tmp/active_scans.log.tmp /tmp/active_scans.log 2>/dev/null || true
            fi
        fi
    done < /tmp/active_scans.log
}

# Cleanup old logs and temporary files
cleanup_files() {
    log "Performing cleanup..."
    
    # Remove old log entries (keep last 1000 lines)
    if [ -f "$LOG_FILE" ]; then
        tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" || true
        mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null || true
    fi
    
    # Clean up old scan records (older than 7 days)
    if [ -f /tmp/active_scans.log ]; then
        local cutoff_time=$(($(date +%s) - 604800))  # 7 days ago
        while IFS='|' read -r scan_id scan_name start_time || [ -n "$scan_id" ]; do
            if [ -n "$start_time" ] && [ "$start_time" -gt "$cutoff_time" ]; then
                echo "$scan_id|$scan_name|$start_time"
            fi
        done < /tmp/active_scans.log > /tmp/active_scans.log.tmp || true
        mv /tmp/active_scans.log.tmp /tmp/active_scans.log 2>/dev/null || true
    fi
}

# Health check
health_check() {
    if ! command -v curl >/dev/null 2>&1; then
        error_exit "curl not found"
    fi
    
    log "Health check passed"
}

# Main scheduler loop
main() {
    log "Starting OpenVAS Scan Scheduler"
    log "OpenVAS Host: $OPENVAS_HOST:$OPENVAS_PORT"
    log "Scan Interval: $SCAN_INTERVAL seconds"
    log "Max Concurrent Scans: $MAX_CONCURRENT_SCANS"
    log "Default Targets: $DEFAULT_TARGETS"
    
    health_check
    wait_for_openvas
    
    # Initialize
    touch /tmp/active_scans.log
    local cleanup_counter=0
    
    log "Scheduler initialized, starting main loop"
    
    while true; do
        # Monitor existing scans
        monitor_scans
        
        # Perform scheduled scan
        perform_scheduled_scan
        
        # Periodic cleanup (every 24 iterations)
        cleanup_counter=$((cleanup_counter + 1))
        if [ $((cleanup_counter % 24)) -eq 0 ]; then
            cleanup_files
            cleanup_counter=0
        fi
        
        log "Sleeping for $SCAN_INTERVAL seconds..."
        sleep "$SCAN_INTERVAL" &
        wait $!
    done
}

# Start the scheduler
main "$@"