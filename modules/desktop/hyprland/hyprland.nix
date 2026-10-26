{
  pkgs,
  pkgs-unstable,
  ...
}: let
  # Custom Hyprland session that uses home-manager's start-hyprland wrapper
  hyprland-session = pkgs.symlinkJoin {
    name = "hyprland-session";
    paths = [
      (pkgs.writeTextDir "share/wayland-sessions/hyprland.desktop" ''
        [Desktop Entry]
        Name=Hyprland
        Comment=An intelligent dynamic tiling Wayland compositor
        Exec=start-hyprland
        Type=Application
        DesktopNames=Hyprland
        Keywords=tiling;wayland;compositor;
      '')
    ];
    passthru.providedSessions = ["hyprland"];
  };
in {
  services.displayManager.sessionPackages = [hyprland-session];
  # Set default session to Hyprland
  services.displayManager.defaultSession = "hyprland";

  # Hyprland window manager (Wayland-based)
  # Keep the login session on the same version as Home Manager. Installing
  # a newer user package alone does not replace the system compositor.
  programs.hyprland.enable = true;
  programs.hyprland.package = pkgs-unstable.hyprland;
  programs.hyprland.portalPackage = pkgs-unstable.xdg-desktop-portal-hyprland;
  programs.hyprland.xwayland.enable = true; # X11 app compatibility

  # XDG Desktop Portal for proper Wayland app integration
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.kwallet
    ];
    config.common.default = "*";
  };
  catppuccin.enable = true;
  catppuccin.sddm.enable = false;
  catppuccin.grub.enable = false;

  # Enable PAM authentication for screen locking
  security.pam.services.hyprlock = {};

  # KWallet supplies the Secret Service API outside Plasma.
  services.dbus.packages = [pkgs.kdePackages.kwallet];
  environment.systemPackages = [pkgs.kdePackages.kwallet];
  services.blueman.enable = true;
}
