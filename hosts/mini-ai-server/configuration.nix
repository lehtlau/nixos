# configuration.nix
{root, ...}: {
  # Hostname, used in config generation
  networking.hostName = "mini-ai-server";

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
    "${root}/modules/virtualization/vm.nix"
    "${root}/modules/services/ssh.nix"
    "${root}/modules/services/forgego.nix"
    "${root}/modules/services/hermes-yolo.nix"
    "${root}/modules/desktop/server"
  ];

  system.stateVersion = "25.05";
}
