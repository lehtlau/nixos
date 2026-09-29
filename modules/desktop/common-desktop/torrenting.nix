{pkgs, ...}: {
  services.mullvad-vpn = {
    enable = true;
    enableEarlyBootBlocking = true;
  };

  environment.systemPackages = with pkgs; [
    qbittorrent
    mullvad-vpn
    mullvad-browser
  ];
}
