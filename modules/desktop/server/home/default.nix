# home.nix
{config, ...}: let
  myUser = config.my.user;
in {
  # Home Manager configuration for user environment
  home-manager.users.${myUser.name} = {
    imports = [
      ../../common-home/non-desktop-home.nix
    ];

    home.stateVersion = "25.05";
  };
}
