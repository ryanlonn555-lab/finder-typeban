#!/bin/bash
# Stop and remove the finder-guard LaunchAgent.
set -e
launchctl bootout gui/$(id -u)/com.local.finder-guard 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.local.finder-guard.plist"
echo "Uninstalled. You can delete this directory (the guard no longer runs)."
