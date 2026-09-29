# home/wlogout.nix
{
  config,
  lib,
  theme,
  ...
}: let
  # wlogout draws each button's icon as a CSS background-image keyed on the
  # button's `label`; these are the PNGs the package itself ships.
  icon = name: "${config.programs.wlogout.package}/share/wlogout/icons/${name}.png";
in {
  programs.wlogout = {
    enable = true;
    layout = [
      {
        "label" = "lock";
        "action" = "loginctl lock-session";
        "text" = "Lock";
        "keybind" = "l";
      }
      {
        "label" = "hibernate";
        "action" = "systemctl hibernate";
        "text" = "Hibernate";
        "keybind" = "h";
      }
      {
        "label" = "logout";
        "action" = "hyprctl dispatch exit";
        "text" = "Logout";
        "keybind" = "e";
      }
      {
        "label" = "shutdown";
        "action" = "systemctl poweroff";
        "text" = "Shutdown";
        "keybind" = "s";
      }
      {
        "label" = "suspend";
        "action" = "systemctl suspend";
        "text" = "Suspend";
        "keybind" = "u";
      }
      {
        "label" = "reboot";
        "action" = "systemctl reboot";
        "text" = "Reboot";
        "keybind" = "r";
      }
    ];

    # Custom styling with Catppuccin colors, icons and rounded corners
    style = lib.mkForce ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 18px;
        font-weight: bold;
        background-image: none;
        outline: none;
        box-shadow: none;
        text-shadow: none;
        transition: all 0.3s ease;
      }

      window {
        background-color: rgba(30, 30, 46, 0.95);
      }

      button {
        background-color: rgba(49, 50, 68, 0.8);
        border: 2px solid rgba(108, 112, 134, 0.6);
        border-radius: 20px;
        margin: 15px;
        padding: 30px;
        color: #${theme.text};
        min-width: 180px;
        min-height: 180px;
        font-size: 24px;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.5);

        /* the icon sits centred, and wlogout pins the text label at
           yalign 0.9, so the two stack instead of overlapping */
        background-repeat: no-repeat;
        background-position: center 40%;
        background-size: 48px 48px;
      }

      button:focus,
      button:active,
      button:hover {
        background-color: rgba(108, 112, 134, 0.4);
        box-shadow: 0 8px 25px rgba(0, 0, 0, 0.6);
      }

      #lock {
        background-image: url("${icon "lock"}");
        background-color: rgba(249, 226, 175, 0.15);
        border-color: rgba(249, 226, 175, 0.5);
      }
      #lock:hover {
        border-color: #${theme.yellow};
        color: #${theme.yellow};
        background-color: rgba(249, 226, 175, 0.25);
        box-shadow: 0 8px 25px rgba(249, 226, 175, 0.4);
      }

      #logout {
        background-image: url("${icon "logout"}");
        background-color: rgba(137, 180, 250, 0.15);
        border-color: rgba(137, 180, 250, 0.5);
      }
      #logout:hover {
        border-color: #${theme.blue};
        color: #${theme.blue};
        background-color: rgba(137, 180, 250, 0.25);
        box-shadow: 0 8px 25px rgba(137, 180, 250, 0.4);
      }

      #suspend {
        background-image: url("${icon "suspend"}");
        background-color: rgba(148, 226, 213, 0.15);
        border-color: rgba(148, 226, 213, 0.5);
      }
      #suspend:hover {
        border-color: #${theme.teal};
        color: #${theme.teal};
        background-color: rgba(148, 226, 213, 0.25);
        box-shadow: 0 8px 25px rgba(148, 226, 213, 0.4);
      }

      #hibernate {
        background-image: url("${icon "hibernate"}");
        background-color: rgba(180, 190, 254, 0.15);
        border-color: rgba(180, 190, 254, 0.5);
      }
      #hibernate:hover {
        border-color: #${theme.lavender};
        color: #${theme.lavender};
        background-color: rgba(180, 190, 254, 0.25);
        box-shadow: 0 8px 25px rgba(180, 190, 254, 0.4);
      }

      #shutdown {
        background-image: url("${icon "shutdown"}");
        background-color: rgba(243, 139, 168, 0.15);
        border-color: rgba(243, 139, 168, 0.5);
      }
      #shutdown:hover {
        border-color: #${theme.red};
        color: #${theme.red};
        background-color: rgba(243, 139, 168, 0.25);
        box-shadow: 0 8px 25px rgba(243, 139, 168, 0.4);
      }

      #reboot {
        background-image: url("${icon "reboot"}");
        background-color: rgba(250, 179, 135, 0.15);
        border-color: rgba(250, 179, 135, 0.5);
      }
      #reboot:hover {
        border-color: #${theme.peach};
        color: #${theme.peach};
        background-color: rgba(250, 179, 135, 0.25);
        box-shadow: 0 8px 25px rgba(250, 179, 135, 0.4);
      }
    '';
  };
}
