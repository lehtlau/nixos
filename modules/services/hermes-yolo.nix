# Hermes with passwordless sudo and command approval prompts disabled.
{lib, ...}: {
  imports = [./hermes-agent.nix];

  # Hermes runs as the normal user, who belongs to wheel.
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Upstream's hardline command blocks still apply in YOLO mode.
  environment.sessionVariables.HERMES_YOLO_MODE = "1";
  systemd.user.services.hermes-gateway = {
    environment.HERMES_YOLO_MODE = "1";
    # sudo must use the setuid wrapper, not the unprivileged store binary.
    path = lib.mkBefore ["/run/wrappers" "/run/current-system/sw"];
    serviceConfig.NoNewPrivileges = false;
  };
}
