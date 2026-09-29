{pkgs-unstable, ...}: {
  programs.vscode = {
    enable = true;

    # VSCode profiles separate settings/extensions per workflow
    profiles.default = {
      userSettings = {
        "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";

        #copilot
        "github.copilot.nextEditSuggestions.enabled" = false;
        "claudeCode.preferredLocation" = "panel";

        # Nix language server configuration
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";

        # Direnv integration
        "direnv.restart.automatic" = true;

        # Development environment settings
        "python.defaultInterpreterPath" = ".venv/bin/python";
        "python.terminal.activateEnvironment" = true;
      };
      keybindings = [
        {
          key = "ctrl+j";
          command = "workbench.action.terminal.toggleTerminal";
          when = "terminal.active";
        }
      ];
    };
    # Extensions are managed declaratively - no manual installation
    profiles.default.extensions = with pkgs-unstable.vscode-extensions; [
      ms-python.python # Official Microsoft Python extension
      ms-python.vscode-pylance # Language server: completions, hover, go-to-definition
      bbenoist.nix # Nix language support
      mkhl.direnv # Direnv integration for automatic environment loading
      jnoortheen.nix-ide # Enhanced Nix language support
    ];
  };
}
