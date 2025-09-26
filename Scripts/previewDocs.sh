#!/bin/bash

# previewDocs.sh - Generate and preview Oak framework documentation
# This script generates documentation using Swift-DocC and opens it in the default browser

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Oak Documentation Preview${NC}"
echo -e "${BLUE}=============================${NC}"

# Check for optional --vscode flag to use VS Code's simple browser
USE_VSCODE_BROWSER=false
if [[ "$1" == "--vscode" ]]; then
    USE_VSCODE_BROWSER=true
    echo -e "${BLUE}ℹ️  Using VS Code Simple Browser mode${NC}"
fi

# Check if we're in the right directory
if [ ! -f "$PROJECT_ROOT/Package.swift" ]; then
    echo -e "${RED}❌ Error: Package.swift not found. Please run this script from the Oak project root.${NC}"
    exit 1
fi

# Change to project root
cd "$PROJECT_ROOT"

# Check for running Swift processes and stop them
echo -e "${YELLOW}🔍 Checking for running Swift Package Manager processes...${NC}"
SPM_PIDS=$(pgrep -f "swift package" 2>/dev/null || true)
if [ -n "$SPM_PIDS" ]; then
    echo -e "${YELLOW}⚠️  Found running Swift Package Manager processes. Stopping them...${NC}"
    echo "$SPM_PIDS" | xargs kill -TERM 2>/dev/null || true
    sleep 2
    # Force kill if still running
    SPM_PIDS=$(pgrep -f "swift package" 2>/dev/null || true)
    if [ -n "$SPM_PIDS" ]; then
        echo -e "${YELLOW}⚠️  Force stopping Swift Package Manager processes...${NC}"
        echo "$SPM_PIDS" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
fi

echo -e "${YELLOW}📚 Generating documentation...${NC}"

# Generate documentation with preview server
echo -e "${BLUE}ℹ️  Starting documentation preview server...${NC}"
echo -e "${BLUE}   This will build the project and start a local server.${NC}"
echo -e "${BLUE}   Press Ctrl+C to stop the server when done.${NC}"
echo ""

# Check if port 8081 is already in use
if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Port 8081 is already in use. Trying to stop existing process...${NC}"
    lsof -ti:8081 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Start the documentation preview server
echo -e "${GREEN}🔧 Starting Swift-DocC preview server...${NC}"

# Function to open browser after server starts
open_browser() {
    sleep 3  # Wait for server to start
    echo -e "${GREEN}🌐 Opening documentation in browser...${NC}"
    
    if [[ "$USE_VSCODE_BROWSER" == "true" ]]; then
        echo -e "${BLUE}ℹ️  Opening in VS Code Simple Browser...${NC}"
        echo -e "${BLUE}   Note: Copy this URL to VS Code's Simple Browser: http://localhost:8081/documentation/oak${NC}"
        return
    fi
    
    # Try to open in developer-friendly browsers first, then fall back to default
    if command -v "/Applications/Firefox.app/Contents/MacOS/firefox" >/dev/null 2>&1; then
        echo -e "${BLUE}ℹ️  Opening in Firefox (HTTP-friendly)...${NC}"
        open -a "Firefox" "http://localhost:8081/documentation/oak"
    elif command -v "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" >/dev/null 2>&1; then
        echo -e "${BLUE}ℹ️  Opening in Google Chrome (HTTP-friendly)...${NC}"
        open -a "Google Chrome" "http://localhost:8081/documentation/oak"
    elif command -v "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" >/dev/null 2>&1; then
        echo -e "${BLUE}ℹ️  Opening in Microsoft Edge (HTTP-friendly)...${NC}"
        open -a "Microsoft Edge" "http://localhost:8081/documentation/oak"
    else
        echo -e "${YELLOW}⚠️  Opening in default browser...${NC}"
        echo -e "${YELLOW}   If Safari shows security warnings for HTTP, try:${NC}"
        echo -e "${YELLOW}   1. Run: ./Scripts/previewDocs.sh --vscode (for VS Code Simple Browser)${NC}"
        echo -e "${YELLOW}   2. Allow HTTP for localhost in Safari settings${NC}"
        echo -e "${YELLOW}   3. Or manually open: http://localhost:8081/documentation/oak${NC}"
        echo -e "${YELLOW}   4. Or install Chrome/Firefox for better HTTP localhost support${NC}"
        open "http://localhost:8081/documentation/oak"
    fi
}

# Start browser opener in background
open_browser &

# Start the documentation preview server
# The --disable-sandbox flag is required for network access
# Platform availability is now handled via @Available metadata in Index.md
swift package --disable-sandbox plugin preview-documentation --target Oak --port 8081

echo -e "${GREEN}✅ Documentation preview completed.${NC}"
if [[ "$USE_VSCODE_BROWSER" == "true" ]]; then
    echo -e "${BLUE}💡 To view in VS Code: Open Simple Browser and navigate to:${NC}"
    echo -e "${BLUE}   http://localhost:8081/documentation/oak${NC}"
fi
