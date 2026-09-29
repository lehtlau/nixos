_: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Allow direnv to automatically load development environments
  home.sessionVariables = {
    DIRENV_LOG_FORMAT = ""; # Reduce direnv output noise
  };
}
