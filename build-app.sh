#!/bin/zsh
set -e

swift build -c release
mkdir -p "Noodle.app/Contents/MacOS"
mkdir -p "Noodle.app/Contents/Resources"
cp "AppBundle/Contents/Info.plist" "Noodle.app/Contents/Info.plist"
cp ".build/arm64-apple-macosx/release/NoodlePet" "Noodle.app/Contents/MacOS/NoodlePet"
cp "AppBundle/Contents/Resources/Noodle.png" "Noodle.app/Contents/Resources/Noodle.png"
cp "AppBundle/Contents/Resources/NoodleWalkA.png" "Noodle.app/Contents/Resources/NoodleWalkA.png"
cp "AppBundle/Contents/Resources/NoodleWalkB.png" "Noodle.app/Contents/Resources/NoodleWalkB.png"
cp "AppBundle/Contents/Resources/DanceBreak.m4a" "Noodle.app/Contents/Resources/DanceBreak.m4a"
chmod +x "Noodle.app/Contents/MacOS/NoodlePet"
echo "Built Noodle.app"
