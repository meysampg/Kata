#!/bin/zsh
# Reinstall Kata on the owner's iPhone (thin wrapper around install.sh).
exec "$(dirname "$0")/install.sh" "${1:-00008030-000511D93CC0202E}"
