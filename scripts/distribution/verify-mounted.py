"""Check a mounted trial DMG before handing it to a user (read-only)."""
from pathlib import Path
import os
import plistlib
import subprocess
import sys
from ds_store import DSStore

volume = Path(sys.argv[1])
app = volume / 'Next One.app'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'local.todo-ai.release'
assert info['CFBundleIconFile'] == 'TodoAI.icns'
assert (app / 'Contents/Resources/TodoAI.icns').read_bytes()[:4] == b'icns'
assert os.readlink(volume / 'Applications') == '/Applications'
for lang in ['zh-Hans', 'en', 'ja', 'ko']:
    assert (app / 'TodoAI_TodoCore.bundle' / f'{lang}.lproj/Localizable.strings').is_file(), lang
for name in ['SKILL.md', 'references/cli.md']:
    assert (app / 'Contents/Resources/CodexIntegration/next-one' / name).is_file(), name
assert not any(p.suffix in {'.sqlite', '.db', '.env'} for p in app.rglob('*'))
with DSStore.open(str(volume / '.DS_Store'), 'r') as store:
    assert store['.']['icvp']['backgroundType'] == 2
    assert store['Next One.app']['Iloc'][0] < store['Applications']['Iloc'][0]
assert any(volume.glob('.background.*'))
help_text = subprocess.check_output([str(app / 'Contents/Helpers/next-one'), '--help'], text=True)
assert 'Data: NEXT_ONE_HOME overrides Application Support/Next-One-Release.' in help_text
print('PASS: app icon, Applications link, four languages, Skill, layout, background, CLI')
