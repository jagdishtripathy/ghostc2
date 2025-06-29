#!/bin/bash

# GhostC2 Setup Script
# This script helps set up the GhostC2 environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[*]${NC} $1"
}

error() {
    echo -e "${RED}[!]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

success() {
    echo -e "${GREEN}[+]${NC} $1"
}

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    GhostC2 Setup Script                      ║"
echo "║                                                              ║"
echo "║  This script will help you set up GhostC2 for testing       ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if we're in the right directory
if [ ! -f "server/main.go" ]; then
    error "This script must be run from the GhostC2 project root directory"
    error "Please navigate to the ghostc2 folder and run this script again"
    exit 1
fi

log "Checking prerequisites..."

# Check if Go is installed
if ! command -v go &> /dev/null; then
    error "Go is not installed. Please install Go 1.19 or higher."
    error "Download from: https://golang.org/dl/"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
log "Found Go version: $GO_VERSION"

# Check if curl is available
if ! command -v curl &> /dev/null; then
    warn "curl is not installed. It's required for Linux/macOS agents."
    warn "Please install curl: sudo apt install curl (Ubuntu/Debian) or brew install curl (macOS)"
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    warn "jq is not installed. It's recommended for better JSON parsing."
    warn "Please install jq: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)"
fi

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    log "Found Python version: $PYTHON_VERSION"
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version | awk '{print $2}')
    log "Found Python version: $PYTHON_VERSION"
else
    warn "Python is not installed. Python agent will not be available."
fi

log "Setting up agent scripts..."

# Make shell scripts executable
if [ -f "agents/linux_agent.sh" ]; then
    chmod +x agents/linux_agent.sh
    success "Made linux_agent.sh executable"
fi

if [ -f "agents/mac_agent.sh" ]; then
    chmod +x agents/mac_agent.sh
    success "Made mac_agent.sh executable"
fi

if [ -f "agents/python_agent.py" ]; then
    chmod +x agents/python_agent.py
    success "Made python_agent.py executable"
fi

# Check if tasks.json exists and is writable
if [ ! -f "server/tasks.json" ]; then
    echo "[]" > server/tasks.json
    success "Created tasks.json file"
fi

log "Checking Go modules..."
if [ -f "go.mod" ]; then
    log "Go modules already initialized"
else
    log "Initializing Go modules..."
    go mod init ghostc2
    success "Initialized Go modules"
fi

log "Building server..."
if go build -o ghostc2 server/main.go; then
    success "Server built successfully"
else
    error "Failed to build server"
    exit 1
fi

echo
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
success "GhostC2 setup completed successfully!"
echo
log "Next steps:"
echo "  1. Start the server: ./ghostc2"
echo "  2. Open your browser to: http://localhost:8080"
echo "  3. Login with: ghostc2 / ghostc2"
echo "  4. Run agents on target systems:"
echo "     - Windows: powershell -ExecutionPolicy Bypass -File agents/windows_agent.ps1"
echo "     - Linux:   ./agents/linux_agent.sh"
echo "     - macOS:   ./agents/mac_agent.sh"
echo "     - Python:  python3 agents/python_agent.py"
echo
log "For remote testing, modify SERVER_URL in agent scripts to your server's IP"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo 