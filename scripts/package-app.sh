#!/bin/zsh
# Build a self-contained local app bundle. Signing/notarization are separate steps.
set -euo pipefail
cd "${0:A:h:h}"
configuration=${1:-debug}
case "$configuration" in debug|release) ;; *) print -u2 "Usage: $0 [debug|release]"; exit 2 ;; esac
swift build -c "$configuration"
mkdir -p .build/TodoAI.app/Contents/{MacOS,Helpers,Resources/CodexIntegration}
cp ".build/$configuration/TodoAI" .build/TodoAI.app/Contents/MacOS/TodoAI.new
mv -f .build/TodoAI.app/Contents/MacOS/TodoAI.new .build/TodoAI.app/Contents/MacOS/TodoAI
cp ".build/$configuration/todo" .build/TodoAI.app/Contents/Helpers/todo.new
mv -f .build/TodoAI.app/Contents/Helpers/todo.new .build/TodoAI.app/Contents/Helpers/todo
# SwiftPM resolves Bundle.module at the root of the main application bundle.
cp -R ".build/$configuration/TodoAI_TodoCore.bundle" .build/TodoAI.app/
# Copy the complete source skill into bundle-owned resources, including references.
python3 - <<'COPY'
from pathlib import Path
import shutil
root = Path('.build/TodoAI.app/Contents/Resources/CodexIntegration')
staging = root / 'todo-ai.new'
if staging.exists(): shutil.rmtree(staging)
shutil.copytree('Skills/todo-ai', staging)
target = root / 'todo-ai'
if target.exists(): shutil.rmtree(target)
staging.rename(target)
COPY
cat > .build/TodoAI.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TodoAI</string>
<key>CFBundleIdentifier</key><string>local.todo-ai.dev</string>
<key>CFBundleName</key><string>TodoAI</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
<key>CFBundleLocalizations</key><array><string>zh-Hans</string><string>en</string><string>ja</string><string>ko</string></array>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
