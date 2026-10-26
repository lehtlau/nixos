{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [
    hyprsunset
  ];

  home.file.".config/hypr/hyprsunset.conf".text = ''
        max-gamma = 150

    profile {
        time = 7:30
        identity = true
    }

    profile {
        time = 21:00
        temperature = 3500
        gamma = 1.0
    }
  '';
}
