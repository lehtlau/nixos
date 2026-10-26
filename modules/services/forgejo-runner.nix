{pkgs, ...}: {
  # Runs Forgejo Actions jobs (e.g. the monthly GitHub sync workflow).
  # Uses podman (already enabled in modules/virtualization/default.nix) as the
  # container backend, so labels must use the ":docker://<image>" scheme.
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.default = {
      enable = true;
      url = "http://127.0.0.1:3000";
      name = "runner";
      # Root-owned, mode 0600; contains TOKEN=<new registration token>.
      # sudo install -d -m 700 /etc/forgejo-runner
      # sudo touch /etc/forgejo-runner/token.env
      # sudo chown root:root /etc/forgejo-runner/token.env
      # sudo chmod 600 /etc/forgejo-runner/token.env
      # sudoedit /etc/forgejo-runner/token.env; TOKEN=<...>

      tokenFile = "/etc/forgejo-runner/token.env";
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
