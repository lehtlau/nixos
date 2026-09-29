# home/shell.nix
{pkgs, ...}: {
  # Zsh Configuration
  home.packages =
    # Core System Utilities (Stable)
    # CLI TUI Tools (Stable)
    with pkgs; [
      eza # Modern 'ls' replacement
      bat # Modern 'cat' with syntax highlighting
      fzf # Fuzzy finder
      zoxide # Smart 'cd' command
      gh # GitHub CLI
      fastfetch
      btop # System monitor
      kitty.terminfo
      nerd-fonts.jetbrains-mono # Programming font with icons
      claude-code # AI coding assistant
    ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # Completion settings
    completionInit = ''
      autoload -U compinit
      compinit

      # Case insensitive completion
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

      # Better completion behavior
      zstyle ':completion:*' menu select
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path ~/.zsh/cache
    '';

    # Add your aliases here
    shellAliases = {
      ls = "eza --icons";
      l = "eza --icons";
      ll = "eza -l --icons --git";
      la = "eza -la --icons --git";
      lt = "eza --tree --level=2 --icons";
      cat = "bat";
    };

    # Oh My Zsh provides themes and plugins for zsh
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
      ]; # Plugin names from oh-my-zsh repository
    };

    # initContent runs after zsh starts - for shell integrations and environment
    initContent = ''
      # Source user environment variables if the file exists
      [ -f ~/.env ] && source ~/.env

      # Editor used by the fzf widgets below. Override at any time with
      # `ed=nano` (or in ~/.env); may contain arguments, e.g. "code -r".
      : "''${ed:=vi}"

      # Initialize tools
      source <(fzf --zsh)
      eval "$(zoxide init zsh)"

      # Autosuggestion settings for better visibility and behavior
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666680,bold"
      ZSH_AUTOSUGGEST_STRATEGY=(history completion)

      # Keybindings for autocompletion
      bindkey '^I' complete-word              # Tab for completion
      bindkey '^[[Z' reverse-menu-complete    # Shift+Tab for reverse completion
      bindkey '^ ' autosuggest-accept         # Ctrl+Space to accept suggestion
      bindkey '^f' autosuggest-accept         # Ctrl+f to accept suggestion (alternative)

      # Ctrl+P: fuzzy-find a file under $PWD and open it in $ed.
      # VS Code's Ctrl+P. Tab multi-selects; all picks are passed to $ed.
      # This takes ^P away from history-back, so that moves to Ctrl+Up below.
      FZF_CTRL_P_OPTS="--preview='bat --style=numbers --color=always --line-range=:200 {}' --preview-window=right,60%,border-left --prompt='files> '"
      fzf-edit-widget() {
        setopt localoptions pipefail no_aliases 2> /dev/null
        local -a files
        files=(''${(f)"$(
          FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=file,follow,hidden --walker-skip=.git,node_modules,.direnv,result,target --scheme=path" "''${FZF_CTRL_P_OPTS-} -m") \
          FZF_DEFAULT_OPTS_FILE="" $(__fzfcmd) < /dev/tty
        )"})
        if (( ''${#files} == 0 )); then
          zle redisplay
          return 0
        fi
        zle push-line # Clear buffer. Auto-restored on next prompt.
        # (q) must be applied per element, then joined: "''${(q)files}" would
        # join the array into one word first and escape the separators too.
        local quoted=''${(j: :)''${(q)files}}
        # $ed stays unquoted so multi-word values like "code -r" work.
        BUFFER="''${ed:-code} $quoted"
        zle accept-line
        local ret=$?
        unset files quoted # ensure these don't end up appearing in prompt expansion
        zle reset-prompt
        return $ret
      }
      zle -N fzf-edit-widget
      bindkey '^P' fzf-edit-widget
      bindkey '^[^F' fzf-edit-widget


      # Ctrl+Alt+P: fuzzy-find a directory under $PWD and open it in $ed.
      # Like Ctrl+P above, but for directories (the editor opens it as a tree/folder).
      FZF_CTRL_ALT_P_OPTS="--preview='eza --tree --level=2 --icons --color=always {}' --preview-window=right,60%,border-left --prompt='dirs> '"
      fzf-edit-dir-widget() {
        setopt localoptions pipefail no_aliases 2> /dev/null
        local dir
        dir="$(
          FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=dir,follow,hidden --walker-skip=.git,node_modules,.direnv,result,target --scheme=path" "''${FZF_CTRL_ALT_P_OPTS-}") \
          FZF_DEFAULT_OPTS_FILE="" $(__fzfcmd) < /dev/tty
        )"
        if [[ -z "$dir" ]]; then
          zle redisplay
          return 0
        fi
        zle push-line # Clear buffer. Auto-restored on next prompt.
        BUFFER="''${ed:-code} ''${(q)dir}"
        zle accept-line
        local ret=$?
        unset dir # ensure this doesn't end up appearing in prompt expansion
        zle reset-prompt
        return $ret
      }
      zle -N fzf-edit-dir-widget
      bindkey '^[^P' fzf-edit-dir-widget

      # History-back, displaced from Ctrl+P. Up arrow and Ctrl+R still work.
      bindkey '^[[1;5A' up-line-or-history    # Ctrl+Up
      bindkey '^[[1;5B' down-line-or-history  # Ctrl+Down

      # Alt+C: fuzzy-find directories *and* files, with a preview pane.
      # Selecting a directory cds into it; selecting a file cds into its parent.
      FZF_ALT_C_OPTS="--preview='if [ -d {} ]; then eza --tree --level=1 --icons --color=always {}; else bat --style=numbers --color=always --line-range=:100 {}; fi' --preview-window=right,60%,border-left"
      fzf-cd-widget() {
        setopt localoptions pipefail no_aliases 2> /dev/null
        local target="$(
          FZF_DEFAULT_COMMAND=''${FZF_ALT_C_COMMAND:-} \
          FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=file,dir,follow,hidden --scheme=path" "''${FZF_ALT_C_OPTS-} +m") \
          FZF_DEFAULT_OPTS_FILE="" $(__fzfcmd) < /dev/tty)"
        if [[ -z "$target" ]]; then
          zle redisplay
          return 0
        fi
        local dir=''${target:a}
        [[ -d "$dir" ]] || dir=''${dir:h}
        zle push-line # Clear buffer. Auto-restored on next prompt.
        BUFFER="builtin cd -- ''${(q)dir}"
        zle accept-line
        local ret=$?
        unset dir target # ensure these don't end up appearing in prompt expansion
        zle reset-prompt
        return $ret
      }
    '';
  };

  programs.fzf = {
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  # Starship Prompt Configuration
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
