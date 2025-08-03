#!/bin/bash

# formatCode.sh - Format Swift files in the Oak project using swift-format
# By default, runs in dry-run mode showing what would be changed
# 
# Usage:
#   ./Scripts/formatCode.sh              # Preview git staged/modified files (dry-run)
#   ./Scripts/formatCode.sh --apply      # Actually format git staged/modified files
#   ./Scripts/formatCode.sh --all        # Preview ALL Swift files in project
#   ./Scripts/formatCode.sh --all --apply  # Format ALL Swift files in project
#
# This script finds and formats Swift source files using git status by default

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

echo -e "${BLUE}🎨 Oak Code Formatter${NC}"
echo -e "${BLUE}===================${NC}"

# Check if swift-format is installed
if ! command -v swift-format >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: swift-format is not installed${NC}"
    echo -e "${YELLOW}💡 Install swift-format:${NC}"
    echo -e "${YELLOW}   1. Clone: git clone https://github.com/apple/swift-format.git${NC}"
    echo -e "${YELLOW}   2. Build: cd swift-format && swift build -c release${NC}"
    echo -e "${YELLOW}   3. Install: cp .build/release/swift-format /usr/local/bin/${NC}"
    echo -e "${YELLOW}   Or use Homebrew: brew install swift-format${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "$PROJECT_ROOT/Package.swift" ]; then
    echo -e "${RED}❌ Error: Package.swift not found. Please run this script from the Oak project root.${NC}"
    exit 1
fi

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${YELLOW}🔍 Finding Swift files to format...${NC}"

# Check for optional flags
DRY_RUN=true  # Default to dry-run mode
FORMAT_ALL=false

for arg in "$@"; do
    case $arg in
        --apply)
            DRY_RUN=false
            ;;
        --all)
            FORMAT_ALL=true
            ;;
    esac
done

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 Running in dry-run mode (no files will be modified)${NC}"
    echo -e "${BLUE}💡 Use --apply flag to actually format files${NC}"
else
    echo -e "${GREEN}🎨 Applying formatting changes${NC}"
fi

if [[ "$FORMAT_ALL" == "true" ]]; then
    echo -e "${BLUE}📂 Formatting ALL Swift files in project${NC}"
    # Find all Swift files, excluding hidden directories, build directories, and package dependencies
    SWIFT_FILES=$(find . -name "*.swift" \
        -not -path "*/.*" \
        -not -path "*/build/*" \
        -not -path "*/.build/*" \
        -not -path "*/DerivedData/*" \
        -not -path "*/Package.resolved" \
        -not -path "*/checkouts/*")
else
    echo -e "${BLUE}📂 Formatting Swift files in git index and working directory${NC}"
    # Get files that are either staged or modified (but exclude deleted files)
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=d | grep '\.swift$' || true)
    MODIFIED_FILES=$(git diff --name-only --diff-filter=d | grep '\.swift$' || true)
    
    # Combine and deduplicate the files
    SWIFT_FILES=$(echo -e "$STAGED_FILES\n$MODIFIED_FILES" | sort -u | grep -v '^$' || true)
fi

if [ -z "$SWIFT_FILES" ]; then
    if [[ "$FORMAT_ALL" == "true" ]]; then
        echo -e "${YELLOW}⚠️  No Swift files found to format${NC}"
    else
        echo -e "${YELLOW}⚠️  No Swift files in git index or working directory to format${NC}"
        echo -e "${BLUE}💡 Use --all flag to format all Swift files in the project${NC}"
    fi
    exit 0
fi

# Count files
FILE_COUNT=$(echo "$SWIFT_FILES" | wc -l | xargs)
if [[ "$FORMAT_ALL" == "true" ]]; then
    echo -e "${BLUE}📋 Found ${FILE_COUNT} Swift files to format${NC}"
else
    echo -e "${BLUE}� Found ${FILE_COUNT} Swift files in git to format${NC}"
fi

echo -e "${GREEN}🎨 Formatting Swift files...${NC}"

# Format each file
FORMATTED_COUNT=0
FAILED_COUNT=0

while IFS= read -r file; do
    if [[ "$DRY_RUN" == "true" ]]; then
        # Dry run - check if file would be changed
        if ! swift-format --mode diff "$file" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}📝 Would format: $file${NC}"
            ((FORMATTED_COUNT++))
        fi
    else
        # Actually format the file
        if swift-format --in-place "$file" 2>/dev/null; then
            echo -e "  ${GREEN}✅ Formatted: $file${NC}"
            ((FORMATTED_COUNT++))
        else
            echo -e "  ${RED}❌ Failed: $file${NC}"
            ((FAILED_COUNT++))
        fi
    fi
done <<< "$SWIFT_FILES"

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${GREEN}🔍 Dry run completed:${NC}"
    echo -e "${BLUE}  📋 Files that would be formatted: ${FORMATTED_COUNT}${NC}"
    echo -e "${BLUE}  📋 Total files checked: ${FILE_COUNT}${NC}"
    if [[ $FORMATTED_COUNT -gt 0 ]]; then
        echo -e "${YELLOW}💡 Run with --apply flag to actually format these files${NC}"
    else
        echo -e "${GREEN}✨ All files are already properly formatted!${NC}"
    fi
else
    echo -e "${GREEN}✅ Code formatting completed:${NC}"
    echo -e "${BLUE}  📋 Files processed: ${FILE_COUNT}${NC}"
    echo -e "${GREEN}  ✅ Successfully formatted: ${FORMATTED_COUNT}${NC}"
    if [[ $FAILED_COUNT -gt 0 ]]; then
        echo -e "${RED}  ❌ Failed to format: ${FAILED_COUNT}${NC}"
    fi
fi

if [[ $FAILED_COUNT -gt 0 ]]; then
    exit 1
fi
