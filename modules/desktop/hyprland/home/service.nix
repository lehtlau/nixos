# home/services.nix
{
  pkgs,
  theme,
  ...
}: {
  # -- User-level System Services --

  # MPRIS proxy forwards D-Bus media control signals to Waybar
  services.mpris-proxy.enable = true;

  # playerctl provides CLI media controls (play, pause, next, etc.)
  home.packages = [pkgs.playerctl];

  # Mako is a Wayland notification daemon - replaces dunst on X11
  services.mako = {
    enable = true;
    # Settings go in a nested attrset, not top-level
    settings = {
      "background-color" = "#${theme.primary_background}";
      "text-color" = "#${theme.primary_foreground}";
      "border-color" = "#${theme.primary_accent}";
      "border-size" = 2;
      "border-radius" = 10;
      "default-timeout" = 5000;
      "font" = "JetBrainsMono Nerd Font 12";

      # Critical notifications (e.g. the 5% battery warning) stay until dismissed
      "urgency=critical" = {
        "border-color" = "#${theme.red}";
        "default-timeout" = 0;
      };
    };
  };

  # batsignal watches the battery and notifies through mako
  services.batsignal = {
    enable = true;
    extraArgs = [
      "-w"
      "10" # warning notification at 10%
      "-c"
      "5" # critical notification at 5%
      "-d"
      "0" # disable danger level, nothing is run automatically
      "-i" # don't fail on machines without a battery
      "-a"
      "Battery"
    ];
  };

  # Systemd user services and timers
  systemd.user = {
    # Random wallpaper rotation service
    services.wallpaper-rotate = {
      Unit = {
        Description = "Rotate wallpaper randomly";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'wallpaper-rotate'";
      };
    };

    # Timer for random wallpaper rotation
    timers.wallpaper-rotate = {
      Unit = {
        Description = "Run wallpaper rotation at random intervals";
      };
      Timer = {
        OnUnitActiveSec = "90min";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
