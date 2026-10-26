"""Keep Mullvad routing and DNS inside a namespace used only by selected apps."""
import configparser
import ipaddress
import os
from pathlib import Path
import subprocess
import tempfile

def run(*args):
    subprocess.run(args, check=True)


path = Path('/etc/wireguard/mullvad-apps.conf')
if not path.is_file():
    raise SystemExit(f'Install a downloaded Mullvad WireGuard config at {path} (root:root, mode 600)')
if path.stat().st_uid != 0 or path.stat().st_mode & 0o077:
    raise SystemExit(f'{path} must be owned by root and readable only by root (chmod 600)')
config = configparser.ConfigParser(interpolation=None)
config.read(path)
interface = config['Interface']
addresses = [ipaddress.ip_interface(value.strip()) for value in interface['Address'].split(',')]
dns = [str(ipaddress.ip_address(value.strip())) for value in interface.get('DNS', '10.64.0.1').split(',')]
# Strip wg-quick options and hooks; never execute commands from the config.
wireguard = '[Interface]\nPrivateKey = ' + interface['PrivateKey'] + '\n'
for section in config.sections():
    if section == 'Peer':
        wireguard += '[Peer]\n'
        for key in ('PublicKey', 'PresharedKey', 'AllowedIPs', 'Endpoint', 'PersistentKeepalive'):
            if key in config[section]:
                wireguard += f'{key} = {config[section][key]}\n'
if not config.has_section('Peer'):
    raise SystemExit('Mullvad config must contain a Peer section')
resolver = Path('/etc/netns/mullvad-apps')
resolver.mkdir(parents=True, exist_ok=True)
(resolver / 'resolv.conf').write_text(''.join(f'nameserver {value}\n' for value in dns))
run('ip', 'netns', 'add', 'mullvad-apps')
try:
    # The WireGuard socket stays in the host namespace; all app routes stay here.
    run('ip', 'link', 'add', 'mv-apps', 'type', 'wireguard')
    with tempfile.NamedTemporaryFile(mode='w', dir='/run', prefix='mullvad-apps-') as target:
        os.chmod(target.name, 0o600)
        target.write(wireguard)
        target.flush()
        run('wg', 'setconf', 'mv-apps', target.name)
    run('ip', 'link', 'set', 'mv-apps', 'netns', 'mullvad-apps')

    def ns(*args):
        run('ip', '-n', 'mullvad-apps', *args)

    # Decrypted traffic is inside this namespace, outside the host firewall.
    # Fail closed if installing the firewall fails.
    subprocess.run(['ip', 'netns', 'exec', 'mullvad-apps', 'nft', '-f', '-'],
                   input='''table inet mullvad_apps {
  chain input {
    type filter hook input priority 0; policy drop;
    iifname "lo" accept
    ct state invalid drop
    ct state established,related accept
    meta l4proto ipv6-icmp accept
    ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
}
''', text=True, check=True)
    ns('link', 'set', 'lo', 'up')
    ns('link', 'set', 'mv-apps', 'mtu', interface.get('MTU', '1380'))
    for address in addresses:
        ns('address', 'add', str(address), 'dev', 'mv-apps')
    ns('link', 'set', 'mv-apps', 'up')
    for version in sorted({address.version for address in addresses}):
        ns(f'-{version}', 'route', 'add', 'default', 'dev', 'mv-apps')
except BaseException:
    subprocess.run(['ip', '-n', 'mullvad-apps', 'link', 'del', 'mv-apps'], check=False)
    subprocess.run(['ip', 'link', 'del', 'mv-apps'], check=False)
    subprocess.run(['ip', 'netns', 'del', 'mullvad-apps'], check=False)
    raise
