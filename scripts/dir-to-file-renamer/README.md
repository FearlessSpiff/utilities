# Directory to File Renamer

A bash script that automatically renames single files in subdirectories to match their parent directory name, then moves them up and removes the empty directory.

## Use Case

This is useful when you have directories containing a single file, and you want to flatten the structure while preserving the directory name as the filename.

## Features

- Scans all subdirectories in a specified directory
- Identifies directories with exactly one file
- Renames the file to match the directory name (preserving the extension)
- Moves the renamed file to the parent directory
- Deletes the now-empty subdirectory
- **Dry-run mode** to preview changes without making them
- Color-coded output for easy reading
- Handles edge cases:
  - Files without extensions
  - Name conflicts (skips to prevent data loss)
  - Empty directories
  - Multiple files in a directory

## Usage

```bash
# Dry run to see what would happen
./rename-single-file-dirs.sh /path/to/directory --dry-run

# Actually perform the operations
./rename-single-file-dirs.sh /path/to/directory
```

## Example

**Before:**
```
/target/
├─ SomeVideo/
│  └─ episode1.mp4
├─ MyDocument/
│  └─ report.pdf
├─ MultipleFiles/
│  ├─ file1.txt
│  └─ file2.txt
└─ EmptyDir/
```

**After running:**
```bash
./rename-single-file-dirs.sh /target/
```

**Result:**
```
/target/
├─ SomeVideo.mp4
├─ MyDocument.pdf
├─ MultipleFiles/
│  ├─ file1.txt
│  └─ file2.txt
└─ EmptyDir/
```

Note: `MultipleFiles/` and `EmptyDir/` are skipped because they don't contain exactly one file.

## Output Example

```
Scanning directory: /target
DRY RUN MODE - No changes will be made

✓ PROCESS: SomeVideo/
  File: episode1.mp4
  Will rename to: SomeVideo.mp4
  Will move to: /target
  Will delete directory: /target/SomeVideo

✓ PROCESS: MyDocument/
  File: report.pdf
  Will rename to: MyDocument.pdf
  Will move to: /target
  Will delete directory: /target/MyDocument

⊘ SKIP: MultipleFiles/ (2 files)

⊘ SKIP: EmptyDir/ (empty directory)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:
  Processed: 2
  Skipped: 2
  No changes made (dry-run mode)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Safety Features

- **Dry-run mode**: Always test with `--dry-run` first to see what will happen
- **Conflict detection**: Won't overwrite existing files with the same name
- **Single file check**: Only processes directories with exactly one file
- **Error handling**: Script stops on errors (`set -e`)

## Requirements

- Bash shell
- Standard Unix utilities (`find`, `mv`, `rmdir`)
