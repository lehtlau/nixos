_: {
  networking.networkmanager.enable = true; # GUI network management
  networking.networkmanager.plugins = [
    #npkgs.etworkmanager-openvpn
    #pkgs.networkmanager-openconnect
  ];
}
