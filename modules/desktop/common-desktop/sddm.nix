{
  config,
  lib,
  pkgs,
  root,
  ...
}: let
  mySddm = config.my.sddm;
  myUser = config.my.user;

  # `or false` rather than a plain read: catppuccin.nixosModules.catppuccin is
  # only imported by modules/desktop/hyprland/default.nix, so on a KDE host the
  # option does not read false -- it does not exist at all.
  catppuccinEnabled = config.catppuccin.enable or false;

  catppuccin-sddm-theme = pkgs.catppuccin-sddm.override {
    flavor = "mocha";
    accent = "mauve";
    fontSize = "9";
    background = "${pkgs.copyPathToStore (root + "/wallpapers/w1.jpg")}";
    loginBackground = true;
  };
in {
  config = {
    services.displayManager.sddm = {
      enable = true;

      wayland = {
        enable = true;
        compositor = "kwin";
      };

      package = lib.mkForce pkgs.kdePackages.sddm;

      settings =
        {
          General = {
            DisplayServer = "wayland";
            GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
            InputMethod = ""; # Can be set to "qtvirtualkeyboard" if needed
          };

          Theme =
            {
              Background = "${pkgs.copyPathToStore (root + "/wallpapers/w1.jpg")}";
              CursorSize = 24;
              Font = "JetBrainsMono Nerd Font";
              EnableAvatars = false;
              DisableAvatarsThreshold = 7;
            }
            # Without these SDDM falls back to its built-in theme and cursor.
            // lib.optionalAttrs catppuccinEnabled {
              Current = "catppuccin-mocha-mauve";
              CursorTheme = "catppuccin-mocha-dark-cursors";
            };

          Wayland = {
            CompositorCommand = "${pkgs.kdePackages.kwin}/bin/kwin_wayland --no-lockscreen --inputmethod maliit-keyboard";
            EnableHiDPI = true;
          };

          Users =
            {
              DefaultPath = "/run/current-system/sw/bin";
              HideShells = "";
              HideUsers = "";
              MaximumUid = 60513;
              MinimumUid = 1000;
              RememberLastSession = false;
              RememberLastUser = true;
              ReuseSession = false;
            }
            // lib.optionalAttrs (mySddm.defaultSession != null) {
              DefaultSession = mySddm.defaultSession;
            };
        }
        // lib.optionalAttrs (mySddm.autologin && mySddm.defaultSession != null) {
          Autologin = {
            User = myUser.name;
            Session = mySddm.defaultSession;
          };
        };
    };

    environment.systemPackages =
      [
        pkgs.libsForQt5.qt5.qtquickcontrols2
        pkgs.libsForQt5.qt5.qtgraphicaleffects
        pkgs.kdePackages.qtquick3d
        pkgs.kdePackages.qtvirtualkeyboard
      ]
      ++ lib.optionals catppuccinEnabled [
        catppuccin-sddm-theme
        pkgs.catppuccin-cursors.mochaDark
      ];

    environment.variables =
      {
        XCURSOR_SIZE = "20";
      }
      // lib.optionalAttrs catppuccinEnabled {
        XCURSOR_THEME = "catppuccin-mocha-dark-cursors";
      };
  };
}
