# home.nix
{config, ...}: let
  myUser = config.my.user;
  # requires catppuccin
in {
  # Home Manager configuration for user environment
  home-manager.users.${myUser.name} = {
    imports = [
      ../../common-home/default.nix
      ./default-apps.nix # Default applications
    ];

    home.stateVersion = "25.05";
  };
}
