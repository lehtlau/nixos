"""Choose one VPN indicator: Mullvad, active Home, or disconnected."""
import html
import json
import subprocess
import sys


def output(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=2)
        return result.stdout if result.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def main():
    home_devices = {
        line.split(':', 1)[1]
        for line in output('nmcli', '-t', '-f', 'NAME,DEVICE', 'connection', 'show', '--active').splitlines()
        if line.startswith('home:')
    }
    mullvad = None
    if '--mullvad' in sys.argv:
        try:
            mullvad = json.loads(output('waybar-mullvad'))
        except ValueError:
            mullvad = {
                'text': '🔓 ?', 'class': 'unavailable',
                'tooltip': 'Mullvad status is unavailable',
            }

    # Reuse Mullvad's status, including transitional and blocked states. Home
    # replaces its disconnected indicator when the private-network tunnel is up.
    if mullvad and (mullvad.get('class') == 'connected' or not home_devices):
        result = mullvad
    elif home_devices:
        result = {
            'text': '󰋜', 'class': 'home',
            'tooltip': html.escape(f'Home VPN: active via {", ".join(sorted(home_devices))}'),
        }
    else:
        result = {'text': '', 'class': [], 'tooltip': ''}
    print(json.dumps(result))


if __name__ == '__main__':
    main()
