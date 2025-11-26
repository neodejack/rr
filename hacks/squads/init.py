#!/usr/bin/env python3
from pathlib import Path

# Create directories
Path("./squads").mkdir(parents=True, exist_ok=True)
Path("./squads/todo").mkdir(parents=True, exist_ok=True)
Path("./squads/todo/backlogs").mkdir(parents=True, exist_ok=True)
Path("./squads/todo/done").mkdir(parents=True, exist_ok=True)

# Create files
Path("./squads/next.md").touch()

# Create endgame.md with content
Path("./squads/endgame.md").touch()
next_md_content = """_who are using this project?_

_what are the users trying to achieve with this project?_

_how does this project help them better with achieving their goal compared to other similar projects?_
"""

Path("./squads/endgame.md").write_text(next_md_content)
