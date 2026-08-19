#!/bin/bash
# Install finder-typeban as a launchd LaunchAgent (auto-start at login).
set -e
cd "$(dirname "$0")"
DIR="$(pwd)"

if [ ! -x "$DIR/finder-typeban" ]; then
    echo "Binary not found. Run ./build.sh first." >&2
    exit 1
fi

PLIST="$HOME/Library/LaunchAgents/com.local.finder-typeban.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.finder-typeban</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DIR/finder-typeban</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl bootout gui/$(id -u)/com.local.finder-typeban 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"

echo "Installed. Grant permissions now:"
echo "  System Settings > Privacy & Security > Input Monitoring -> add $DIR/finder-typeban"
echo "  System Settings > Privacy & Security > Accessibility    -> add $DIR/finder-typeban"
