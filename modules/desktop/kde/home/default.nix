{
  config,
  root,
  ...
}: let
  myUser = config.my.user;
in {
  home-manager.users.${myUser.name} = {
    imports = [
      "${root}/modules/desktop/common-home/default.nix"
      ./default-apps.nix # Default applications
      ../../common-home/kwallet
    ];

    home.stateVersion = "25.05";
  };
}
