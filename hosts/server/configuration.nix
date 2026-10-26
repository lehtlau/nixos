# configuration.nix
{root, ...}: {
  # Hostname, used in config generation
  networking.hostName = "server";

  imports = [
    # Hardware config
    ./hardware-configuration.nix

    # System config
    "${root}/modules/system/boot/grub.nix"
    "${root}/modules/system/users"
    "${root}/modules/system/locale"
    "${root}/modules/system/networking"
    "${root}/modules/services/firewall/server.nix"

    # Nix settings
    "${root}/modules/nix"

    # Server
    "${root}/modules/virtualization/default.nix"
    "${root}/modules/services/fail-to-ban.nix"
    "${root}/modules/services/homepage.nix"
    "${root}/modules/services/jellyfin.nix"
    "${root}/modules/services/photo-sync/immich.nix"
    "${root}/modules/services/caddy.nix"
    "${root}/modules/services/local-dns.nix"
    "${root}/modules/services/container/minecraft-server.nix"
    "${root}/modules/services/container-control"
    "${root}/modules/services/container/wireguard-easy.nix"
    "${root}/modules/services/ssh.nix"
    "${root}/modules/services/forgego.nix"
    "${root}/modules/services/forgejo-runner.nix"
    "${root}/modules/services/samba-share.nix"
    "${root}/modules/services/hermes-agent.nix"
    "${root}/modules/desktop/server"
  ];

  system.stateVersion = "25.05";
}
