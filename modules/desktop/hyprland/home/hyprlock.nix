{
  pkgs,
  osConfig,
  ...
}: let
  myUser = osConfig.my.user;
in {
  # Install the hyprlock package
  home.packages = with pkgs; [
    hyprlock
  ];

  # Link the configuration file to the correct path
  # Hyprlock looks for its config in ~/.config/hypr/hyprlock.conf
  home.file.".config/hypr/hyprlock.conf".text = ''
    # hyprlock.conf

    general {
        disable_loading_bar = true
        hide_cursor = false
    }

    background {
        path = /home/${myUser.name}/nixos-config/wallpapers/f1.png
        blur_passes = 3
        blur_size = 8
    }

    input-field {
        size = 250, 50
        position = 0, -80
        monitor =
        dots_center = true
        fade_on_empty = false
        placeholder_text = <i>Password...</i>
        outer_color = rgb(cba6f7)
        inner_color = rgb(1e1e2e)
        font_color = rgb(cdd6f4)
        outline_thickness = 2
        rounding = 15
    }

    # Time
    label {
        monitor =
        text = cmd[update:1000] echo "<b><big> $(date +"%H:%M") </big></b>"
        color = rgba(205, 214, 244, 1.0)
        font_size = 64
        position = 0, 80
        halign = center
        valign = center
    }

    # Date
    label {
        monitor =
        text = cmd[update:1000] echo "$(date +"%A, %d %B")"
        color = rgba(186, 194, 222, 1.0)
        font_size = 18
        position = 0, -15
        halign = center
        valign = center
    }
  '';
}
