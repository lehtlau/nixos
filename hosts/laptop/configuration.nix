# configuration.nix
{
  pkgs,
  root,
  ...
}: {
  networking.hostName = "laptop";

  imports = [
    # hardware config
    ./hardware-configuration.nix
    # desktop modules -- hyprland
    "${root}/modules/desktop/common-desktop/common-desktop-packages.nix"
    "${root}/modules/desktop/common-desktop/sddm.nix"
    "${root}/modules/desktop/hyprland"
    "${root}/modules/desktop/common-desktop/gaming.nix"
    "${root}/modules/desktop/common-desktop/orca.nix"
    "${root}/modules/desktop/common-desktop/torrenting.nix"

    #system config
    "${root}/modules/system/kernel/lts.nix"
    "${root}/modules/system/boot/grub.nix"
    "${root}/modules/system/input"
    "${root}/modules/system/audio"
    "${root}/modules/system/users"
    "${root}/modules/system/networking"
    "${root}/modules/desktop/common-desktop/home-vpn"
    "${root}/modules/system/locale"
    "${root}/modules/system/fonts/lcd.nix"
    "${root}/modules/system/bluetooth"

    #nix settings
    "${root}/modules/nix"

    #services
    "${root}/modules/services/ssh.nix"
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
