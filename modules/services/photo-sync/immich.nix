# Use the unstable package because the stable Immich package is marked insecure.
{pkgs-unstable, ...}: {
  services.immich = {
    enable = true;
    package = pkgs-unstable.immich;

    # LAN access is restricted by firewall/server.nix.
    host = "0.0.0.0";
    port = 2283;

    mediaLocation = "/var/lib/immich";
  };
}
