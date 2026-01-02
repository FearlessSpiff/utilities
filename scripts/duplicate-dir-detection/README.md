# Remove Similar Duplicate Directories Script

## Overview
This bash script scans a directory for subdirectories with similar names and removes duplicates based on a similarity threshold. **The script only scans immediate subdirectories (non-recursive) - it does not look into nested directories.**

## Usage
```bash
./remove_similar_dirs.sh <directory_to_scan> <similarity_percentage> [--dry-run]
```

### Parameters
1. **directory_to_scan**: The directory containing subdirectories you want to scan
2. **similarity_percentage**: A number between 0-100 representing the minimum similarity threshold
   - 100 = exact match
   - 80-90 = very similar names
   - 70-79 = moderately similar names
   - Below 70 = less similar
3. **--dry-run** (optional): Test mode - shows what would be deleted without actually deleting anything

## Features
- **Non-recursive scanning**: Only analyzes immediate subdirectories in the specified path (does not descend into nested folders)
- Uses Levenshtein distance algorithm to calculate name similarity
- Keeps the first directory found and deletes similar ones
- Dry-run mode for safe testing
- Unattended operation (no manual prompts)
- Provides clear output showing which directories will be kept/deleted

## Examples

### Example 1: Dry-run test (recommended first step)
```bash
./remove_similar_dirs.sh /path/to/projects 80 --dry-run
```

This will show you what would be deleted without actually deleting anything. Always run this first!

### Example 2: Actual deletion with 80% similarity
```bash
./remove_similar_dirs.sh /path/to/projects 80
```

If you have directories like:
- `project_alpha`
- `project_alpha_backup`
- `project_beta`
- `project_beta_v2`

The script will identify:
- `project_alpha_backup` as similar to `project_alpha` (if >80% similar)
- `project_beta_v2` as similar to `project_beta` (if >80% similar)

### Example 3: More lenient matching (70%)
```bash
./remove_similar_dirs.sh /home/user/documents 70 --dry-run
```

This will catch more variations but may also flag directories that are less similar.

### Example 4: Running unattended in scripts
```bash
# Test first
./remove_similar_dirs.sh /data/backups 85 --dry-run

# If satisfied, run for real
./remove_similar_dirs.sh /data/backups 85
```

The script runs without prompts, making it perfect for automation and cron jobs.

## Safety Features
1. **Dry-run mode**: Test with `--dry-run` to see what would be deleted without actually deleting
2. **Unattended operation**: No manual confirmation required - perfect for scripts and automation
3. **Clear output**: Shows exactly which directories will be kept and deleted
4. **Summary**: Displays total count and mode (DRY RUN or LIVE)
5. **Validation**: Checks that directory exists and percentage is valid

## How Similarity is Calculated
The script uses the Levenshtein distance (edit distance) algorithm:
- Measures the minimum number of single-character edits needed to change one string into another
- Converts this to a percentage: `similarity = 100 - (distance * 100 / max_length)`

## Non-Recursive Behavior Example
Given this directory structure:
```
/data/
├── project_alpha/
│   └── subfolder1/
├── project_alpha_backup/
│   └── subfolder2/
└── project_beta/
    └── nested_similar/
```

Running: `./remove_similar_dirs.sh /data 80 --dry-run`

Will only compare:
- `project_alpha`
- `project_alpha_backup` 
- `project_beta`

It will **NOT** compare or touch:
- `subfolder1`
- `subfolder2`
- `nested_similar`

Only the immediate subdirectories of `/data` are analyzed.

## Important Notes
- **Non-recursive**: Only scans direct subdirectories in the given path - nested directories are ignored
- The script keeps the **first** directory encountered and deletes subsequent similar ones
- Directories are processed in sorted order
- No manual confirmation required - runs unattended
- Use with caution - deleted directories cannot be recovered!
- **Always test with --dry-run first!**

## Recommended Workflow
1. **Test first**: Run with `--dry-run` to see what would be deleted
2. **Review output**: Check if the matches make sense
3. **Adjust threshold**: If needed, try different similarity percentages
4. **Execute**: Run without `--dry-run` to perform actual deletion
