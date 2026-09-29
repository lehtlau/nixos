# configuration.nix
{...}: {
  # hostname, used in config generaiton
  networking.hostName = "gmk";

  imports = [
    # hardware config
    ./hardware-configuration.nix
    # De module, imports both desktop envinment and packages
    #system config
    ../../modules/system/kernel/latest.nix
    ../../modules/system/boot/grub.nix
    ../../modules/system/input
    ../../modules/system/audio
    ../../modules/system/users
    ../../modules/system/networking
    ../../modules/system/locale
    ../../modules/system/fonts/oled.nix
    ../../modules/system/bluetooth/default.nix
    #nix settings
    ../../modules/nix
    # desktop modules
    ../../modules/desktop/common-desktop/common-desktop-packages.nix
    ../../modules/desktop/common-desktop/sddm.nix
    ../../modules/desktop/common-desktop/gaming.nix
    ../../modules/desktop/common-desktop/torrenting.nix
    ../../modules/desktop/common-desktop/game-dev.nix
    ../../modules/desktop/common-desktop/emulators.nix
    ../../modules/desktop/common-desktop/gaming.nix
    ../../modules/desktop/kde
    #services
    ../../modules/services/llm/ollama.nix
  ];

  my.sddm = {
    defaultSession = "plasma.desktop";
    autologin = true;
  };

  #hw specific packages
  environment.systemPackages = [
  ];

  system.stateVersion = "25.05";
}
