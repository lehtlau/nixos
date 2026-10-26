{
  config,
  lib,
  pkgs,
  myOptions,
  ...
}: let
  # sudo install -D -o root -g root -m 600 ~/Downloads/mullvad.conf /etc/wireguard/mullvad-apps.conf
  user = config.my.user.name;
  userShell = lib.getExe config.users.users.${user}.shell;
  python = pkgs.python3.withPackages (p: [p.pygobject3]);
  desktopSupport = pkgs.writeTextDir "vpn_desktop.py" (builtins.readFile ./desktop.py);
  # Keep desktop rendering consistent across sudo -> netns -> runuser.
  # Display sockets alone are insufficient: losing XDG_SESSION_TYPE or the
  # toolkit backend settings can make apps use blurry, scaled XWayland windows.
  desktopEnvironment = lib.concatStringsSep " " [
    "DISPLAY"
    "WAYLAND_DISPLAY"
    "XAUTHORITY"
    "DBUS_SESSION_BUS_ADDRESS"
    "XDG_RUNTIME_DIR"
    "XDG_SESSION_TYPE"
    "XDG_SESSION_DESKTOP"
    "XDG_CURRENT_DESKTOP"
    "XDG_CONFIG_HOME"
    "XDG_CONFIG_DIRS"
    "XDG_DATA_HOME"
    "XDG_DATA_DIRS"
    "NIXOS_OZONE_WL"
    "ELECTRON_OZONE_PLATFORM_HINT"
    "MOZ_ENABLE_WAYLAND"
    "GDK_BACKEND"
    "GDK_SCALE"
    "GDK_DPI_SCALE"
    "GTK_THEME"
    "GTK_APPLICATION_PREFER_DARK_THEME"
    "QT_QPA_PLATFORM"
    "QT_QPA_PLATFORMTHEME"
    "QT_STYLE_OVERRIDE"
    "QT_SCALE_FACTOR"
    "QT_SCREEN_SCALE_FACTORS"
    "QT_AUTO_SCREEN_SCALE_FACTOR"
    "QT_ENABLE_HIGHDPI_SCALING"
    "QT_SCALE_FACTOR_ROUNDING_POLICY"
    "XCURSOR_THEME"
    "XCURSOR_SIZE"
    "XCURSOR_PATH"
    "HYPRCURSOR_THEME"
    "HYPRCURSOR_SIZE"
    "DRI_PRIME"
  ];
  stop = pkgs.writeShellScript "home-vpn-stop" ''
    set -eu
    # Delete the interface even when applications keep the namespace alive.
    ${pkgs.iproute2}/bin/ip -n home-vpn link delete home-apps
    ${pkgs.iproute2}/bin/ip netns delete home-vpn
  '';
  enter = pkgs.writeShellScript "home-vpn-enter" ''
    set -eu
    ${pkgs.systemd}/bin/systemctl start home-vpn.service
    exec ${pkgs.iproute2}/bin/ip netns exec home-vpn \
      ${pkgs.util-linux}/bin/runuser -u ${user} -- \
      ${pkgs.coreutils}/bin/env SHELL=${userShell} "$@"
  '';
  run = pkgs.writeShellApplication {
    name = "home-vpn-run";
    runtimeInputs = [pkgs.libnotify];
    text = ''
      if ! /run/wrappers/bin/sudo ${enter} "$@"; then
        notify-send "Home VPN" "Launch failed. Disconnect the normal home VPN first; check journalctl -u home-vpn."
        exit 1
      fi
    '';
  };
  mullvadEnter = pkgs.writeShellScript "mullvad-apps-enter" ''
    set -eu
    ${pkgs.systemd}/bin/systemctl start mullvad-apps.service
    exec ${pkgs.iproute2}/bin/ip netns exec mullvad-apps \
      ${pkgs.util-linux}/bin/runuser -u ${user} -- \
      ${pkgs.coreutils}/bin/env SHELL=${userShell} "$@"
  '';
  mullvadStop = pkgs.writeShellScript "mullvad-apps-stop" ''
    set -eu
    ${pkgs.iproute2}/bin/ip -n mullvad-apps link delete mv-apps
    ${pkgs.iproute2}/bin/ip netns delete mullvad-apps
  '';
  mullvadRun = pkgs.writeShellApplication {
    name = "mullvad-apps-run";
    runtimeInputs = [pkgs.libnotify];
    text = ''
      if ! /run/wrappers/bin/sudo ${mullvadEnter} "$@"; then
        notify-send "Mullvad apps" "Launch failed. Install /etc/wireguard/mullvad-apps.conf; check journalctl -u mullvad-apps."
        exit 1
      fi
    '';
  };
  launcher = pkgs.writeShellApplication {
    name = "home-vpn-launcher";
    runtimeInputs = [pkgs.wofi run mullvadRun];
    text = ''
      export PYTHONPATH=${desktopSupport}
      exec ${python}/bin/python ${./launcher.py}
    '';
  };
in {
  environment.systemPackages = [
    run
    mullvadRun
    launcher
    (pkgs.makeDesktopItem {
      name = "home-vpn-launcher";
      desktopName = "Home VPN Launcher";
      exec = "home-vpn-launcher";
      icon = "network-vpn";
      categories = ["Network"];
    })
  ];

  systemd.services.home-vpn = {
    description = "Home WireGuard tunnel for selected applications";
    environment.HOME_VPN_DNS = myOptions.server.lanIp;
    after = ["NetworkManager.service" "network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.iproute2 pkgs.wireguard-tools pkgs.networkmanager pkgs.nftables];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.python3}/bin/python ${./setup.py}";
      ExecStop = "${stop}";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /etc/netns/home-vpn";
    };
  };
  systemd.services.mullvad-apps = {
    description = "Mullvad WireGuard tunnel for selected applications";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.iproute2 pkgs.wireguard-tools pkgs.nftables];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.python3}/bin/python ${./mullvad-setup.py}";
      ExecStop = "${mullvadStop}";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /etc/netns/mullvad-apps";
    };
  };
  security.sudo.extraRules = [
    {
      users = [user];
      commands = [
        {
          command = "${mullvadEnter} *";
          options = ["NOPASSWD"];
        }
        {
          command = "${enter} *";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
  security.sudo.extraConfig = ''
    Defaults!${mullvadEnter} env_keep += "${desktopEnvironment}"
    Defaults!${enter} env_keep += "${desktopEnvironment}"
  '';
}
