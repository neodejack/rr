#!/usr/bin/env python3
import subprocess
from pathlib import Path
from typing import Optional


def git_add(file_path: Path) -> bool:
    """
    Add a file to git staging area.

    Args:
        file_path: Path to the file to add

    Returns:
        True if successful, False otherwise
    """
    try:
        result = subprocess.run(
            ["git", "add", str(file_path)],
            capture_output=True,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Warning: Failed to git add {file_path}: {e.stderr}")
        return False
    except Exception as e:
        print(f"Warning: Unexpected error during git add: {e}")
        return False


def git_commit(message: str, allow_empty: bool = False) -> bool:
    """
    Create a git commit with the given message.

    Args:
        message: Commit message
        allow_empty: Whether to allow empty commits

    Returns:
        True if successful, False otherwise
    """
    try:
        cmd = ["git", "commit", "-m", message]
        if allow_empty:
            cmd.append("--allow-empty")

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        # Check if it's because there's nothing to commit
        if "nothing to commit" in e.stdout or "nothing to commit" in e.stderr:
            print("Warning: Nothing to commit")
        else:
            print(f"Warning: Failed to git commit: {e.stderr}")
        return False
    except Exception as e:
        print(f"Warning: Unexpected error during git commit: {e}")
        return False


def git_add_and_commit(file_path: Path, message: str) -> bool:
    """
    Add a file and commit it in one operation.

    Args:
        file_path: Path to the file to add
        message: Commit message

    Returns:
        True if both operations successful, False otherwise
    """
    if git_add(file_path):
        return git_commit(message)
    return False
