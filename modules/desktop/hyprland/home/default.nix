# home.nix
{
  catppuccin,
  config,
  ...
}: let
  myUser = config.my.user;
  # requires catppuccin
in {
  # Home Manager configuration for user environment
  home-manager.users.${myUser.name} = {
    imports = [
      # Catppuccin theming system
      catppuccin.homeModules.catppuccin
      ./hyprland.nix
      ./hyprlock.nix
      ./hypridle.nix
      ./hyprsunset.nix
      ./wofi.nix
      ./wlogout.nix
      ./waybar.nix
      ./service.nix
      ./gtk.nix
      ./packages.nix
      ./scripts.nix
      ./catppuccin.nix
      ../../common-home/default.nix
      ./default-apps.nix # Default applications
    ];

    home.stateVersion = "25.05";
  };
}
