{pkgs, ...}: {
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
    enableEarlyBootBlocking = true;
  };

  environment.systemPackages = with pkgs; [
    qbittorrent
    mullvad-browser
  ];
}
