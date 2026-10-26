# Hold a gamemoded request in a transient user unit; SIGINT unregisters it cleanly.
# Activating selects the performance power profile; stopping leaves that profile set.
{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  gamemodeCfg = osConfig.programs.gamemode;
  gamemodedBin = "${pkgs.gamemode}/bin/gamemoded";

  # The transient unit that holds the manual "-r" request open. Fixed name so
  # repeated toggles reuse (and query) the same unit.
  holdUnit = "gamemode-waybar-hold.service";

  # waybar re-runs custom/gamemode on SIGRTMIN+<signal>; the number has to
  # match the "signal" key in waybar.nix.
  signal = 9;
  refreshWaybar = "pkill -RTMIN+${toString signal} waybar || true";

  waybarGamemode = pkgs.writeShellApplication {
    name = "waybar-gamemode";
    runtimeInputs = [pkgs.jq pkgs.gnugrep pkgs.power-profiles-daemon];
    text = ''
      if ${gamemodedBin} -s 2>/dev/null | grep -q "is active"; then
        if [ "$(powerprofilesctl get)" = "performance" ]; then
          jq -nc '{text: "󰊴", class: "active-performance", alt: "active-performance",
                   tooltip: "GameMode is active (performance profile)\nLeft click: deactivate"}'
        else
          jq -nc '{text: "󰊴", class: "active", alt: "active",
                   tooltip: "GameMode is active\nLeft click: deactivate"}'
        fi
      else
        jq -nc '{text: "󰗴", class: "inactive", alt: "inactive",
                 tooltip: "GameMode is inactive\nLeft click: activate"}'
      fi
    '';
  };

  gamemodeToggle = pkgs.writeShellApplication {
    name = "gamemode-toggle";
    runtimeInputs = [pkgs.systemd pkgs.power-profiles-daemon];
    text = ''
      if systemctl --user is-active --quiet ${holdUnit}; then
        systemctl --user stop ${holdUnit}
      else
        systemctl --user reset-failed ${holdUnit} >/dev/null 2>&1 || true
        systemd-run --user --unit=${holdUnit} --property=KillSignal=SIGINT \
          --description="Manual GameMode hold (waybar toggle)" \
          -- ${gamemodedBin} -r
        powerprofilesctl set performance
      fi

      ${refreshWaybar}
    '';
  };
in {
  config = lib.mkIf gamemodeCfg.enable {
    home.packages = [
      waybarGamemode
      gamemodeToggle
    ];
  };
}
