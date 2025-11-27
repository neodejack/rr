#!/usr/bin/env python3
import sys
import shutil
from pathlib import Path
from git_utils import git_add, git_commit

if len(sys.argv) < 2:
    print("Error: todo_name is required")
    print("Usage: just squads::done <todo_name>")
    sys.exit(1)

todo_name = sys.argv[1]

# Setup paths
todo_dir = Path(__file__).parent.parent.parent / "squads" / "todo"
done_dir = todo_dir / "done"

# Ensure done directory exists
done_dir.mkdir(exist_ok=True)

# Find matching files with substring match
# Only search for files that start with § in the todo directory (not in subdirectories)
all_files = [f for f in todo_dir.iterdir() if f.is_file() and f.name.startswith("§") and f.name.endswith(".md")]
matched_files = [f for f in all_files if todo_name in f.name]

# Error handling for no matches
if len(matched_files) == 0:
    print(f"Error: No files match '{todo_name}'")
    sys.exit(1)

# Error handling for multiple matches
if len(matched_files) > 1:
    print(f"Error: Multiple files match '{todo_name}':")
    for file in matched_files:
        print(f"  - {file.name}")
    sys.exit(1)

# Move the matched file to done directory
matched_file = matched_files[0]
destination = done_dir / matched_file.name

try:
    shutil.move(str(matched_file), str(destination))
    print(f"Moved {matched_file.name} to done/")

    # Commit the moved file to git
    # Stage both the old location (deletion) and new location (addition)
    git_add(matched_file)  # Stage the deletion
    git_add(destination)   # Stage the addition
    git_commit(f"squads::done {todo_name}")
except Exception as e:
    print(f"Error: Failed to move file: {e}")
    sys.exit(1)
