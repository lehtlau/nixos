#
{
  pkgs,
  config,
  ...
}: {
  # Nix configuration
  nix.settings.trusted-users = [
    "root"
    "${config.my.user.name}"
  ]; # Users who can configure Nix
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ]; # Enable new Nix CLI
  nix.settings.download-buffer-size = 134217728; # 128MB download buffer (default: 64MB)

  # Development environment optimization
  nix.settings.keep-outputs = true; # Keep build outputs for development shells
  nix.settings.keep-derivations = true; # Keep derivations for development shells

  # Automatic garbage collection - runs daily and keeps only last 3 days
  nix.gc = {
    automatic = true;
    dates = "daily"; # Run every day at 03:15
    options = "--delete-older-than 3d"; # Keep only last 3 days (very aggressive)
  };

  # Enable bin files to run
  programs.nix-ld.enable = true;

  # Run user garbage collection alongside system cleanup
  systemd.user.services.nix-gc-user = {
    description = "Nix Garbage Collector (User)";
    script = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 3d";
    serviceConfig = {
      Type = "oneshot";
      User = "${config.my.user.name}";
    };
  };

  systemd.user.timers.nix-gc-user = {
    description = "Nix Garbage Collection Timer (User)";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1800"; # 30min random delay
      Persistent = true;
    };
  };

  # Automatic store optimization to reduce disk usage
  nix.settings.auto-optimise-store = true;

  # Automatic system updates disabled - manual updates on Sundays
  system.autoUpgrade.enable = false;
}
