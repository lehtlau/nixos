import configparser
import glob
import os
from pathlib import Path
import subprocess
import tempfile


def run(*args):
    subprocess.run(args, check=True)


profile = None
for path in glob.glob('/etc/NetworkManager/system-connections/*') + glob.glob('/run/NetworkManager/system-connections/*'):
    candidate = configparser.ConfigParser(interpolation=None)
    candidate.read(path)
    if candidate.get('connection', 'id', fallback='') == 'home':
        profile = candidate
        break
if profile is None:
    raise SystemExit('No NetworkManager keyfile for home found')

key = profile.get('wireguard', 'private-key', fallback='')
if not key:
    raise SystemExit('The home profile must store its WireGuard private key in its root-owned keyfile')
lines = ['[Interface]', 'PrivateKey = ' + key]
peers = [section for section in profile.sections() if section.startswith('wireguard-peer.')]
if len(peers) != 1:
    raise SystemExit('Home VPN app routing requires exactly one WireGuard peer')
section = peers[0]
# The NetworkManager profile can use private-only split routes. This namespace
# sends all app traffic through home, so its peer must accept every destination.
# This changes only the temporary WireGuard config, not the saved NM profile.
lines += ['[Peer]', 'PublicKey = ' + section.split('.', 1)[1],
          'AllowedIPs = 0.0.0.0/0, ::/0']
for source, target in [('endpoint', 'Endpoint'), ('preshared-key', 'PresharedKey'), ('persistent-keepalive', 'PersistentKeepalive')]:
    value = profile.get(section, source, fallback='').strip(';')
    if value:
        lines.append(target + ' = ' + value.replace(';', ','))

# Refuse to silently leave a second, whole-system tunnel active.
active = subprocess.check_output(['nmcli', '-g', 'NAME', 'connection', 'show', '--active'], text=True).splitlines()
if 'home' in active:
    raise SystemExit('Disconnect the NetworkManager home connection before launching through Home VPN')
# ip netns exec needs a real resolver file before launching applications.
# The host's 127.0.0.53 stub is unreachable from the isolated loopback.
resolver = Path('/etc/netns/home-vpn')
resolver.mkdir(parents=True, exist_ok=True)
(resolver / 'resolv.conf').write_text(f"nameserver {os.environ['HOME_VPN_DNS']}\n")
run('ip', 'netns', 'add', 'home-vpn')
try:
    run('ip', 'link', 'add', 'home-apps', 'type', 'wireguard')
    with tempfile.NamedTemporaryFile(mode='w', dir='/run', prefix='home-vpn-') as config:
        os.chmod(config.name, 0o600)
        config.write('\n'.join(lines) + '\n')
        config.flush()
        run('wg', 'setconf', 'home-apps', config.name)
    run('ip', 'link', 'set', 'home-apps', 'netns', 'home-vpn')
    def ns(*args):
        run('ip', '-n', 'home-vpn', *args)
    # The host firewall does not filter plaintext inside this namespace.
    # Install this before bringing up either interface.
    subprocess.run(['ip', 'netns', 'exec', 'home-vpn', 'nft', '-f', '-'],
                   input='''table inet home_vpn {
  chain input {
    type filter hook input priority 0; policy drop;
    iifname "lo" accept
    ct state invalid drop
    ct state established,related accept
    # Orca remote connections arrive through the home WireGuard interface.
    iifname "home-apps" tcp dport 6768 accept
    meta l4proto ipv6-icmp accept
    ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
}
''', text=True, check=True)
    ns('link', 'set', 'lo', 'up')
    ns('link', 'set', 'home-apps', 'mtu', profile.get('wireguard', 'mtu', fallback='1420'))
    for family, section in [('-4', 'ipv4'), ('-6', 'ipv6')]:
        for option, value in profile.items(section):
            if option.startswith('address') and option[7:].isdigit():
                ns(family, 'address', 'add', value.split(',')[0], 'dev', 'home-apps')
    ns('link', 'set', 'home-apps', 'up')
    ns('-4', 'route', 'add', 'default', 'dev', 'home-apps')
    ns('-6', 'route', 'add', 'default', 'dev', 'home-apps')
except BaseException:
    subprocess.run(['ip', '-n', 'home-vpn', 'link', 'del', 'home-apps'])
    subprocess.run(['ip', 'link', 'del', 'home-apps'])
    subprocess.run(['ip', 'netns', 'del', 'home-vpn'])
    raise
