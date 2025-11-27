#!/usr/bin/env python3
import sys
from pathlib import Path
from git_utils import git_add_and_commit

if len(sys.argv) < 2:
    print("Error: todo_name is required")
    print("Usage: just squads todo <todo_name>")
    sys.exit(1)

todo_name = sys.argv[1]

# Create the file path
todo_dir = Path(__file__).parent.parent.parent / "squads" / "todo"
file_name = f"§{todo_name}.md"
file_path = todo_dir / file_name

# Check if file already exists
if file_path.exists():
    print(f"Error: Todo file '{file_name}' already exists")
    sys.exit(1)

# Template content
content = f"""§{todo_name}

## overview

## user journey

## tech spec
"""

# Write the file
file_path.write_text(content)
print(f"Created todo: {file_path}")

# Commit the new file to git
git_add_and_commit(file_path, f"squads::todo {todo_name}")
