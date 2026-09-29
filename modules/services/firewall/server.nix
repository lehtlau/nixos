_: {
  networking.nftables.enable = true;

  # Let the kernel forward packets between interfaces at all
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # NAT/masquerade podman traffic going out the LAN interface
  networking.nat = {
    enable = true;
    internalInterfaces = ["podman0"];
    externalInterface = "eth0"; # <-- replace with your actual LAN interface name
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [80 443 25565];
    allowedUDPPorts = [51820 80 443];

    extraInputRules = ''
      ip saddr 192.168.50.142 accept
      ip saddr 192.168.50.0/24 accept
      ip saddr 10.88.0.0/16 ip daddr 192.168.50.0/24 accept
    '';

    extraForwardRules = ''
      ip saddr 10.88.0.0/16 ip daddr 192.168.50.0/24 accept
      ip saddr 192.168.50.0/24 ip daddr 10.88.0.0/16 accept
    '';
  };
}
