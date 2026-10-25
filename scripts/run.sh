#!/bin/zsh
# Local development wrapper only: no installation, signing, notarization or system settings.
set -euo pipefail
cd "${0:A:h:h}"
swift build
mkdir -p .build/TodoAI.app/Contents/MacOS
# Replace the executable inode instead of overwriting a previously launched Mach-O.
cp .build/debug/TodoAI .build/TodoAI.app/Contents/MacOS/TodoAI.new
mv -f .build/TodoAI.app/Contents/MacOS/TodoAI.new .build/TodoAI.app/Contents/MacOS/TodoAI
cat > .build/TodoAI.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TodoAI</string>
<key>CFBundleIdentifier</key><string>local.todo-ai.dev</string>
<key>CFBundleName</key><string>TodoAI</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
exec .build/TodoAI.app/Contents/MacOS/TodoAI
