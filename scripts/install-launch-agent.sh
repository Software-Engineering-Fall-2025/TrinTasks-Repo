#!/bin/bash
PLIST="com.trintasks.app.plist"
DEST="$HOME/Library/LaunchAgents/${PLIST}"
cp "$(dirname "$0")/${PLIST}" "${DEST}"
launchctl load "${DEST}"
echo "TrinTasks will now launch at login."
