#!/bin/zsh
cd "$(dirname "$0")"
if [[ ! -x "Noodle.app/Contents/MacOS/NoodlePet" ]]; then
  zsh build-app.sh
fi
open "Noodle.app"
