{...}: {
  imports = [
    ./packages.nix
    ./browsers.nix
    ./vscode.nix
    ./mangohud.nix

    ./direnv.nix
    ./kitty.nix
    ./nmtui.nix
    ./thunar.nix

    ./environment.nix

    ./non-desktop-home.nix
  ];
}
