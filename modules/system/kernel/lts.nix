{pkgs, ...}: {
  # Use the default LTS kernel
  boot.kernelPackages = pkgs.linuxPackages;

  system.nixos.tags = ["lts-kernel"];
}
