#!/bin/bash
set -e

APP_NAME="TrinTasks"
SCHEME="TrinTasks"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/${APP_NAME}.dmg"

echo "Archiving..."
xcodebuild archive \
  -project "TrinTasksApp/${APP_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}"

echo "Exporting..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist scripts/ExportOptions.plist

echo "Creating DMG..."
create-dmg \
  --volname "${APP_NAME}" \
  --window-size 500 320 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 120 160 \
  --app-drop-link 380 160 \
  "${DMG_PATH}" \
  "${EXPORT_PATH}/${APP_NAME}.app"

echo "Done: ${DMG_PATH}"
