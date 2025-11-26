list:
  @just --list squads --list-heading $'Squads related stuff\n' --list-prefix '■ '

init:
  @hacks/squads/init.py

todo todo_name:
  @hacks/squads/todo.py "{{todo_name}}"

upgrade:
  curl -fsSL https://raw.githubusercontent.com/neodejack/squads/main/upgrade.sh | bash
