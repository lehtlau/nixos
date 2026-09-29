{pkgs, ...}: let
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
  # Note: Package version is managed in home/hyprland.nix via home-manager
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true; # X11 app compatibility

  # XDG Desktop Portal for proper Wayland app integration
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };
  catppuccin.enable = true;
  catppuccin.sddm.enable = false;
  catppuccin.grub.enable = false;

  # Enable PAM authentication for screen locking
  security.pam.services.hyprlock = {};

  # Enable gnome-keyring for secret storage
  services.gnome.gnome-keyring.enable = true;
  services.blueman.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
}
