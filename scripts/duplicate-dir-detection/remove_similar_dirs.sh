#!/bin/bash

# Script to find and remove similar duplicate directories based on name similarity
# Usage: ./remove_similar_dirs.sh <directory_to_scan> <similarity_percentage> [options]

set -euo pipefail

show_usage() {
    echo "Usage: $0 <directory_to_scan> <similarity_percentage> [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run           Preview changes without deleting anything"
    echo "  --keep=<strategy>   Strategy for choosing which directory to keep:"
    echo "                        first   - Keep first alphabetically (default)"
    echo "                        newest  - Keep the most recently modified"
    echo "                        largest - Keep the one with most disk usage"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/scan 80"
    echo "  $0 /path/to/scan 80 --dry-run"
    echo "  $0 /path/to/scan 80 --keep=newest"
    echo "  $0 /path/to/scan 80 --keep=largest --dry-run"
}

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    show_usage
    exit 1
fi

SCAN_DIR="$1"
SIMILARITY_THRESHOLD="$2"
DRY_RUN=false
KEEP_STRATEGY="first"

# Parse optional arguments
shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --keep=*)
            KEEP_STRATEGY="${1#--keep=}"
            if [[ ! "$KEEP_STRATEGY" =~ ^(first|newest|largest)$ ]]; then
                echo "Error: Invalid keep strategy '$KEEP_STRATEGY'. Use: first, newest, or largest"
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown parameter '$1'"
            show_usage
            exit 1
            ;;
    esac
    shift
done

# Validate directory exists
if [ ! -d "$SCAN_DIR" ]; then
    echo "Error: Directory '$SCAN_DIR' does not exist"
    exit 1
fi

# Check for bc if using newest strategy (needed for floating-point comparison)
if [ "$KEEP_STRATEGY" = "newest" ] && ! command -v bc &> /dev/null; then
    echo "Error: 'bc' is required for --keep=newest but is not installed"
    exit 1
fi

# Check for agrep (required for fast similarity matching)
if ! command -v agrep &> /dev/null; then
    echo "Error: 'agrep' is required but is not installed"
    echo "Install with: sudo pacman -S tre (Arch) or sudo apt install agrep (Debian/Ubuntu)"
    exit 1
fi

# Validate similarity percentage is a number between 0 and 100
if ! [[ "$SIMILARITY_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$SIMILARITY_THRESHOLD" -lt 0 ] || [ "$SIMILARITY_THRESHOLD" -gt 100 ]; then
    echo "Error: Similarity percentage must be a number between 0 and 100"
    exit 1
fi

# Fast similarity check using agrep
# Returns similarity percentage if strings are similar enough, 0 otherwise
# Uses agrep for O(n) approximate matching instead of O(n*m) Levenshtein
calculate_similarity() {
    local str1="$1"
    local str2="$2"

    local len1=${#str1}
    local len2=${#str2}
    local max_len=$len1
    local min_len=$len2
    if [ $len2 -gt $max_len ]; then
        max_len=$len2
        min_len=$len1
    fi

    if [ $max_len -eq 0 ]; then
        echo "100"
        return
    fi

    # Quick filter: if length difference exceeds max allowed errors, skip
    # Formula: similarity = 100 - (distance * 100 / max_len)
    # So: max_distance = (100 - threshold) * max_len / 100
    local max_distance=$(( (100 - SIMILARITY_THRESHOLD) * max_len / 100 ))
    local len_diff=$((max_len - min_len))

    if [ $len_diff -gt $max_distance ]; then
        echo "0"
        return
    fi

    # Use agrep for fast approximate matching
    # agrep -N allows N errors (insertions, deletions, substitutions)
    # We check if str1 matches str2 within max_distance errors
    # Using -x for whole-line match, -i for case insensitive could be added

    # Try matching with agrep - need to escape special regex characters
    local escaped_str2
    escaped_str2=$(printf '%s' "$str2" | sed 's/[][\.*^$(){}|+?\\]/\\&/g')

    if printf '%s\n' "$str1" | agrep -"$max_distance" -- "$escaped_str2" >/dev/null 2>&1; then
        # Strings match within threshold - calculate approximate similarity
        # We know distance <= max_distance, so similarity >= threshold
        # For more accuracy, binary search for actual distance
        local dist=0
        while [ $dist -lt $max_distance ]; do
            if printf '%s\n' "$str1" | agrep -"$dist" -- "$escaped_str2" >/dev/null 2>&1; then
                break
            fi
            dist=$((dist + 1))
        done
        local similarity=$((100 - (dist * 100 / max_len)))
        echo "$similarity"
        return
    fi

    echo "0"
}

# Function to get directory modification time (newest file inside)
get_dir_mtime() {
    local dir="$1"
    # Get the most recent modification time of any file in the directory
    find "$dir" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1 || echo "0"
}

# Function to get directory size in bytes
get_dir_size() {
    local dir="$1"
    du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
}

# Function to decide which directory to keep based on strategy
# Returns 0 if dir1 should be kept, 1 if dir2 should be kept
should_keep_first() {
    local dir1="$1"
    local dir2="$2"

    case "$KEEP_STRATEGY" in
        first)
            # Already sorted alphabetically, dir1 comes first
            return 0
            ;;
        newest)
            local mtime1 mtime2
            mtime1=$(get_dir_mtime "$dir1")
            mtime2=$(get_dir_mtime "$dir2")
            if (( $(echo "$mtime2 > $mtime1" | bc -l) )); then
                return 1
            else
                return 0
            fi
            ;;
        largest)
            local size1 size2
            size1=$(get_dir_size "$dir1")
            size2=$(get_dir_size "$dir2")
            if [ "$size2" -gt "$size1" ]; then
                return 1
            else
                return 0
            fi
            ;;
    esac
    return 0
}

# Get all directories (non-recursively) in the scan directory
mapfile -t dirs < <(find "$SCAN_DIR" -maxdepth 1 -type d ! -path "$SCAN_DIR" | sort)

if [ ${#dirs[@]} -eq 0 ]; then
    echo "No subdirectories found in '$SCAN_DIR'"
    exit 0
fi

echo "Found ${#dirs[@]} directories to analyze"
echo "Similarity threshold: ${SIMILARITY_THRESHOLD}%"
echo "Keep strategy: $KEEP_STRATEGY"
if [ "$DRY_RUN" = true ]; then
    echo "Mode: DRY RUN (no directories will be deleted)"
else
    echo "Mode: LIVE (directories will be deleted)"
fi
echo ""

# Array to track directories that should be kept
declare -A keep_dirs
declare -A delete_dirs

# Calculate total comparisons for progress display
total_dirs=${#dirs[@]}
total_comparisons=$((total_dirs * (total_dirs - 1) / 2))
current_comparison=0

echo "Starting pairwise comparison ($total_comparisons total comparisons)..."
echo ""

# Compare all directories pairwise
for ((i=0; i<${#dirs[@]}; i++)); do
    dir1="${dirs[$i]}"
    basename1=$(basename "$dir1")

    # Progress: show which directory we're processing
    printf "\r\033[KProcessing [%d/%d]: %s" "$((i + 1))" "$total_dirs" "$basename1"

    # Skip if already marked for deletion
    if [ -n "${delete_dirs[$dir1]:-}" ]; then
        continue
    fi

    for ((j=i+1; j<${#dirs[@]}; j++)); do
        dir2="${dirs[$j]}"
        basename2=$(basename "$dir2")
        current_comparison=$((current_comparison + 1))

        # Skip if already marked for deletion
        if [ -n "${delete_dirs[$dir2]:-}" ]; then
            continue
        fi

        # Calculate similarity
        similarity=$(calculate_similarity "$basename1" "$basename2")

        if [ "$similarity" -ge "$SIMILARITY_THRESHOLD" ]; then
            # Determine which directory to keep based on strategy
            if should_keep_first "$dir1" "$dir2"; then
                keep_dir="$dir1"
                del_dir="$dir2"
            else
                keep_dir="$dir2"
                del_dir="$dir1"
            fi

            # Clear progress line before printing match
            printf "\r\033[K"
            echo "Found similar directories (${similarity}% similar):"
            echo "  KEEP:   $keep_dir"
            echo "  DELETE: $del_dir"
            echo ""

            delete_dirs[$del_dir]=1
            keep_dirs[$keep_dir]=1
        fi
    done
done

# Clear the progress line
printf "\r\033[K"
echo "Comparison complete."
echo ""

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
