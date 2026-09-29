{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages =
    # Core System Utilities (Stable)
    (with pkgs; [
      pwvucontrol # PipeWire volume control
    ])
    ++
    # Media and Screenshot Tools (Unstable)
    (with pkgs-unstable; [
      wl-clipboard # Wayland clipboard
      cliphist # Clipboard history manager
      loupe # Image viewer
    ])
    ++
    # Productivity Applications (Unstable)
    (with pkgs-unstable; [
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
    ++
    # Communication (Unstable)
    (with pkgs-unstable; [
      discord # Voice and text chat
    ])
    ++
    # Audio Production Tools (Mixed)
    (with pkgs; [
      audacity # Free audio editor
      sox # Sound processing library
      alsa-utils # ALSA utilities (PipeWire compatible)
    ])
    ++ (with pkgs-unstable; [
      #reaper             # Professional DAW
      ffmpeg-full # Comprehensive media conversion
      celluloid # Media player with codec support
    ]);
}
