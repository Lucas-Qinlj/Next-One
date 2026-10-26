#!/bin/zsh
# Local trial DMG; no Developer ID signing, notarization, or installation.
set -euo pipefail
cd "${0:A:h:h}"
dmg_python=${TODO_AI_DMG_PYTHON:-"$PWD/.local/dmg-tools/venv/bin/python"}
if [[ ! -x "$dmg_python" ]]; then
    print -u2 "DMG build tools missing. See docs/distribution/local-install.md."
    exit 1
fi
"$dmg_python" -c 'import importlib.metadata; assert importlib.metadata.version("dmgbuild") == "1.6.7", "Expected dmgbuild 1.6.7"'
output_dir="$PWD/.local/releases"
mkdir -p "$output_dir" .build
staging=$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
./scripts/package-app.sh release "$staging/TodoAI.app"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 0.1.0' "$staging/TodoAI.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 4' "$staging/TodoAI.app/Contents/Info.plist"
architecture=$(uname -m)
revision=$(git rev-parse --short HEAD)
image="$output_dir/Todo-AI-0.1.0-local-managed-skill-${architecture}-${revision}.dmg"
if [[ -e "$image" ]]; then
    print -u2 "Output already exists: $image"
    exit 1
fi
"$dmg_python" -m dmgbuild -s scripts/distribution/dmg-settings.py -D "app=$staging/TodoAI.app" "Todo-AI Installer" "$image"
hdiutil verify "$image"
shasum -a 256 "$image" > "$image.sha256"
print "DMG: $image"
