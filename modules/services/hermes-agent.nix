# Hermes Agent: the CLI plus the messaging gateway as a user service.
#
# The gateway unit that `hermes gateway install` writes is meant for FHS
# distros: it pins a store path that goes stale after a rebuild and sets
# PATH=/usr/bin:..., so node/npm/ripgrep/ffmpeg are missing. This unit runs
# the packaged `hermes` wrapper instead, which sets all of that up.
#
# State stays in ~/.hermes and is still configured with the hermes CLI.
{
  config,
  pkgs,
  hermes-agent,
  ...
}: let
  user = config.my.user.name;
  hermes = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  python = "${hermes.hermesVenv}/bin/python3";

  # The package leaves out scripts/whatsapp-bridge, and the bridge needs a
  # writable directory for its node_modules. Copy it into HERMES_HOME, where
  # the gateway looks next and runs `npm install` itself.
  seedWhatsappBridge = pkgs.writeShellScript "hermes-seed-whatsapp-bridge" ''
    dst="$HERMES_HOME/scripts/whatsapp-bridge"
    ${pkgs.coreutils}/bin/mkdir -p "$dst"
    ${pkgs.coreutils}/bin/cp -rT --no-preserve=mode,ownership \
      ${hermes-agent}/scripts/whatsapp-bridge "$dst"
  '';
in {
  environment.systemPackages = [hermes];

  # Keep the gateway running without an active login session.
  users.users.${user}.linger = true;

  systemd.user.services.hermes-gateway = {
    description = "Hermes Agent Gateway - Messaging Platform Integration";
    wantedBy = ["default.target"];
    unitConfig = {
      ConditionUser = user;
      StartLimitIntervalSec = 0;
    };

    environment = {
      HERMES_HOME = "%h/.hermes";
      HERMES_SUPERVISED_CHILD = "1";
    };

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "%h/.hermes";
      ExecStartPre = seedWhatsappBridge;
      ExecStart = "${hermes}/bin/hermes gateway run";
      ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
      # Mark planned stops and reap leftover bridge processes, as the
      # upstream-generated unit does.
      ExecStop = "-${python} -m gateway.systemd_stop_mark";
      ExecStopPost = "-${python} -m gateway.cgroup_cleanup";

      Restart = "always";
      RestartSec = 5;
      # 75 = restart requested, 78 = config error (don't loop on it).
      RestartForceExitStatus = 75;
      SuccessExitStatus = 75;
      RestartPreventExitStatus = 78;
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      TimeoutStopSec = 70;
    };
  };
}
