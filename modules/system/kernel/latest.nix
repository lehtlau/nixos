{pkgs-unstable, ...}: {
  boot.kernelPackages = pkgs-unstable.linuxPackages_latest;

  system.nixos.tags = ["latest-kernel"];
}
