{...}: {
  imports = [
    # Applications and tools
    ./packages.nix # System / general packages
    ./browsers.nix # Web browsers (Firefox & Brave)
    ./vscode.nix # Code editor
    ./mangohud.nix # Code editor

    # Shell and development environment
    ./direnv.nix # Development environment management
    ./kitty.nix
    ./thunar.nix

    # System integration
    ./environment.nix # Environment variables and secrets

    ./non-desktop-home.nix
  ];
}
