#!/bin/bash

# generateDocs.sh - Generate static Oak framework documentation
# This script generates static documentation using Swift-DocC for deployment

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

echo -e "${BLUE}📚 Oak Documentation Generator${NC}"
echo -e "${BLUE}==============================${NC}"

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

# Also check for any processes using the .build directory
if [ -d ".build" ]; then
    BUILD_PIDS=$(lsof +D .build 2>/dev/null | awk 'NR>1 {print $2}' | sort -u 2>/dev/null || true)
    if [ -n "$BUILD_PIDS" ]; then
        echo -e "${YELLOW}⚠️  Found processes using .build directory. Stopping them...${NC}"
        echo "$BUILD_PIDS" | xargs kill -TERM 2>/dev/null || true
        sleep 2
    fi
fi

# Clean up previous documentation
if [ -d "generated-docs" ]; then
    echo -e "${YELLOW}🧹 Cleaning up previous documentation...${NC}"
    rm -rf generated-docs
fi

echo -e "${YELLOW}📚 Generating static documentation...${NC}"

# First, try to generate documentation without static hosting to see if basic generation works
echo -e "${BLUE}ℹ️  Attempting basic documentation generation first...${NC}"

# Create output directory
mkdir -p ./generated-docs

# Try basic documentation generation first
if swift package --disable-sandbox generate-documentation --target Oak; then
    echo -e "${GREEN}✅ Basic documentation generation successful!${NC}"
    
    # Now try with static hosting transformation
    echo -e "${BLUE}ℹ️  Converting to static hosting format...${NC}"
    
    # Generate static documentation
    if swift package --disable-sandbox generate-documentation \
        --target Oak \
        --disable-indexing \
        --transform-for-static-hosting \
        --output-path ./generated-docs; then
        
        echo -e "${GREEN}✅ Documentation generated successfully!${NC}"
        echo -e "${BLUE}📁 Output location: $(pwd)/generated-docs${NC}"
        echo -e "${BLUE}🌐 To serve locally: cd generated-docs && python3 -m http.server 8080${NC}"
        echo -e "${BLUE}   Then open: http://localhost:8080/documentation/oak${NC}"
    else
        echo -e "${YELLOW}⚠️  Static hosting transformation failed, but basic docs were generated.${NC}"
        echo -e "${BLUE}ℹ️  You can find the documentation in: .build/plugins/Swift-DocC/outputs/Oak.doccarchive${NC}"
        echo -e "${BLUE}ℹ️  To view: open .build/plugins/Swift-DocC/outputs/Oak.doccarchive${NC}"
    fi
else
    echo -e "${RED}❌ Documentation generation failed.${NC}"
    echo -e "${YELLOW}💡 This might be because:${NC}"
    echo -e "${YELLOW}   1. No .docc catalog exists in the project${NC}"
    echo -e "${YELLOW}   2. No documentation comments are present${NC}"
    echo -e "${YELLOW}   3. The target name might be incorrect${NC}"
    echo ""
    echo -e "${BLUE}ℹ️  Try adding some documentation comments to your Swift files first.${NC}"
    echo -e "${BLUE}ℹ️  Example: /// This is a documentation comment${NC}"
    exit 1
fi
