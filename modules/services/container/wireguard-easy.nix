{
  pkgs,
  myOptions,
  ...
}: {
  systemd.services.wg-easy = {
    requires = ["podman-wg-network-create.service"];
    after = ["podman-wg-network-create.service"];
  };

  systemd.services.podman-wg-network-create = {
    description = "Create wg Podman network";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Preserve an existing network, including any attached containers.
      # Exit 1 means absent; operational errors must fail this unit.
      if ${pkgs.podman}/bin/podman network exists wg; then
        exit 0
      else
        status=$?
        if [ "$status" -ne 1 ]; then
          exit "$status"
        fi
      fi

      ${pkgs.podman}/bin/podman network create \
        --driver bridge \
        --ipv6 \
        --subnet 10.42.42.0/24 \
        --subnet fdcc:ad94:bacf:61a3::/64 \
        wg
    '';
  };
  virtualisation.oci-containers.containers.wg-easy = {
    serviceName = "wg-easy";
    image = "ghcr.io/wg-easy/wg-easy:15.3";
    autoStart = true;

    volumes = [
      "etc-wireguard:/etc/wireguard"
    ];

    environment = {
      # Allow HTTP administration on the LAN/VPN; access is restricted by the firewall.
      INSECURE = "true";

      # Unattended setup, only applied on first start (empty database).
      # INIT_USERNAME / INIT_PASSWORD come from the environment file below.
      INIT_ENABLED = "true";
      # LAN-only bootstrap default, not an internet endpoint. For remote access,
      # set the public hostname in the admin UI and update/reimport clients.
      # INIT_* does not change an already initialized persistent database.
      INIT_HOST = myOptions.server.lanIp;
      INIT_PORT = "51820";
      # Existing clients need DNS updated in the UI and profiles reimported.
      INIT_DNS = myOptions.server.lanIp;
      INIT_IPV4_CIDR = "10.8.0.0/24";
      INIT_IPV6_CIDR = "fdcc:ad94:bacf:61a4::/64";
    };

    # Kept out of the nix store. Create it on the host:
    #   install -d -m 700 /etc/wg-easy
    #   install -m 600 /dev/null /etc/wg-easy/wg-easy.env
    #   printf 'INIT_USERNAME=admin\nINIT_PASSWORD=<at least 12 chars>\n' > /etc/wg-easy/wg-easy.env
    environmentFiles = ["/etc/wg-easy/wg-easy.env"];

    networks = ["wg"];

    ports = [
      "51820:51820/udp"
      "51821:51821/tcp" # LAN/VPN administration; access restricted by the firewall.
    ];

    # The image switches iptables to the legacy backend, but the host runs nftables
    # (networking.nftables blacklists ip_tables), so switch it back to iptables-nft.
    entrypoint = "/bin/sh";
    cmd = [
      "-c"
      ''
        set -e
        update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-nft 20 --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-nft-restore --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-nft-save
        update-alternatives --install /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-nft 20 --slave /usr/sbin/ip6tables-restore ip6tables-restore /usr/sbin/ip6tables-nft-restore --slave /usr/sbin/ip6tables-save ip6tables-save /usr/sbin/ip6tables-nft-save
        exec /usr/local/bin/docker-entrypoint.sh /usr/bin/dumb-init node server/index.mjs
      ''
    ];

    extraOptions = [
      "--ip=10.42.42.42"
      "--ip6=fdcc:ad94:bacf:61a3::2a"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"

      "--sysctl=net.ipv4.ip_forward=1"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
      "--sysctl=net.ipv6.conf.all.disable_ipv6=0"
      "--sysctl=net.ipv6.conf.all.forwarding=1"
      "--sysctl=net.ipv6.conf.default.forwarding=1"
    ];
  };
  boot.kernelModules = [
    "wireguard"
    "nf_tables"
    "nft_masq"
    "nft_chain_nat"
    "nft_compat" # xtables matches used by iptables-nft
    "xt_MASQUERADE"
    "nf_nat"
    "nf_conntrack"
    "nf_defrag_ipv4"
    "xt_conntrack"
    "xt_addrtype"
    "xt_mark"
  ];
}
