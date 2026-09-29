{
  pkgs,
  lib,
  ...
}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
  };
  systemd.services.ollama.wantedBy = lib.mkForce [];
}
