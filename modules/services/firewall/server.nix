{myOptions, ...}: {
  networking.nftables.enable = true;

  # Let the kernel forward packets between interfaces at all
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # NAT/masquerade podman traffic going out the LAN interface
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    internalInterfaces = ["podman0"];
    # 10.42.42.0/24 / fdcc:ad94:bacf:61a3::/64 is the dedicated "wg" podman
    # network that the wg-easy container runs on (see wireguard-easy.nix).
    # wg-easy masquerades its own VPN peer subnet (10.8.0.0/24 /
    # fdcc:ad94:bacf:61a4::/64) behind this address itself, so this is the
    # subnet that actually needs NAT'ing out to the internet.
    internalIPs = ["10.42.42.0/24"];
    internalIPv6s = ["fdcc:ad94:bacf:61a3::/64"];
    externalInterface = "eno1";
  };

  networking.firewall = {
    enable = true;
    filterForward = true;
    allowedTCPPorts = [
      25565 # Minecraft Java server
    ];
    allowedUDPPorts = [
      51820 # WireGuard VPN traffic
    ];
    # TCP 22 (host SSH) is opened separately by modules/services/ssh.nix.

    extraInputRules = ''
      # LAN TCP ports:
      # 53: DNS; 80/443: Caddy; 51821: wg-easy admin
      # 139: SMB over NetBIOS; 445: direct SMB file sharing
      # 2222: Forgejo Git SSH; 2283: Immich; 3000: Forgejo web UI
      # 5357: WSD discovery HTTP endpoint; 8082: Homepage dashboard
      # 8090: Minecraft start/stop panel; 8096: Jellyfin HTTP
      iifname "eno1" ip saddr 192.168.50.0/24 tcp dport { 53, 80, 443, 139, 445, 2222, 2283, 3000, 5357, 8082, 8090, 8096, 51821 } accept
      # LAN UDP ports:
      # 137: NetBIOS name service; 138: NetBIOS datagrams
      # 3702: WSD discovery; 7359: Jellyfin discovery
      iifname "eno1" ip saddr 192.168.50.0/24 udp dport { 53, 137, 138, 3702, 7359 } accept
      # wg-easy masquerades VPN clients behind its container address.
      # Trust these clients for all services on the server's LAN address.
      ip saddr 10.42.42.42 ip daddr ${myOptions.server.lanIp} accept
    '';

    # Container egress (including VPN peers masqueraded by wg-easy).
    # Reply traffic and published ports are handled by the NixOS firewall.
    extraForwardRules = ''
      iifname "podman0" oifname "eno1" ip saddr 10.88.0.0/16 accept
      oifname "eno1" ip saddr 10.42.42.0/24 accept
      oifname "eno1" ip6 saddr fdcc:ad94:bacf:61a3::/64 accept
    '';
  };

  # Run before both NixOS and Podman's forward chains. NixOS accepts DNAT
  # unconditionally, so its allowedTCPPorts alone cannot protect admin ports.
  # Allow LAN/VPN administration, then block other forwarded access, including
  # direct routed access to these container ports.
  networking.nftables.tables.container-admin-guard = {
    family = "inet";
    content = ''
      chain forward {
        type filter hook forward priority -10; policy accept;
        # 51821: wg-easy admin.
        # Accept LAN and masqueraded VPN clients before blocking other sources.
        iifname "eno1" ip saddr 192.168.50.0/24 ip daddr { 10.88.0.0/16, 10.42.42.0/24 } tcp dport 51821 accept
        ip saddr 10.42.42.42 ip daddr { 10.88.0.0/16, 10.42.42.0/24 } tcp dport 51821 accept
        ip6 saddr fdcc:ad94:bacf:61a3::2a ip6 daddr fdcc:ad94:bacf:61a3::/64 tcp dport 51821 accept
        ip daddr { 10.88.0.0/16, 10.42.42.0/24 } tcp dport 51821 drop
        ip6 daddr fdcc:ad94:bacf:61a3::/64 tcp dport 51821 drop
      }
    '';
  };
}
