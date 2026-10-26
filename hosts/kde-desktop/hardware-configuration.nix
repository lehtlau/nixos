# PLACEHOLDER -- unlike the other hosts, this was not produced by
# `nixos-generate-config`, because the machine does not exist yet. Replace the
# whole file with the generated one when installing, then re-add the
# boot.initrd.luks block below.
#
# As written it assumes:
#   - the LUKS partition is labelled "encrypted"
#   - the ESP is labelled "BOOT"
#   - root is ext4 directly inside the container (no LVM), so unlocking
#     cryptroot yields /dev/mapper/cryptroot
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = ["dm-snapshot" "cryptd"];
  boot.extraModulePackages = [];

  # LUKS prompts at boot; SDDM autologin is configured separately.
  boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-label/encrypted";

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
