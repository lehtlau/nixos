{
  config,
  lib,
  pkgs,
  ...
}: let
  port = 8090;

  # systemd unit -> label shown in the web UI. Add more here to control them too.
  units = {
    "minecraft-server.service" = "Minecraft";
  };

  unitNames = builtins.attrNames units;
in {
  # systemctl start/stop from an unprivileged user goes through polkit.
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "container-control") {
        var unit = action.lookup("unit");
        var verb = action.lookup("verb");
        var allowed = [${lib.concatMapStringsSep ", " (u: ''"${u}"'') unitNames}];
        if (allowed.indexOf(unit) != -1 &&
            (verb == "start" || verb == "stop" || verb == "restart")) {
          return polkit.Result.YES;
        }
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

  users.users.container-control = {
    isSystemUser = true;
    group = "container-control";
    description = "Web control panel for selected systemd units";
  };
  users.groups.container-control = {};

  systemd.services.container-control = {
    description = "Start/stop panel for selected systemd units";
    after = ["network.target" "polkit.service"];
    wantedBy = ["multi-user.target"];

    environment = {
      CONTROL_PORT = toString port;
      CONTROL_PAGE = "${./index.html}";
      CONTROL_UNITS = lib.concatStringsSep "," (map (u: "${u}=${units.${u}}") unitNames);
      SYSTEMCTL = "${config.systemd.package}/bin/systemctl";
    };

    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./control.py}";
      User = "container-control";
      Group = "container-control";
      Restart = "on-failure";
      RestartSec = 5;

      # hardening
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "full";
      LockPersonality = true;
      RemoveIPC = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
      UMask = "0077";
    };
  };
}
