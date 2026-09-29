{ pkgs, ... }: {
  # Runs Forgejo Actions jobs (e.g. the monthly GitHub sync workflow).
  # Uses podman (already enabled in modules/virtualization/default.nix) as the
  # container backend, so labels must use the ":docker://<image>" scheme.
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.default = {
      enable = true;
      url = "http://192.168.50.197:3000";
      name = "runner";
      token = "98Yn5OVFm_1gvhRWmVoF30m6CGek4gDREjc6-Npozmb";
      hostPackages = with pkgs; [
        nodejs
        buildah
        fuse-overlayfs
        bash
        coreutils
        curl
        gawk
        gitMinimal
        gnused
        wget
      ];
      settings = {
        container.network = "host";
        runner.capacity = 2;
      };
      labels = [
        "debian-latest:docker://node:current-trixie"
      ];
    };
  };
}
