{
  catppuccin,
  config,
  hypr-monitors,
  pkgs,
  root,
  ...
}: let
  myUser = config.my.user;
in {
  home-manager.users.${myUser.name} = {
    # catppuccin's own flake builds its vscode extension against its
    # unconfigured `nixpkgs.legacyPackages` (not this system's pkgs), which
    # still resolves to the insecure pnpm 10.34.0 and fails evaluation.
    # Rebuild the same package against our own (permittedInsecurePackages
    # already covers it) pkgs instead.
    catppuccin.sources.vscode = (import "${catppuccin}" {inherit pkgs;}).packages.vscode;

    imports = [
      catppuccin.homeModules.catppuccin
      hypr-monitors.homeModules.default
      ./hyprland.nix
      ./hyprlock.nix
      ./hypridle.nix
      ./hyprsunset.nix
      ./wofi.nix
      ./wlogout.nix
      ./waybar.nix
      ./mullvad.nix
      ./gamemode.nix
      ./service.nix
      ./gtk.nix
      ./packages.nix
      ./scripts.nix
      ./catppuccin.nix
      "${root}/modules/desktop/common-home/default.nix"
      ./default-apps.nix # Default applications
      ../../common-home/kwallet # Classic wallet with an empty password
    ];

    # The widget follows the GTK theme when left alone; this stylesheet is
    # what makes it Catppuccin like the rest of the desktop. The keybind, lid
    # switch and hotplug hook that drive it live in hyprland.nix.
    programs.hypr-monitors = {
      enable = true;
      style = builtins.readFile "${hypr-monitors}/examples/catppuccin-mocha.css";
    };

    home.stateVersion = "25.05";
  };
}
