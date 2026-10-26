#!/bin/zsh
# Build a self-contained local app bundle. Signing/notarization are separate steps.
set -euo pipefail
cd "${0:A:h:h}"
configuration=${1:-debug}
case "$configuration" in debug|release) ;; *) print -u2 "Usage: $0 [debug|release] [output.app]"; exit 2 ;; esac
app_path=${2:-.build/TodoAI.app}
app_path=${app_path:A}
swift build -c "$configuration"
mkdir -p "$app_path"/Contents/{MacOS,Helpers,Resources/CodexIntegration}
cp ".build/$configuration/TodoAI" "$app_path"/Contents/MacOS/TodoAI.new
mv -f "$app_path"/Contents/MacOS/TodoAI.new "$app_path"/Contents/MacOS/TodoAI
cp ".build/$configuration/todo" "$app_path"/Contents/Helpers/todo.new
mv -f "$app_path"/Contents/Helpers/todo.new "$app_path"/Contents/Helpers/todo
cp Resources/Distribution/TodoAI.icns "$app_path"/Contents/Resources/TodoAI.icns
# SwiftPM resolves Bundle.module at the root of the main application bundle.
ditto ".build/$configuration/TodoAI_TodoCore.bundle" "$app_path"/TodoAI_TodoCore.bundle
# Copy the complete source skill into bundle-owned resources, including references.
python3 - "$app_path" <<'COPY'
from pathlib import Path
import shutil
import sys
root = Path(sys.argv[1]) / 'Contents/Resources/CodexIntegration'
staging = root / 'todo-ai.new'
if staging.exists(): shutil.rmtree(staging)
shutil.copytree('Skills/todo-ai', staging)
target = root / 'todo-ai'
if target.exists(): shutil.rmtree(target)
staging.rename(target)
COPY
cat > "$app_path"/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TodoAI</string>
<key>CFBundleIdentifier</key><string>local.todo-ai.dev</string>
<key>CFBundleName</key><string>TodoAI</string>
<key>CFBundleDisplayName</key><string>Todo-AI</string>
<key>CFBundleIconFile</key><string>TodoAI.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
<key>CFBundleLocalizations</key><array><string>zh-Hans</string><string>en</string><string>ja</string><string>ko</string></array>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST

# Distinct application identities; storage selection lives in the shared compiled core.
if [[ "$configuration" == release ]]; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.todo-ai.release' "$app_path"/Contents/Info.plist
fi
