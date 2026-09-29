{pkgs, ...}: {
  # System-wide font configuration for better rendering
  fonts = {
    enableDefaultPackages = true;

    # Font optimization settings
    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
        style = "slight"; # Better for LCD screens
      };
      subpixel = {
        rgba = "rgb"; # For RGB subpixel layout (most common)
        lcdfilter = "default";
      };
      defaultFonts = {
        monospace = [
          "JetBrainsMono Nerd Font"
          "JetBrains Mono"
        ];
        sansSerif = [
          "Inter"
          "DejaVu Sans"
        ];
        serif = ["DejaVu Serif"];
      };
    };

    packages = with pkgs; [
      inter # Better system font
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      source-han-sans
      source-han-serif
      nerd-fonts.ubuntu-mono
      nerd-fonts.ubuntu
      nerd-fonts.ubuntu-sans
      nerd-fonts.symbols-only #icons
      nerd-fonts.jetbrains-mono # programming icons
    ];
  };
}
