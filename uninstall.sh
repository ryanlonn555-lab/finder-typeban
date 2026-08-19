#!/bin/bash
# Stop and remove the finder-typeban LaunchAgent.
set -e
launchctl bootout gui/$(id -u)/com.local.finder-typeban 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.local.finder-typeban.plist"
echo "Uninstalled. You can delete this directory (the guard no longer runs)."
