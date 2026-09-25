#!/usr/bin/env bash
# Double-click this on a Mac to set up and open Where.
# (Mac opens .command files in Terminal; it runs start-where.sh.)
cd "$(dirname "$0")" || exit 1
bash ./start-where.sh "$@"
echo
read -r -p "Press Return to close this window. " _
