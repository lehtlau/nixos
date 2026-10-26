import subprocess
from gi.repository import Gio
from vpn_desktop import launch


def choose(items, prompt):
    result = subprocess.run(['wofi', '--normal-window', '--dmenu', '--prompt', prompt], input='\n'.join(items), text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else ''


apps = {}
for app in Gio.AppInfo.get_all():
    if app.should_show() and isinstance(app, Gio.DesktopAppInfo):
        apps[f'{app.get_display_name()} ({app.get_id()})'] = app
selection = choose(sorted(apps), 'Application')
if selection not in apps:
    raise SystemExit(0)
routes = {'Through home VPN': 'home-vpn-run', 'Through Mullvad (app only)': 'mullvad-apps-run', 'Normally': None}
mode = choose(list(routes), 'Connection')
if mode not in routes:
    raise SystemExit(0)
app = apps[selection]
launch(app.get_filename(), prefix=routes[mode])
