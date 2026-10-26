{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages =
    (with pkgs; [
      pwvucontrol # PipeWire volume control
    ])
    ++ (with pkgs-unstable; [
      wl-clipboard # Wayland clipboard
      cliphist # Clipboard history manager
      loupe # Image viewer
    ])
    ++ (with pkgs-unstable; [
      obsidian # Note-taking and knowledge management
      kdePackages.kdenlive
      kdePackages.kate
      hunspell # used by libreoffice and others to spellcheck
      hunspellDicts.en_US-large
      libreoffice
      obs-studio
      baobab # gnome disk analyzer
      gimp
      mediawriter
      gnome-calculator
    ])
    ++ (with pkgs-unstable; [
      discord # Voice and text chat
    ])
    ++ (with pkgs; [
      audacity # Free audio editor
      sox # Sound processing library
      alsa-utils # ALSA utilities (PipeWire compatible)
    ])
    ++ (with pkgs-unstable; [
      ffmpeg-full # Comprehensive media conversion
      celluloid # Media player with codec support
    ]);
}
