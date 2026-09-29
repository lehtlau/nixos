# configuration.nix
{...}: {
  # hostname, used in config generaiton
  networking.hostName = "server";

  imports = [
    # hardware config
    ./hardware-configuration.nix
    # De module, imports both desktop envinment and packages
    #system config
    ../../modules/system/boot/grub.nix
    ../../modules/system/users
    ../../modules/system/locale
    ../../modules/system/networking
    ../../modules/services/firewall/server.nix
    #nix settings
    ../../modules/nix

    #server
    ../../modules/virtualization/default.nix
    ../../modules/services/fail-to-ban.nix
    ../../modules/services/homepage.nix
    ../../modules/services/jellyfin.nix
    ../../modules/services/container/nginx-proxy-manager.nix
    ../../modules/services/container/minecraft-server.nix
    ../../modules/services/container-control
    # ../../modules/services/container/wireguard-easy.nix
    ../../modules/services/ssh.nix
    ../../modules/services/forgego.nix
    ../../modules/services/forgejo-runner.nix
    ../../modules/services/samba-share.nix
    ../../modules/desktop/server
  ];

  #security.sudo.wheelNeedsPassword = false;
  #hw specific packages
  environment.systemPackages = [
  ];

  system.stateVersion = "25.05";
}
