#!/bin/zsh
# Local trial DMG; no Developer ID signing, notarization, or installation.
set -euo pipefail
cd "${0:A:h:h}"
output_dir="$PWD/.local/releases"
mkdir -p "$output_dir" .build
staging=$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
./scripts/package-app.sh release "$staging/TodoAI.app"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 0.1.0' "$staging/TodoAI.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 1' "$staging/TodoAI.app/Contents/Info.plist"
ln -s /Applications "$staging/Applications"
cat > "$staging/Install.txt" <<'INSTALL'
Todo-AI 0.1.0 — Local trial / 本机试装版

1. Quit any running Todo-AI development copy using its menu (Quit).
2. Drag TodoAI.app to Applications.
3. Open TodoAI from Applications. Click its floating button to show the list.
4. Eject this disk image after installation.

先通过菜单退出正在运行的 Todo-AI 开发版，再将 TodoAI.app 拖入 Applications。
从“应用程序”打开 TodoAI，点击悬浮球展开清单；安装后可推出此磁盘映像。

Your existing local tasks are reused. Installation does not erase them.
Do not run the development copy and installed copy against the same data at once.
Default data: ~/Library/Application Support/Todo-AI
Settings → Codex integration contains the setup instructions to copy to Codex.

沿用本机现有待办，安装不清空数据。开发版与安装版不要同时读写同一数据目录。
接入 Coding Agent：设置 → Codex 接入，复制指令到本机 Codex 对话并发送。

Built for the architecture in this DMG's filename; macOS 14+.
This trial is not Developer ID signed or notarized. It is not a verified public release.
未进行 Developer ID 签名或 Apple 公证，仅供本机试装；不代表已完成公开发行验证。
INSTALL
architecture=$(uname -m)
revision=$(git rev-parse --short HEAD)
image="$output_dir/Todo-AI-0.1.0-local-${architecture}-${revision}.dmg"
if [[ -e "$image" ]]; then
    print -u2 "Output already exists: $image"
    exit 1
fi
hdiutil create -volname 'Todo-AI Install' -srcfolder "$staging" -format UDZO "$image"
hdiutil verify "$image"
shasum -a 256 "$image" > "$image.sha256"
print "DMG: $image"
