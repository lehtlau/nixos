_: {
  # catppuccin.firefox.enable = true;
  # catppuccin.brave.enable = true;
  # catppuccin.vscode.profiles.default.enable = true;
  # Global Catppuccin configuration
  catppuccin = {
    enable = true;
    flavor = "mocha"; # Dark theme - options: latte, frappe, macchiato, mocha
    waybar = {
      mode = "createLink";
    };
    # catppuccin's hyprland integration only emits hyprlang `source` lines for
    # its color variables, which a lua config cannot load (and which nothing
    # here referenced anyway)
    hyprland.enable = false;
    # catppuccin-nvim fails nixpkgs' require check on neovim 0.12 (its
    # detect_integrations module calls vim.pack.get() at load time), and the
    # neovim config here uses tokyonight anyway
    nvim.enable = false;
    vscode.profiles.default.enable = true;
  };
}
