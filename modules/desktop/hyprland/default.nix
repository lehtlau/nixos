# configuration.nix
{catppuccin, ...}: {
  imports = [
    ./hyprland.nix
    ./home # Home-manager configuration
    catppuccin.nixosModules.catppuccin
  ];
}
