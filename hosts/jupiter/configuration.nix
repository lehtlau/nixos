# configuration.nix
{
  root,
  pkgs-unstable,
  ...
}: {
  # hostname, used in config generation
  networking.hostName = "jupiter";

  imports = [
    # hardware config
    ./hardware-configuration.nix
    # De module, imports both desktop envinment and packages
    #system config
    "${root}/modules/system/kernel/lts.nix"
    "${root}/modules/system/boot/grub.nix"
    "${root}/modules/system/input"
    "${root}/modules/system/audio"
    "${root}/modules/system/users"
    "${root}/modules/system/networking"
    "${root}/modules/system/locale"
    "${root}/modules/system/fonts/lcd.nix"
    "${root}/modules/system/bluetooth/default.nix"
    #nix settings
    "${root}/modules/nix"
    # desktop modules
    "${root}/modules/desktop/common-desktop/common-desktop-packages.nix"
    "${root}/modules/desktop/common-desktop/home-vpn"
    "${root}/modules/desktop/common-desktop/sddm.nix"
    "${root}/modules/desktop/common-desktop/gaming.nix"
    "${root}/modules/desktop/common-desktop/game-dev.nix"
    "${root}/modules/desktop/common-desktop/emulators.nix"
    "${root}/modules/virtualization/vm.nix"
    "${root}/modules/desktop/common-desktop/orca.nix"
    "${root}/modules/desktop/kde"

    #services
    "${root}/modules/services/llm/ollama.nix"
    "${root}/modules/services/ssh.nix"
  ];

  my.sddm = {
    defaultSession = "plasma.desktop";
    autologin = true;
  };

  #hw specific packages
  environment.systemPackages = [
  ];

  services.asusd = {
    enable = true;
    package = pkgs-unstable.asusctl;
  };

  services.power-profiles-daemon.enable = true;
  hardware.sensor.iio.enable = true;
  system.stateVersion = "25.05";
}
