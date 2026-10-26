# Placeholder for a future host, using the installer's filesystem labels.
# Replace with nixos-generate-config output before installing manually.
# scripts/install.sh replaces this file, including the actual LUKS configuration.
{lib, ...}: {
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = ["dm-snapshot"];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NixOS-Root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NixOS-Boot";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
