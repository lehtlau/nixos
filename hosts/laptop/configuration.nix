# configuration.nix
{pkgs, ...}: {
  # hostname, used in config generaiton
  networking.hostName = "laptop";

  imports = [
    # hardware config
    ./hardware-configuration.nix
    # desktop modules
    ../../modules/desktop/common-desktop/common-desktop-packages.nix
    ../../modules/desktop/common-desktop/sddm.nix
    ../../modules/desktop/hyprland
    ../../modules/desktop/common-desktop/gaming.nix

    #system config
    ../../modules/system/kernel/latest.nix
    ../../modules/system/boot/grub.nix
    ../../modules/system/input
    ../../modules/system/audio
    ../../modules/system/users
    ../../modules/system/networking
    ../../modules/system/locale
    ../../modules/system/fonts/lcd.nix
    ../../modules/system/bluetooth

    #nix settings
    ../../modules/nix
  ];

  my.sddm = {
    defaultSession = "hyprland.desktop";
    autologin = true;
  };

  #hw specific packages
  environment.systemPackages = with pkgs; [
    acpi
    lm_sensors
    brightnessctl # For brightness control
    cpufrequtils # For CPU frequency monitoring
  ];

  # Do not sleep when connected to power and closing lid
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  powerManagement = {
    enable = true;
    powertop.enable = false;
  };

  # Switchable power profiles (power-saver / balanced / performance).
  # No ACPI platform_profile here, so PPD drives intel_pstate EPP + turbo.
  services.power-profiles-daemon.enable = true;

  system.stateVersion = "25.05";
}
