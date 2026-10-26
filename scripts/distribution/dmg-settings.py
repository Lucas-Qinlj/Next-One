# dmgbuild configuration: writes Finder layout without automating Finder.
from pathlib import Path

app = Path(defines['app'])
assets = Path('Resources/Distribution').resolve()
format = 'UDZO'
filesystem = 'HFS+'
files = [str(app)]
symlinks = {'Applications': '/Applications'}
icon = str(assets / 'TodoAI.icns')
background = str(assets / 'installer-background.png')
window_rect = ((220, 160), (720, 480))
icon_locations = {app.name: (180, 220), 'Applications': (540, 220)}
icon_size = 116
text_size = 15
default_view = 'icon-view'
arrange_by = None
grid_spacing = 80
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
# FinderInfo on a signed app invalidates strict resource verification.
hide_extensions = []
