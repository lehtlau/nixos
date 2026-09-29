# unfinessed
{pkgs, ...}: {
  systemd.services.podman-wg-network-create = {
    description = "Create wg Podman network";
    before = ["wg-easy.service"];
    requires = ["podman.service"];
    wantedBy = ["wg-easy.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.podman}/bin/podman network rm wg || true
      ${pkgs.podman}/bin/podman network create \
        --driver bridge \
        --subnet 10.42.42.0/24 \
        --subnet fdcc:ad94:bacf:61a3::/64 \
        wg || true
    '';
  };
  virtualisation.oci-containers.containers.wg-easy = {
    serviceName = "wg-easy";
    image = "ghcr.io/wg-easy/wg-easy:15.3";
    autoStart = true;

    volumes = [
      "etc-wireguard:/etc/wireguard"
      "/run/current-system/kernel-modules/lib/modules:/lib/modules:ro"
    ];

    environment = {
      # Allow logging into the web UI over plain http (no TLS reverse proxy)
      INSECURE = "true";

      # Unattended setup, only applied on first start (empty database).
      # INIT_USERNAME / INIT_PASSWORD come from the environment file below.
      INIT_ENABLED = "true";
      INIT_HOST = "192.168.50.142";
      INIT_PORT = "51820";
      INIT_DNS = "1.1.1.1,8.8.8.8";
      INIT_IPV4_CIDR = "10.8.0.0/24";
      INIT_IPV6_CIDR = "fdcc:ad94:bacf:61a4::/64";
    };

    # Kept out of the nix store. Create it on the host, e.g.:
    #   INIT_USERNAME=admin
    #   INIT_PASSWORD=<at least 12 chars>

    networks = ["wg"];

    ports = [
      "51820:51820/udp"
      "51821:51821/tcp" # WEB UI
    ];

    # The image switches iptables to the legacy backend, but the host runs nftables
    # (networking.nftables blacklists ip_tables), so switch it back to iptables-nft.
    entrypoint = "/bin/sh";
    cmd = [
      "-c"
      ''
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
      "--cap-add=SYS_MODULE" # <-- add this

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
