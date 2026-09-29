# home/gtk.nix
{
  pkgs,
  lib,
  ...
}: {
  # GTK Theme Configuration
  gtk = {
    enable = true;

    # The native file/directory dialogs of VSCode and other Electron apps are drawn
    # by xdg-desktop-portal-gtk, a separate GTK3 process. It does not inherit the
    # GTK_THEME/GTK_APPLICATION_PREFER_DARK_THEME that hyprland.nix exports (those
    # only reach hyprland's own children), and GTK3 has no notion of the libadwaita
    # color-scheme below, so the dialogs fell back to light Adwaita. This writes
    # gtk-application-prefer-dark-theme into gtk-3.0/settings.ini, which every GTK
    # process reads, so the portal renders Adwaita's dark variant.
    colorScheme = "dark";

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
  };

  # Tell libadwaita applications (like Loupe and Shortwave) to prefer the dark theme.
  # This uses dconf, a configuration system for GNOME apps.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      "color-scheme" = "prefer-dark";
    };
  };

  # libadwaita apps (gnome-calculator, pwvucontrol) read color-scheme from the portal's
  # Settings interface, which xdg-desktop-portal-gtk provides. The home-manager Hyprland
  # module points NIX_XDG_DESKTOP_PORTAL_DIR at the user profile, so the portal must be
  # installed here too; the system-level extraPortals entry is not seen.
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];

  # Qt application theming with Catppuccin support
  # Kvantum is applied through qt5ct/qt6ct instead of QT_STYLE_OVERRIDE,
  # because QML apps (e.g. mediawriter) treat that variable as a QtQuick style and fail to start.
  qt = let
    qtctSettings = {
      Appearance = {
        style = "kvantum";
        icon_theme = "Papirus-Dark";
        # Kvantum only styles widgets; QML apps (e.g. mediawriter) take colors from this palette
        custom_palette = true;
        color_scheme_path = "${pkgs.catppuccin-qt5ct}/share/qt5ct/colors/catppuccin-mocha-mauve.conf";
      };
    };
  in {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum"; # required by catppuccin's kvantum module
    qt5ctSettings = qtctSettings;
    qt6ctSettings = qtctSettings;
  };

  # Empty value is ignored by Qt, so the style comes from qtct above.
  home.sessionVariables.QT_STYLE_OVERRIDE = lib.mkForce "";
  systemd.user.sessionVariables.QT_STYLE_OVERRIDE = lib.mkForce "";
}
