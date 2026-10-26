_: {
  programs.wofi = {
    enable = true;
    # Minimal custom styling - using official Catppuccin Mocha colors
    style = ''
      window {
        background-color: transparent;
        border: 2px solid #cba6f7; /* Catppuccin Mocha mauve */
        border-radius: 10px;
        font-family: "JetBrainsMono Nerd Font";
      }

      #input {
        background-color: #313244; /* Catppuccin Mocha surface0 */
        color: #cdd6f4; /* Catppuccin Mocha text */
        border: none;
        border-radius: 0px;
        margin: 5px;
        padding: 5px;
      }

      #inner-box {
        color: #cdd6f4; /* Catppuccin Mocha text */
        background-color: #1e1e2e; /* Catppuccin Mocha base */
        margin: 5px;
        border-radius: 5px;
      }

      #outer-box {
        margin: 0px;
        background-color: #1e1e2e; /* Catppuccin Mocha base */
        border-radius: 10px;
      }

      #scroll {
        background-color: #1e1e2e; /* Catppuccin Mocha base */
        margin: 5px;
        padding: 5px;
      }

      #entry {
        color: #cdd6f4; /* Catppuccin Mocha text */
        background-color: #313244; /* Catppuccin Mocha surface0 */
        padding: 6px 10px;
      }

      #entry:selected {
        background-color: #cba6f7; /* Catppuccin Mocha mauve */
        color: #1e1e2e; /* Catppuccin Mocha base */
      }

      /* App icon shown in drun mode (allow_images below) */
      #img {
        margin-right: 10px;
      }

      /* Second label of a drun entry, only drawn when display_generic is on */
      #text.drun-generic-name {
        color: #a6adc8; /* Catppuccin Mocha subtext0 */
      }
    '';
    settings = {
      insensitive = true;
      show = "drun"; # Application launcher mode
      width = "60%";
      height = "60%"; # only honoured while `lines` is unset/0
      prompt = "Launch:";
      layer = "overlay"; # Appears above other windows
      # Show each app's icon from the GTK icon theme (Papirus-Dark, see gtk.nix).
      # Also enables wofi's img:/text: escapes in dmenu mode.
      allow_images = true;
      image_size = 24;
    };
  };
}
