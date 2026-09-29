{...}: {
  imports = [
    # Applications and tools
    ./neovim.nix # Terminal editor

    # Shell and development environment
    ./shell.nix # Zsh configuration
    ./git.nix # Git settings
    ./ssh.nix
  ];
}
