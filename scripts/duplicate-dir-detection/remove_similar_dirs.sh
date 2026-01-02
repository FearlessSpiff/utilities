#!/bin/bash

# Script to find and remove similar duplicate directories based on name similarity
# Usage: ./remove_similar_dirs.sh <directory_to_scan> <similarity_percentage> [--dry-run]

set -euo pipefail

# Check if required arguments are provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <directory_to_scan> <similarity_percentage> [--dry-run]"
    echo "Example: $0 /path/to/scan 80"
    echo "Example: $0 /path/to/scan 80 --dry-run"
    exit 1
fi

SCAN_DIR="$1"
SIMILARITY_THRESHOLD="$2"
DRY_RUN=false

# Check for dry-run flag
if [ "$#" -eq 3 ]; then
    if [ "$3" = "--dry-run" ]; then
        DRY_RUN=true
    else
        echo "Error: Unknown parameter '$3'. Use --dry-run for testing."
        exit 1
    fi
fi

# Validate directory exists
if [ ! -d "$SCAN_DIR" ]; then
    echo "Error: Directory '$SCAN_DIR' does not exist"
    exit 1
fi

# Validate similarity percentage is a number between 0 and 100
if ! [[ "$SIMILARITY_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$SIMILARITY_THRESHOLD" -lt 0 ] || [ "$SIMILARITY_THRESHOLD" -gt 100 ]; then
    echo "Error: Similarity percentage must be a number between 0 and 100"
    exit 1
fi

# Function to calculate Levenshtein distance between two strings
levenshtein_distance() {
    local s1="$1"
    local s2="$2"
    local len1=${#s1}
    local len2=${#s2}
    
    # Create a 2D array
    declare -A matrix
    
    # Initialize first row and column
    for ((i=0; i<=len1; i++)); do
        matrix[$i,0]=$i
    done
    for ((j=0; j<=len2; j++)); do
        matrix[0,$j]=$j
    done
    
    # Fill the matrix
    for ((i=1; i<=len1; i++)); do
        for ((j=1; j<=len2; j++)); do
            if [ "${s1:i-1:1}" = "${s2:j-1:1}" ]; then
                cost=0
            else
                cost=1
            fi
            
            local deletion=$((matrix[$((i-1)),$j] + 1))
            local insertion=$((matrix[$i,$((j-1))] + 1))
            local substitution=$((matrix[$((i-1)),$((j-1))] + cost))
            
            # Find minimum
            local min=$deletion
            [ $insertion -lt $min ] && min=$insertion
            [ $substitution -lt $min ] && min=$substitution
            
            matrix[$i,$j]=$min
        done
    done
    
    echo "${matrix[$len1,$len2]}"
}

# Function to calculate similarity percentage
calculate_similarity() {
    local str1="$1"
    local str2="$2"
    
    local len1=${#str1}
    local len2=${#str2}
    local max_len=$len1
    [ $len2 -gt $max_len ] && max_len=$len2
    
    if [ $max_len -eq 0 ]; then
        echo "100"
        return
    fi
    
    local distance=$(levenshtein_distance "$str1" "$str2")
    local similarity=$((100 - (distance * 100 / max_len)))
    
    echo "$similarity"
}

# Get all directories (non-recursively) in the scan directory
mapfile -t dirs < <(find "$SCAN_DIR" -maxdepth 1 -type d ! -path "$SCAN_DIR" | sort)

if [ ${#dirs[@]} -eq 0 ]; then
    echo "No subdirectories found in '$SCAN_DIR'"
    exit 0
fi

echo "Found ${#dirs[@]} directories to analyze"
echo "Similarity threshold: ${SIMILARITY_THRESHOLD}%"
if [ "$DRY_RUN" = true ]; then
    echo "Mode: DRY RUN (no directories will be deleted)"
else
    echo "Mode: LIVE (directories will be deleted)"
fi
echo ""

# Array to track directories that should be kept
declare -A keep_dirs
declare -A delete_dirs

# Compare all directories pairwise
for ((i=0; i<${#dirs[@]}; i++)); do
    dir1="${dirs[$i]}"
    basename1=$(basename "$dir1")
    
    # Skip if already marked for deletion
    if [ -n "${delete_dirs[$dir1]:-}" ]; then
        continue
    fi
    
    # Mark this directory as one to keep (unless we find it's similar to an earlier one)
    if [ -z "${keep_dirs[$dir1]:-}" ] && [ -z "${delete_dirs[$dir1]:-}" ]; then
        keep_dirs[$dir1]=1
    fi
    
    for ((j=i+1; j<${#dirs[@]}; j++)); do
        dir2="${dirs[$j]}"
        basename2=$(basename "$dir2")
        
        # Skip if already marked for deletion
        if [ -n "${delete_dirs[$dir2]:-}" ]; then
            continue
        fi
        
        # Calculate similarity
        similarity=$(calculate_similarity "$basename1" "$basename2")
        
        if [ "$similarity" -ge "$SIMILARITY_THRESHOLD" ]; then
            echo "Found similar directories (${similarity}% similar):"
            echo "  KEEP:   $dir1"
            echo "  DELETE: $dir2"
            echo ""
            delete_dirs[$dir2]=1
        fi
    done
done

# Count directories to delete
delete_count=0
for dir in "${!delete_dirs[@]}"; do
    delete_count=$((delete_count + 1))
done

if [ $delete_count -eq 0 ]; then
    echo "No similar duplicate directories found."
    exit 0
fi

echo "========================================="
echo "Summary: Found $delete_count duplicate director(ies) to delete"
echo "========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: No directories were deleted."
    echo "Run without --dry-run to perform actual deletion."
    exit 0
fi

# Delete the duplicate directories
echo "Deleting duplicate directories..."
for dir in "${!delete_dirs[@]}"; do
    echo "Deleting: $dir"
    rm -rf "$dir"
done

echo ""
echo "Done! Deleted $delete_count duplicate director(ies)."
