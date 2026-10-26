# home.nix
{
  config,
  root,
  ...
}: let
  myUser = config.my.user;
in {
  # Home Manager configuration for user environment
  home-manager.users.${myUser.name} = {
    imports = [
      "${root}/modules/desktop/common-home/non-desktop-home.nix"
    ];

    home.stateVersion = "25.05";
  };
}
