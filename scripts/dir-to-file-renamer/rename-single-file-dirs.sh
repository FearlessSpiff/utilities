#!/bin/bash

# Script to rename single files in directories to match their parent directory name
# Usage: ./rename-single-file-dirs.sh <directory> [--dry-run]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
TARGET_DIR=""

for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        TARGET_DIR="$arg"
    fi
done

# Validate input
if [[ -z "$TARGET_DIR" ]]; then
    echo -e "${RED}Error: Please provide a directory path${NC}"
    echo "Usage: $0 <directory> [--dry-run]"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}Error: Directory '$TARGET_DIR' does not exist${NC}"
    exit 1
fi

# Convert to absolute path
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

echo -e "${BLUE}Scanning directory: $TARGET_DIR${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
fi
echo ""

# Counter for statistics
PROCESSED=0
SKIPPED=0

# Loop through all subdirectories
while IFS= read -r -d '' subdir; do
    # Count files in the subdirectory (excluding hidden files)
    file_count=$(find "$subdir" -maxdepth 1 -type f ! -name '.*' | wc -l)

    if [[ $file_count -eq 1 ]]; then
        # Get the single file
        file=$(find "$subdir" -maxdepth 1 -type f ! -name '.*' -print -quit)

        # Get directory name (without path)
        dir_name=$(basename "$subdir")

        # Get file extension
        file_extension="${file##*.}"

        # If file has no extension, don't add a dot
        if [[ "$file" == *"."* ]]; then
            new_filename="${dir_name}.${file_extension}"
        else
            new_filename="${dir_name}"
        fi

        # Target path for the renamed file
        new_filepath="${TARGET_DIR}/${new_filename}"

        # Check if target file already exists
        if [[ -e "$new_filepath" ]] && [[ "$new_filepath" != "$file" ]]; then
            echo -e "${RED}⊘ SKIP: $dir_name/${NC}"
            echo -e "  File '$new_filename' already exists in target directory"
            echo ""
            ((SKIPPED++)) || true
            continue
        fi

        echo -e "${GREEN}✓ PROCESS: $dir_name/${NC}"
        echo -e "  File: $(basename "$file")"
        echo -e "  Will rename to: $new_filename"
        echo -e "  Will move to: $TARGET_DIR"
        echo -e "  Will delete directory: $subdir"

        if [[ "$DRY_RUN" == false ]]; then
            # Move and rename the file
            mv "$file" "$new_filepath"

            # Remove the now-empty directory
            rmdir "$subdir"

            echo -e "  ${GREEN}Done!${NC}"
        fi

        echo ""
        ((PROCESSED++)) || true
    else
        # Skip directories with 0 or multiple files
        dir_name=$(basename "$subdir")
        if [[ $file_count -eq 0 ]]; then
            echo -e "${YELLOW}⊘ SKIP: $dir_name/ (empty directory)${NC}"
        else
            echo -e "${YELLOW}⊘ SKIP: $dir_name/ ($file_count files)${NC}"
        fi
        echo ""
        ((SKIPPED++)) || true
    fi
done < <(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

# Print summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Processed: ${GREEN}$PROCESSED${NC}"
echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}  No changes made (dry-run mode)${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
