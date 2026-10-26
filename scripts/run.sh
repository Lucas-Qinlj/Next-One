#!/bin/zsh
# Local development startup, without installing globally or changing system settings.
set -euo pipefail
cd "${0:A:h:h}"
./scripts/package-app.sh debug
exec ".build/Next One.app/Contents/MacOS/TodoAI"
