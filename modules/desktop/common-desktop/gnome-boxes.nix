{
  pkgs,
  config,
  ...
}: {
  environment.systemPackages = [
    pkgs.gnome-boxes
  ];

  users.users.${config.my.user.name}.extraGroups = ["libvirtd"];
  virtualisation.libvirtd.enable = true;
}
