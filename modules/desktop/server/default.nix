{pkgs, ...}: {
  imports = [
    ./home
  ];
  programs.zsh.enable = true; # Enable Zsh system-wide
  # Enable automatic trim
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    just
  ];
}
