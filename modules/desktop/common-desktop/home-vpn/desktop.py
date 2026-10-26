"""Launch desktop applications through the selected connection."""
import tempfile

from gi.repository import Gio, GLib


def launch(path, prefix=None):
    app = Gio.DesktopAppInfo.new_from_filename(path)
    if not app:
        raise ValueError('Could not load desktop entry')
    desktop = GLib.KeyFile()
    desktop.load_from_file(path, GLib.KeyFileFlags.NONE)
    command = desktop.get_string('Desktop Entry', 'Exec')
    desktop.set_string('Desktop Entry', 'Exec', (prefix + ' ' if prefix else '') + command)
    desktop.set_boolean('Desktop Entry', 'DBusActivatable', False)
    context = Gio.AppLaunchContext()
    if app.get_boolean('PrefersNonDefaultGPU'):
        context.setenv('DRI_PRIME', '1')
    with tempfile.NamedTemporaryFile(mode='w', suffix='.desktop') as target:
        target.write(desktop.to_data()[0])
        target.flush()
        Gio.DesktopAppInfo.new_from_filename(target.name).launch([], context)
