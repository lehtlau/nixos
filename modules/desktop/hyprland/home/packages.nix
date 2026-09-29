{pkgs, ...}: {
  home.packages =
    # Fonts and Themes (Stable)
    with pkgs; [
      # papirus-icon-theme - provided by Catppuccin
      libsForQt5.qtstyleplugin-kvantum # Qt theme engine for Catppuccin
      qt6Packages.qtstyleplugin-kvantum # Qt6 theme engine
      libnotify # Desktop notifications
      grim # Wayland screenshot tool
      slurp # Screen area selection
    ];
}
