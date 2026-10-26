#!/bin/zsh
# Developer ID signed local DMG; notarization and installation are separate.
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
./scripts/package-app.sh release "$staging/Next One.app"
identity=${NEXT_ONE_SIGNING_IDENTITY:-"Developer ID Application: LIJIAN QIN (5C58V84WF7)"}
[[ "$identity" == "Developer ID Application:"* ]] || { print -u2 "Developer ID Application identity required"; exit 1; }
codesign --force --sign "$identity" --options runtime --timestamp "$staging/Next One.app/Contents/Helpers/next-one"
codesign --force --sign "$identity" --options runtime --timestamp "$staging/Next One.app"
codesign --verify --deep --strict --verbose=2 "$staging/Next One.app"
architecture=$(uname -m)
revision=$(git rev-parse --short HEAD)
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$staging/Next One.app/Contents/Info.plist")
image="$output_dir/Next-One-${version}-local-isolated-${architecture}-${revision}.dmg"
if [[ -e "$image" ]]; then
    print -u2 "Output already exists: $image"
    exit 1
fi
"$dmg_python" -m dmgbuild -s scripts/distribution/dmg-settings.py -D "app=$staging/Next One.app" "Next One Installer" "$image"
codesign --force --sign "$identity" --timestamp "$image"
codesign --verify --strict --verbose=2 "$image"
hdiutil verify "$image"
shasum -a 256 "$image" > "$image.sha256"
print "DMG: $image"
