# commonConfig
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nfs-utils # For NFS filesystem support
    cifs-utils # For SMB/CIFS filesystem support
    wireguard-tools # WireGuard VPN tools
    networkmanagerapplet # GUI for NetworkManager VPN
    kdePackages.ark # file achiver tool
    nixd # nix language server
    nixfmt # nix formatter
    just
  ];

  # Enable thunar, services, and plugins
  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  services.gvfs.enable = true; # Required for trash, network browsing, etc.
  services.tumbler.enable = true; # Thumbnail generation for files/images
  programs.thunar.plugins = with pkgs; [
    thunar-archive-plugin
    thunar-volman
  ];
  # auto disk mounting service
  services.udisks2.enable = true;
  security.polkit.enable = true;

  # DNS resolution service for caching and security
  services.resolved.enable = true;

  # Enable UPower for power management information
  services.upower.enable = true;

  programs.zsh.enable = true; # Enable Zsh system-wide

  services.flatpak.enable = false;

  # SSH agent disabled
  programs.ssh.startAgent = false;

  programs.gnupg.agent = {
    enable = true;
    #enableSSHSupport = true;
  };

  #Enable Sudo
  security.sudo.enable = true;

  # Enable automatic trim
  services.fstrim.enable = true;

  # Graphics configuration for gaming and GPU acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Required for Wine/Steam Proton games
  };
}
