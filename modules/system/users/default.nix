{
  pkgs-unstable,
  theme,
  config,
  pkgs,
  ...
}: {
  my.user = {
    name = "user";
    email = "user@net.com";
    keys = [];
  };

  # Home-Manager configuration - manages user environment
  home-manager = {
    useGlobalPkgs = true; # Use system nixpkgs
    useUserPackages = true; # Install to user profile
    backupFileExtension = "backup"; # Backup existing files instead of failing
    extraSpecialArgs = {inherit pkgs-unstable theme;}; # Pass variables to home config
    users.${config.my.user.name} = _: {
      # User configuration defined in home/
    };
  };
  users.users.${config.my.user.name} = {
    openssh.authorizedKeys.keys = config.my.user.keys;
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel" # sudo group
      "gamemode" # Gaming mode service requires user to be part of gamemode group
      "input"
      "disk"
      "storage" # gnome service, allows user to mount and unmount disks
      "podman" # Required by podman engine / virtualization.nix
    ]; # wheel = sudo access
  };
}
