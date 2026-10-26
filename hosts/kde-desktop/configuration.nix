# configuration.nix
{root, ...}: {
  # hostname, used in config generation
  networking.hostName = "kde-desktop";

  imports = [
    # hardware config
    ./hardware-configuration.nix
    #system config
    "${root}/modules/system/kernel/latest.nix"
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
    "${root}/modules/desktop/common-desktop/sddm.nix"
    "${root}/modules/desktop/kde"
    #services
    "${root}/modules/services/ssh.nix"
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
