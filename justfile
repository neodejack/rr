mod dev

list:
  @just --list --list-heading $'Cool stuff\n' --list-prefix '■ '
upgrade_rr:
  curl -fsSL https://raw.githubusercontent.com/neodejack/rr/main/upgrade.sh | bash
