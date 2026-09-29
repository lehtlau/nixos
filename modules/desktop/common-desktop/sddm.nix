{
  config,
  lib,
  pkgs,
  ...
}: let
  mySddm = config.my.sddm;
  myUser = config.my.user;
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

          Theme = {
            Current = "catppuccin-mocha-mauve";
            Background = "${pkgs.copyPathToStore ../../../wallpapers/w1.jpg}";
            CursorTheme = "catppuccin-mocha-dark-cursors";
            CursorSize = 24;
            Font = "JetBrainsMono Nerd Font";
            EnableAvatars = false;
            DisableAvatarsThreshold = 7;
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

    environment.systemPackages = with pkgs; [
      (catppuccin-sddm.override {
        flavor = "mocha";
        accent = "mauve";
        fontSize = "9";
        background = "${pkgs.copyPathToStore ../../../wallpapers/w1.jpg}";
        loginBackground = true;
      })

      catppuccin-cursors.mochaDark
      libsForQt5.qt5.qtquickcontrols2
      libsForQt5.qt5.qtgraphicaleffects
      kdePackages.qtquick3d
      kdePackages.qtvirtualkeyboard
    ];

    environment.variables = {
      XCURSOR_THEME = "catppuccin-mocha-dark-cursors";
      XCURSOR_SIZE = "20";
    };
  };
}
