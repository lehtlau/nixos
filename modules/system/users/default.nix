{
  pkgs-unstable,
  hypr-monitors,
  theme,
  config,
  pkgs,
  root,
  myOptions,
  ...
}: let
  myUser = config.my.user;
in {
  # Values come from options.nix in the project root
  my.user = {
    inherit (myOptions.user) name email keys;
    hashedPassword = myOptions.user.hashedPassword or null;
    hashedPasswordFile = myOptions.user.hashedPasswordFile or null;
  };

  # Home-Manager configuration - manages user environment
  home-manager = {
    useGlobalPkgs = true; # Use system nixpkgs
    useUserPackages = true; # Install to user profile
    # Keep previous backups when switching desktops or regenerating config files.
    backupCommand = pkgs.writeShellScript "home-manager-backup" ''
      if [ "$#" -gt 0 ]; then
        exec ${pkgs.coreutils}/bin/mv --backup=numbered --no-target-directory -- "$1" "$1.backup"
      fi
    '';
    extraSpecialArgs = {inherit pkgs-unstable hypr-monitors theme root myOptions;}; # Pass variables to home config
    users.${myUser.name} = _: {
      # User configuration defined in home/
    };
  };
  users.users.${myUser.name} = {
    openssh.authorizedKeys.keys = myUser.keys;
    # null means "not managed here", i.e. whatever passwd set stays
    inherit (myUser) hashedPassword hashedPasswordFile;
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel" # sudo group
      "gamemode" # Gaming mode service requires user to be part of gamemode group
      "input"
      "storage" # gnome service, allows user to mount and unmount disks
    ]; # wheel = sudo access
  };
}
