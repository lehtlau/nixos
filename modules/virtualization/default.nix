{
  pkgs,
  podman-5-8-6,
  ...
}: {
  # Podman configuration for rootless containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Docker compatibility
    defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    # Pinned to 5.8.6: 5.8.7 broke "docker cp" (used by the Forgejo Actions
    # runner to seed actions into job containers) whenever the destination
    # crosses an in-container absolute symlink like /var/run -> /run.
    # Remove this override once nixpkgs picks up a podman/buildah release
    # containing containers/buildah#7129.
    package = podman-5-8-6;
  };
  virtualisation.oci-containers.backend = "podman";

  environment.systemPackages = with pkgs; [
    nfs-utils # For NFS filesystem support
    cifs-utils # For SMB/CIFS filesystem support
    podman-tui # Terminal UI for Podman
    podman-compose # Docker Compose compatibility
  ];
}
