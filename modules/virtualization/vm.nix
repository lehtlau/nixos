{pkgs, ...}: {
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.swtpm.enable = true;
  programs.virt-manager.enable = true;

  environment.systemPackages = [
    pkgs.swtpm
  ];
}
