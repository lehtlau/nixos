# configuration.nix
{...}: {
  # hostname, used in config generaiton
  networking.hostName = "jupiter";

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
    ../../modules/system/fonts/lcd.nix
    ../../modules/system/bluetooth/default.nix
    #nix settings
    ../../modules/nix
    # desktop modules
    ../../modules/desktop/common-desktop/common-desktop-packages.nix
    ../../modules/desktop/common-desktop/sddm.nix
    ../../modules/desktop/common-desktop/gaming.nix
    ../../modules/desktop/common-desktop/game-dev.nix
    ../../modules/desktop/common-desktop/emulators.nix
    ../../modules/desktop/common-desktop/gaming.nix
    ../../modules/desktop/common-desktop/gnome-boxes.nix
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

  # flr 10bit hdmi on amd gpus
  boot.kernelParams = ["amdgpu.dc_feature_mask=0x400"];

  services.asusd = {
    enable = true;
  };
  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root -"
  ];
  services.power-profiles-daemon.enable = true;
  hardware.sensor.iio.enable = true;
  system.stateVersion = "25.05";
}
