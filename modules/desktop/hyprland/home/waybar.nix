{
  lib,
  osConfig,
  pkgs-unstable,
  pkgs,
  config,
  ...
}: let
  # Only some machines have Mullvad installed, so the VPN widget follows the
  # daemon. The scripts it calls live in mullvad.nix.
  hasMullvad = osConfig.services.mullvad-vpn.enable;
  # Only some machines enable GameMode (Feral Interactive's gamemoded), so the
  # toggle follows it. The scripts it calls live in gamemode.nix.
  hasGamemode = osConfig.programs.gamemode.enable;
  defaultVpn = pkgs.writeShellApplication {
    name = "waybar-default-vpn";
    runtimeInputs =
      [
        pkgs.networkmanager
      ]
      ++ lib.optional hasMullvad osConfig.services.mullvad-vpn.package;
    text = ''
      exec ${pkgs.python3}/bin/python ${./waybar-default-vpn.py} ${lib.optionalString hasMullvad "--mullvad"}
    '';
  };
in {
  home.packages = [defaultVpn];
  programs.waybar = {
    enable = true;
    # Upstream drawers only open on hover or on left click, and the hover kind
    # snaps shut as soon as the pointer leaves. The patch adds a pin: right
    # click holds the drawer open (and marks the group .pinned), and makes the
    # power profile module leave non-left buttons to the group around it.
    package = pkgs-unstable.waybar.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./waybar-drawer-pin.patch];
    });
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 36;
        spacing = 4;
        reload_style_on_change = true;
        # hypr-monitors writes the primary output at runtime. Do not set output
        # here: it would override the included file. An empty file shows all outputs.
        include = ["${config.xdg.configHome}/hypr-monitor/primary-output.json"];
        modules-left = [
          "hyprland/workspaces"
          "mpris"
        ];
        modules-center = ["hyprland/window"];
        modules-right =
          [
            "pulseaudio"
            "network"
            "custom/default-vpn"
          ]
          ++ [
            "group/hardware" # battery, expands to hardware controls and stats
            "tray"
            "clock"
          ];

        "hyprland/workspaces" = {
          # Empty workspaces still need a visible glyph.
          "format" = "{icon}{windows}";
          "format-icons" = {
            "default" = "";
            "active" = "";
            "empty" = "·";
          };
          # Workspaces are labelled with the apps they hold instead of a number
          "format-window-separator" = " ";
          "window-rewrite-default" = "";
          "window-rewrite" = {
            # terminals
            "class<kitty>" = "";
            "class<kitty> title<.*n?vim.*>" = "";
            # browsers
            "class<firefox>" = "";
            "class<brave-.*>" = "";
            "class<[Cc]hrom(e|ium)(-browser)?>" = "";
            "class<.*[Mm]ullvad.*>" = "";
            # editors, notes and office
            "class<orca>" = "󰚩";
            "class<[Cc]ode(-oss)?>" = "󰨞";
            "class<obsidian>" = "";
            "class<org.kde.kate>" = "";
            "class<libreoffice.*>" = "";
            # chat
            "class<[Dd]iscord>" = "󰙯";
            # gaming
            "class<[Ss]team>" = "";
            "class<steam_app_.*>" = "";
            "class<steam-rom-manager>" = "";
            "class<gamescope>" = "";
            "class<[Hh]eroic>" = "";
            "class<org.prismlauncher.PrismLauncher>" = "";
            "class<net.davidotek.pupgui2>" = "";
            "class<(PCSX2|rpcs3|eden)>" = "";
            # creative
            "class<[Gg]imp.*>" = "";
            "class<(krita|Pixelorama)>" = "";
            "class<([Bb]lender|[Uu]nity.*)>" = "";
            "class<org.kde.kdenlive>" = "";
            "class<com.obsproject.Studio>" = "";
            "class<[Aa]udacity>" = "";
            # media and files
            "class<(mpv|io.github.celluloid_player.Celluloid)>" = "";
            "class<org.gnome.Loupe>" = "";
            "class<[Tt]hunar>" = "";
            "class<org.kde.ark>" = "";
            "class<org.qbittorrent.qBittorrent>" = "";
            # system
            "class<com.saivert.pwvucontrol>" = "";
            "class<nm-connection-editor>" = "";
            "class<org.gnome.Calculator>" = "";
            "class<(org.gnome.Baobab|[Mm]edia[Ww]riter)>" = "";
            # portal dialogs get no icon of their own
            "class<xdg-desktop-portal-gtk>" = "";
          };
          # Pin global IDs on every output. hypr-monitors maps buttons to
          # workspaces by position when styling secondary monitors.
          "persistent-workspaces" = {
            "*" = builtins.genList (i: i + 1) 10;
          };
          "all-outputs" = true;
        };

        "hyprland/window" = {
          "format" = "{}";
          "separate-outputs" = true;
          "max-length" = 50;
        };

        "mpris" = {
          "format" = "{player_icon}";
          "format-paused" = "";
          "format-stopped" = "";
          "player-icons" = {
            "default" = "";
            "mpv" = "🎵";
          };
          "on-click" = "playerctl play-pause";
          "tooltip-format" = "{player}: {title} - {artist}";
        };

        "idle_inhibitor" = {
          "format" = "{icon}";
          "format-icons" = {
            "activated" = "☕ Awake ON";
            "deactivated" = "☕ Awake OFF";
          };
          "start-activated" = false;
          "tooltip-format-activated" = "Automatic screen lock and suspend paused\nClick to turn Awake off";
          "tooltip-format-deactivated" = "Lock and suspend after 30 minutes idle\nClick to turn Awake on";
        };

        "battery" = {
          "name" = "battery";
          "format" = "{capacity}% {icon}";
          "format-charging" = "{capacity}% ";
          "format-plugged" = "{capacity}% ";
          "format-full" = "{capacity}% ";
          "format-not charging" = "{capacity}% ";
          "format-time" = "{H}h {M}min";
          "tooltip-format" = "{timeTo}\n{power}W\nHover: hardware controls and stats\nRight click: pin or unpin drawer";
          "format-icons" = [
            ""
            ""
            ""
            ""
            ""
          ];
          "tooltip" = true;
        };

        # Battery leads the group; hardware controls and stats live in its drawer.
        # Hovering the battery slides them out, right click pins them
        # open until the next right click (see waybar-drawer-pin.patch).
        "group/hardware" = {
          "orientation" = "horizontal";
          "drawer" = {
            "transition-duration" = 300;
            "transition-left-to-right" = false;
            "children-class" = "hardware-child";
          };
          "modules" =
            [
              "battery"
              "custom/temps"
              "cpu"
              "memory"
            ]
            ++ lib.optional hasGamemode "custom/gamemode"
            ++ [
              "idle_inhibitor"
              "power-profiles-daemon"
            ];
        };

        "power-profiles-daemon" = {
          "format" = "{icon}";
          "tooltip" = true;
          "tooltip-format" = "Power profile: {profile}\nLeft click: next profile\nRight click: pin or unpin hardware drawer";
          "format-icons" = {
            "default" = "";
            "performance" = "";
            "balanced" = "";
            "power-saver" = "";
          };
        };

        "pulseaudio" = {
          "format" = "{icon} {volume}%";
          "format-muted" = " Muted";
          "format-icons" = {
            "default" = [
              ""
              ""
              ""
            ];
          };
          "on-click" = "pwvucontrol";
        };

        "network" = {
          "format-wifi" = "{essid} ({signalStrength}%) ";
          "format-ethernet" = "󰈀";
          "format-disconnected" = "󰌙";
          "tooltip-format" = "{ifname}: {essid} via {gwaddr}";
          "on-click" = "kitty -e nmtui";
        };

        "custom/default-vpn" =
          {
            "exec" = "waybar-default-vpn";
            "return-type" = "json";
            "interval" = 5;
            "format" = "{}";
            "tooltip" = true;
            "hide-empty-text" = true;
            "signal" = 8;
          }
          // lib.optionalAttrs hasMullvad {
            "on-click" = "mullvad-toggle";
            "on-click-right" = "mullvad-menu";
          };

        "cpu" = {
          "format" = "󰻠 {usage}%";
          "interval" = 5;
          "tooltip" = true;
          "on-click" = "kitty -e btop";
        };

        "memory" = {
          "format" = "󰍛 {}%";
          "interval" = 10;
          "tooltip" = true;
          "on-click" = "kitty -e bash -c 'free -h; read'";
        };

        "custom/temps" = {
          "exec" = "waybar-temps";
          "format" = "{}";
          "interval" = 50;
          "tooltip" = true;
          "on-click" = "kitty -e bash -c 'sensors; read'";
        };

        # GameMode (Feral Interactive's gamemoded) toggle, only wired up when
        # programs.gamemode is enabled on the host. Left click starts the
        # service if it's stopped, stops it if it's running; the script
        # signals waybar (SIGRTMIN+9) once the state has flipped so the icon
        # updates immediately instead of waiting out the interval.
        "custom/gamemode" = {
          "exec" = "waybar-gamemode";
          "return-type" = "json";
          "interval" = 10;
          "signal" = 9;
          "tooltip" = true;
          "on-click" = "gamemode-toggle";
        };

        "custom/vpn" = {
          "exec" = "waybar-vpn";
          "format" = "{}";
          "interval" = 5;
          "tooltip" = true;
          "tooltip-format" = "VPN Status - Click to toggle";
          "on-click" = "kitty -e bash -c 'if nmcli connection show --active | grep -q be-bru.prod.surfshark.comsurfshark_openvpn_udp; then vpn disconnect; else vpn connect; fi; read'";
        };

        "clock" = {
          "format" = " {:%H:%M}";
          "tooltip-format" = "<big>{:%A, %d %B %Y}</big>\n<tt><small>{calendar}</small></tt>";
          "calendar" = {
            "mode" = "year";
            "mode-mon-col" = 3;
            "weeks-pos" = "right";
            "on-scroll" = 1;
            "format" = {
              "months" = "<span color='#ffead3'><b>{}</b></span>";
              "days" = "<span color='#ecc6d9'><b>{}</b></span>";
              "weeks" = "<span color='#99ffdd'><b>W{}</b></span>";
              "weekdays" = "<span color='#ffcc66'><b>{}</b></span>";
              "today" = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };

        "tray" = {
          "icon-size" = 16;
          "spacing" = 10;
        };
      };
    };
    style = ''
      @import "catppuccin.css";
      /* Red underline on secondary-monitor workspaces, rewritten by the
         hypr-monitors widget (SUPER+P) whenever monitor topology changes. */
      @import "../hypr-monitor/workspace-monitors.css";

      * {
        font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", "Inter", "Noto Sans", sans-serif;
        font-size: 14px;
        font-weight: 500;
        min-height: 0;
        border: none;
      }

      window#waybar {
        background-color: @base;
        color: @text;
        padding: 4px 8px;
      }

      #workspaces button {
        padding: 4px 8px;
        margin: 4px 2px;
        background: transparent;
        color: @subtext0;
        font-size: 15px;
      }

      /* Empty workspaces have no window icons to show */
      #workspaces button.empty {
        padding: 4px 6px;
        color: @overlay0;
      }

      #workspaces button.active {
        background: @mauve;
        color: @base;
        border-radius: 4px;
      }

      #workspaces button:hover {
        background: @surface1;
        color: @text;
        border-radius: 4px;
      }

      /* Flat like the workspace icons: no pill, just the glyph and its label */
      #cpu, #memory, #custom-temps, #pulseaudio, #battery,
      #network, #clock, #mpris, #idle_inhibitor,
      #custom-vpn, #custom-mullvad, #custom-default-vpn,
      #custom-gamemode, #power-profiles-daemon {
        padding: 4px 8px;
        margin: 4px 2px;
        background: transparent;
        color: @subtext0;
        border-radius: 4px;
      }

      #cpu:hover, #memory:hover, #custom-temps:hover, #pulseaudio:hover,
      #battery:hover, #network:hover, #clock:hover, #mpris:hover, #idle_inhibitor:hover,
      #custom-vpn:hover,
      #custom-gamemode:hover, #power-profiles-daemon:hover {
        background: @surface1;
        color: @text;
      }

      #idle_inhibitor.activated {
        color: @green;
      }

      #custom-gamemode.active {
        color: @green;
      }

      #custom-gamemode.active-performance {
        color: @yellow;
      }

      #custom-default-vpn.home {
        color: @blue;
      }

      #custom-default-vpn.mullvad {
        color: @green;
      }

      #custom-default-vpn.connected {
        color: @green;
      }

      #custom-default-vpn.connecting,
      #custom-default-vpn.disconnecting {
        color: @yellow;
      }

      /* traffic is blocked: either lockdown mode or the daemon's blocked state */
      #custom-default-vpn.lockdown {
        color: @peach;
      }

      #custom-default-vpn.blocked {
        background: @red;
        color: @base;
      }

      #custom-default-vpn.disconnected,
      #custom-default-vpn.unavailable,
      #custom-default-vpn.unknown {
        color: @subtext0;
      }

      #power-profiles-daemon.performance {
        color: @peach;
      }

      #power-profiles-daemon.balanced {
        color: @blue;
      }

      #power-profiles-daemon.power-saver {
        color: @green;
      }

      /* The group gets :hover while its drawer is open, so the revealed
         temps/cpu/memory read as one container next to the profile icon */
      #hardware:hover {
        background: @surface0;
        border-radius: 4px;
      }

      /* Pinned open by right click: same container, a little more present */
      #hardware.pinned {
        background: @surface1;
        border-radius: 4px;
      }

      #hardware .hardware-child {
        margin: 4px 0px;
      }

      #custom-temps.critical {
        color: @red;
        animation: temp-warning 1s ease-in-out infinite alternate;
      }

      @keyframes temp-warning {
        from { opacity: 1; }
        to { opacity: 0.7; }
      }

      #window {
        background: transparent;
        color: @subtext1;
        font-style: italic;
      }

      #tray {
        padding: 4px 8px;
        margin: 4px 2px;
        background: transparent;
        border-radius: 4px;
      }
    '';
  };

  # workspace-monitors.css and primary-output.json are rewritten at runtime by
  # the hypr-monitors widget (SUPER+P) whenever monitor topology changes, so
  # neither can be a home-manager-managed symlink (that would make them
  # read-only and fight the widget's writes). This only seeds them so the
  # @import and the include above have something to resolve before the widget
  # has ever run; once they exist this is a no-op.
  home.activation.ensureWaybarMonitorsCss = lib.hm.dag.entryAfter ["writeBoundary"] ''
    css="${config.xdg.configHome}/hypr-monitor/workspace-monitors.css"
    [ -f "$css" ] || install -D -m644 /dev/null "$css"
    out="${config.xdg.configHome}/hypr-monitor/primary-output.json"
    [ -f "$out" ] || { install -D -m644 /dev/null "$out" && echo '{}' > "$out"; }
  '';
}
