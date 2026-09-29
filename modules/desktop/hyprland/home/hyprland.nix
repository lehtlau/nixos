{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}: let
  inherit (lib.generators) mkLuaInline;

  # Lua string literal. JSON escaping is valid Lua escaping for the strings we
  # generate here, so this keeps embedded quotes and backslashes correct.
  luaStr = builtins.toJSON;

  # `hyprctl keyword` only works with the legacy (hyprlang) parser, so anything
  # that pokes at config at runtime goes through `hyprctl eval` instead.
  lidToggle = pkgs.writeShellApplication {
    name = "lid-toggle";
    runtimeInputs = [
      pkgs.jq
      pkgs.hyprland
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      MONITOR="eDP-1"
      ACTION="''${1:-}"

      if [[ -z "$ACTION" ]]; then
        echo "Usage: $0 close|open" >&2
        exit 1
      fi

      monitors_json="$(hyprctl monitors -j)"

      # hyprctl only lists *active* monitors, so presence == enabled
      edp_active=$(jq --arg m "$MONITOR" '[.[] | select(.name == $m)] | length > 0' <<< "$monitors_json")
      other_count=$(jq --arg m "$MONITOR" '[.[] | select(.name != $m)] | length' <<< "$monitors_json")

      case "$ACTION" in
        close)
          # only disable the laptop panel if something else is driving the show
          if (( other_count > 0 )); then
            hyprctl eval "hl.monitor({ output = '$MONITOR', disabled = true })"
          fi
          ;;
        open)
          if [[ "$edp_active" == "false" ]]; then
            hyprctl eval "hl.monitor({ output = '$MONITOR', mode = 'preferred', position = 'auto', scale = 1 })"
          fi
          ;;
        *)
          echo "Unknown action: $ACTION" >&2
          exit 1
          ;;
      esac
    '';
  };

  # ---------------------------------------------------------------------------
  # Keybindings
  #
  # One record per bind. Both the hl.bind() calls and the hypr-keybinds
  # cheatsheet are generated from these lists, so the two cannot drift apart.
  #
  #   mod       name of the lua local holding the modifier, or null for a bare key
  #   extra     additional modifiers, e.g. [ "SHIFT" ]
  #   key       key as hyprland spells it ("T", "left", "mouse:272", ...)
  #   dispatch  raw lua expression: a hl.dsp.* dispatcher or a lua function
  #   desc      human readable action, shown by hypr-keybinds
  #   opts      hl.bind() options, filled in per group by withOpts
  # ---------------------------------------------------------------------------

  # display names of the modifier locals, for the cheatsheet
  modNames = {
    mainMod = "SUPER";
    altMod = "SUPER ALT";
    ctrlMod = "SUPER CTRL";
  };

  exec = cmd: "hl.dsp.exec_cmd(${luaStr cmd})";

  # scale changes used to be `hyprctl keyword monitor`, which the lua parser
  # rejects, so bind a lua function that calls hl.monitor() instead
  setScale = scale: ''function() hl.monitor({ output = "", mode = "preferred", position = "auto", scale = ${scale} }) end'';

  withOpts = opts: map (bind: bind // {inherit opts;});

  keyArg = {
    mod ? null,
    extra ? [],
    key,
    ...
  }: let
    suffix = lib.concatStringsSep " + " (extra ++ [key]);
  in
    if mod == null
    then suffix
    else mkLuaInline ''${mod} .. " + ${suffix}"'';

  mkBind = bind @ {
    dispatch,
    opts ? {},
    ...
  }: {
    _args =
      [
        (keyArg bind)
        (mkLuaInline dispatch)
      ]
      ++ lib.optional (opts != {}) opts;
  };

  # -- lid -- (was bindl)
  lidBinds = withOpts {locked = true;} [
    {
      key = "switch:on:Lid Switch";
      dispatch = exec "lid-toggle close";
      desc = "lid closed: turn the built-in panel off";
    }
    {
      key = "switch:off:Lid Switch";
      dispatch = exec "lid-toggle open";
      desc = "lid opened: turn the built-in panel on";
    }
    {
      key = "switch:on:Lid Switch";
      dispatch = exec "loginctl lock-session";
      desc = "lid closed: lock the session";
    }
  ];

  # -- Resize w/mouse -- (was bindm)
  mouseBinds = withOpts {mouse = true;} [
    {
      mod = "mainMod";
      key = "mouse:272";
      dispatch = "hl.dsp.window.drag()";
      desc = "drag window";
    }
    {
      mod = "mainMod";
      key = "mouse:273";
      dispatch = "hl.dsp.window.resize()";
      desc = "resize window";
    }
  ];

  # was binde
  repeatBinds = withOpts {repeating = true;} [
    # -- Hyprsunset --
    {
      mod = "ctrlMod";
      key = "up";
      dispatch = exec "hyprctl hyprsunset temperature +500";
      desc = "warmer screen";
    }
    {
      mod = "ctrlMod";
      key = "down";
      dispatch = exec "hyprctl hyprsunset temperature -500";
      desc = "cooler screen";
    }
    # -- Resize Windows --
    {
      mod = "altMod";
      key = "left";
      dispatch = "hl.dsp.window.resize({ x = -20, y = 0, relative = true })";
      desc = "shrink window horizontally";
    }
    {
      mod = "altMod";
      key = "right";
      dispatch = "hl.dsp.window.resize({ x = 20, y = 0, relative = true })";
      desc = "grow window horizontally";
    }
    {
      mod = "altMod";
      extra = ["CTRL"];
      key = "up";
      dispatch = "hl.dsp.window.resize({ x = 0, y = -20, relative = true })";
      desc = "shrink window vertically";
    }
    {
      mod = "altMod";
      extra = ["CTRL"];
      key = "down";
      dispatch = "hl.dsp.window.resize({ x = 0, y = 20, relative = true })";
      desc = "grow window vertically";
    }
  ];

  # -- Laptop multimedia keys for volume and LCD brightness -- (was bindel)
  mediaBinds =
    withOpts {
      locked = true;
      repeating = true;
    } [
      {
        key = "XF86AudioRaiseVolume";
        dispatch = exec "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
        desc = "volume up";
      }
      {
        key = "XF86AudioLowerVolume";
        dispatch = exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        desc = "volume down";
      }
      {
        key = "XF86AudioMute";
        dispatch = exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        desc = "mute output";
      }
      {
        key = "XF86AudioMicMute";
        dispatch = exec "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        desc = "mute microphone";
      }
      {
        key = "XF86MonBrightnessUp";
        dispatch = exec "brightnessctl -e4 -n2 set 5%+";
        desc = "brightness up";
      }
      {
        key = "XF86MonBrightnessDown";
        dispatch = exec "brightnessctl -e4 -n2 set 5%-";
        desc = "brightness down";
      }
      # these two used $mainModCtrl, which was never defined anywhere
      {
        mod = "ctrlMod";
        key = "right";
        dispatch = exec "brightnessctl -e4 -n2 set 5%+";
        desc = "brightness up";
      }
      {
        mod = "ctrlMod";
        key = "left";
        dispatch = exec "brightnessctl -e4 -n2 set 5%-";
        desc = "brightness down";
      }
    ];

  # -- Workspace Navigation --
  workspaceBinds = lib.concatMap (n: let
    key = toString (lib.mod n 10);
    ws = toString n;
  in [
    {
      mod = "mainMod";
      inherit key;
      dispatch = "hl.dsp.focus({ workspace = ${ws} })";
      desc = "workspace ${ws}";
    }
    {
      mod = "mainMod";
      extra = ["SHIFT"];
      inherit key;
      dispatch = "hl.dsp.window.move({ workspace = ${ws} })";
      desc = "move window to workspace ${ws}";
    }
  ]) (lib.range 1 10);

  # was bind; these are the ones hypr-keybinds lists
  appBinds =
    [
      # -- App Launchers --
      {
        mod = "mainMod";
        key = "T";
        dispatch = exec "kitty";
        desc = "kitty";
      }
      {
        mod = "mainMod";
        key = "space";
        dispatch = exec "wofi --show drun";
        desc = "app launcher";
      }
      {
        mod = "mainMod";
        key = "E";
        dispatch = exec "thunar";
        desc = "file manager";
      }
      {
        mod = "mainMod";
        key = "O";
        dispatch = exec "obsidian";
        desc = "obsidian";
      }
      {
        mod = "mainMod";
        key = "B";
        dispatch = exec "brave-origin --new-window";
        desc = "brave";
      }
      {
        mod = "altMod";
        key = "B";
        dispatch = exec "firefox --new-window";
        desc = "firefox";
      }
      {
        mod = "mainMod";
        key = "L";
        dispatch = exec "loginctl lock-session";
        desc = "lock session";
      }
      {
        mod = "altMod";
        key = "ESCAPE";
        dispatch = exec "wlogout";
        desc = "logout menu";
      }
      {
        mod = "mainMod";
        key = "K";
        dispatch = exec "code";
        desc = "vscode";
      }
      {
        mod = "altMod";
        key = "K";
        dispatch = exec "kate";
        desc = "kate";
      }
      {
        mod = "mainMod";
        key = "delete";
        dispatch = exec "kitty btop";
        desc = "btop";
      }

      # -- scratchpad --
      {
        mod = "mainMod";
        key = "S";
        dispatch = ''hl.dsp.workspace.toggle_special("magic")'';
        desc = "toggle scratchpad";
      }
      {
        mod = "mainMod";
        extra = ["SHIFT"];
        key = "S";
        dispatch = ''hl.dsp.window.move({ workspace = "special:magic" })'';
        desc = "move window to scratchpad";
      }

      # -- Hyprsunset --
      {
        mod = "mainMod";
        key = "N";
        dispatch = exec "hyprctl hyprsunset temperature 3000";
        desc = "night temperature";
      }
      {
        mod = "ctrlMod";
        key = "N";
        dispatch = exec "hyprctl hyprsunset temperature 6500";
        desc = "day temperature";
      }

      # -- Screenshots --
      {
        key = "Print";
        dispatch = exec "screenshot full";
        desc = "screenshot: whole screen";
      }
      {
        extra = ["SHIFT"];
        key = "Print";
        dispatch = exec "screenshot select";
        desc = "screenshot: selection";
      }
      {
        extra = ["ALT"];
        key = "Print";
        dispatch = exec "screenshot select";
        desc = "screenshot: selection";
      }

      # -- Window Management --
      {
        mod = "mainMod";
        key = "W";
        dispatch = exec "pkill waybar || waybar";
        desc = "restart waybar";
      }
      {
        mod = "mainMod";
        key = "ESCAPE";
        dispatch = "hl.dsp.window.close()";
        desc = "close window";
      }
      {
        mod = "altMod";
        key = "delete";
        dispatch = "hl.dsp.exit()";
        desc = "exit hyprland";
      }
      {
        mod = "mainMod";
        key = "F";
        dispatch = "hl.dsp.window.fullscreen()";
        desc = "fullscreen";
      }
      {
        # window goes into fullscreen mode and does client not
        mod = "altMod";
        key = "F";
        dispatch = "hl.dsp.window.fullscreen_state({ internal = 2, client = 0 })";
        desc = "fullscreen window, client unaware";
      }
      {
        # keeps the window non-fullscreen, but the client goes into fullscreen
        # mode within the window
        mod = "ctrlMod";
        key = "F";
        dispatch = "hl.dsp.window.fullscreen_state({ internal = 0, client = 2 })";
        desc = "client fullscreen inside a normal window";
      }
      {
        mod = "mainMod";
        key = "V";
        dispatch = ''hl.dsp.window.float({ action = "toggle" })'';
        desc = "toggle floating";
      }
      {
        mod = "mainMod";
        key = "P";
        dispatch = "hl.dsp.window.pseudo()";
        desc = "pseudotile (dwindle)";
      }

      # scaling
      {
        mod = "mainMod";
        key = "plus";
        dispatch = setScale "2";
        desc = "scale 2x";
      }
      {
        mod = "altMod";
        key = "plus";
        dispatch = setScale "1.33";
        desc = "scale 1.33x";
      }
      {
        mod = "mainMod";
        key = "minus";
        dispatch = setScale "1";
        desc = "scale 1x";
      }

      # -- Focus / Move with Arrow Keys --
      {
        mod = "mainMod";
        key = "left";
        dispatch = ''hl.dsp.focus({ direction = "left" })'';
        desc = "focus left";
      }
      {
        mod = "mainMod";
        key = "right";
        dispatch = ''hl.dsp.focus({ direction = "right" })'';
        desc = "focus right";
      }
      {
        mod = "mainMod";
        key = "up";
        dispatch = ''hl.dsp.focus({ direction = "up" })'';
        desc = "focus up";
      }
      {
        mod = "mainMod";
        key = "down";
        dispatch = ''hl.dsp.focus({ direction = "down" })'';
        desc = "focus down";
      }
      {
        mod = "mainMod";
        key = "TAB";
        dispatch = "hl.dsp.window.cycle_next()";
        desc = "next window";
      }
      {
        mod = "altMod";
        key = "TAB";
        dispatch = "hl.dsp.window.cycle_next({ prev = true })";
        desc = "previous window";
      }
      {
        mod = "mainMod";
        extra = ["SHIFT"];
        key = "left";
        dispatch = ''hl.dsp.window.move({ direction = "left" })'';
        desc = "move window left";
      }
      {
        mod = "mainMod";
        extra = ["SHIFT"];
        key = "right";
        dispatch = ''hl.dsp.window.move({ direction = "right" })'';
        desc = "move window right";
      }
      {
        mod = "mainMod";
        extra = ["SHIFT"];
        key = "up";
        dispatch = ''hl.dsp.window.move({ direction = "up" })'';
        desc = "move window up";
      }
      {
        mod = "mainMod";
        extra = ["SHIFT"];
        key = "down";
        dispatch = ''hl.dsp.window.move({ direction = "down" })'';
        desc = "move window down";
      }

      # -- Keybinding Helper --
      {
        mod = "mainMod";
        key = "H";
        dispatch = exec "hypr-keybinds";
        desc = "this list";
      }

      # -- Clipboard Manager --
      {
        mod = "mainMod";
        key = "C";
        dispatch = exec "cliphist list | wofi --dmenu | cliphist decode | wl-copy";
        desc = "clipboard history";
      }
    ]
    ++ workspaceBinds;

  allBinds = lidBinds ++ mouseBinds ++ repeatBinds ++ mediaBinds ++ appBinds;

  # Autostart. `exec-once` has no lua equivalent; it is a hyprland.start hook.
  execOnce = [
    "awww-daemon"
    "waybar"
    "hyprsunset"
    "awww init" # Initialize awww daemon
    "wallpaper-rotate" # Set random wallpaper at startup
    "wl-paste --type text --watch cliphist store" # Start clipboard history daemon
    "wl-paste --type image --watch cliphist store" # Store image clipboard items
    "gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'" # Set GTK dark theme
    "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'" # Set color scheme preference
  ];

  startupHook = ''
    function()
    ${lib.concatMapStrings (cmd: "  hl.exec_cmd(${luaStr cmd})\n") execOnce}end'';

  # Format one bind for the wofi cheatsheet
  pangoEscape = lib.replaceStrings ["&" "<" ">"] ["&amp;" "&lt;" "&gt;"];
  format-keybind = bind: let
    keys = lib.concatStringsSep " + " (
      lib.optional (bind.mod or null != null) modNames.${bind.mod}
      ++ (bind.extra or [])
      ++ [bind.key]
    );
  in "<b>${pangoEscape keys}</b>: ${pangoEscape bind.desc}";

  formatted-keybinds = map format-keybind appBinds;

  # writeShellScriptBin creates an executable script in your PATH
  keybinds-script = pkgs.writeShellScriptBin "hypr-keybinds" ''
    echo -e "${lib.concatStringsSep "\\n" formatted-keybinds}" | wofi --show dmenu --allow-markup -p "Hyprland Keybindings"
  '';
in {
  # Hyprland window manager configuration
  # This is the single source of truth for Hyprland version and settings
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs-unstable.hyprland; # Use unstable
    configType = "lua";
    settings = {
      # `$mainMod = SUPER` in hyprlang, a lua local here
      mainMod = {_var = "SUPER";};
      altMod = {_var = "SUPER + ALT";};
      ctrlMod = {_var = "SUPER + CTRL";};

      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = 1;
      };

      # Environment variables to ensure applications detect dark mode
      env = [
        {_args = ["GTK_THEME" "Adwaita:dark"];}
        {_args = ["COLOR_SCHEME" "prefer-dark"];}
        {_args = ["GTK_APPLICATION_PREFER_DARK_THEME" "1"];}
        # {_args = ["QT_QPA_PLATFORMTHEME" "qt5ct"];} # qt6 apps pick up qt6ct automatically
        # {_args = ["QT_QPA_PLATFORM" "wayland"];}
      ];

      config = {
        input = {
          kb_layout = "fi";
          kb_variant = "winkeys";
        };

        misc = {
          disable_hyprland_logo = true;
          force_default_wallpaper = 0;
          disable_splash_rendering = true;
        };

        general = {
          gaps_out = 2;
          gaps_in = 2;

          border_size = 1;
          allow_tearing = true; # Reduces input lag for gaming
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 5;
            passes = 2;
          };
        };

        animations = {
          enabled = true;
        };
      };

      # `bezier = myBezier, 0.05, 0.9, 0.1, 1.05` in hyprlang
      curve = {
        _args = [
          "myBezier"
          {
            type = "bezier";
            points = [
              [0.05 0.9]
              [0.1 1.05]
            ];
          }
        ];
      };

      animation = [
        {
          leaf = "specialWorkspace";
          enabled = false;
          speed = 1;
          bezier = "default";
          style = "slide";
        }
        {
          leaf = "windows";
          enabled = true;
          speed = 7;
          bezier = "myBezier";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 7;
          bezier = "default";
          style = "popin 80%";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 10;
          bezier = "default";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 7;
          bezier = "default";
        }
        {
          leaf = "workspaces";
          enabled = false;
          speed = 6;
          bezier = "default";
        }
      ];

      on = {
        _args = [
          "hyprland.start"
          (mkLuaInline startupHook)
        ];
      };

      bind = map mkBind allBinds;
    };
  };

  # Add our generated script to user packages
  home.packages = [
    keybinds-script
    pkgs.awww # wallpaper utility
    lidToggle
  ];
}
