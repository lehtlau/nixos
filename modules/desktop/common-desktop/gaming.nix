{
  pkgs-unstable,
  config,
  pkgs,
  ...
}: let
  #https://github.com/shahnawazshahin/steam-using-gamescope-guide
  #pci_dev=0:0d:00.0 rx6800 # 0000:c4:00.0 igpu z13
  gpu =
    if config.networking.hostName == "jupiter"
    then 1
    else 0;

  startGamescopeSession = pkgs.writeShellScript "startGamescopeSession" ''
    ${pkgs.gamescope}/bin/gamescope --steam --mangoapp -e -W 3840 -H 2160 -r 120 --default-touch-mode 4 --force-grab-cursor -w 3840 -h 2160 -- steam -steamdeck -steamos3;
  '';

  steam-session = pkgs.symlinkJoin {
    name = "steam-session";
    paths = [
      (pkgs.writeTextDir "share/wayland-sessions/steam.desktop" ''
        [Desktop Entry]
        Name=steam
        Comment=Steam client
        Exec=${startGamescopeSession}
        Type=Application
        DesktopNames=Steam
        Keywords=gaming;steam;
      '')
    ];
    passthru.providedSessions = ["steam"];
  };
in {
  services.displayManager.sessionPackages = [steam-session];
  programs = {
    gamemode = {
      # gamemoded -s --verify gamemode is runnign; In steam, game properties: gamemoderun %command%
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility"; # For systems with AMD GPUs
          gpu_device = gpu;
          amd_performance_level = "high";
        };
      };
    };

    gamescope = {
      enable = true;
      capSysNice = false; # true; # may break gamescope in hpyrland
    };
    steam = {
      extraPackages = [pkgs.hidapi]; # Steam controller dependency
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
      extraCompatPackages = [pkgs-unstable.proton-ge-bin];
    };
  };
  hardware.graphics = {
    enable32Bit = true;
    extraPackages = [pkgs.gamescope-wsi];
    extraPackages32 = [pkgs.pkgsi686Linux.gamescope-wsi];
  };
  hardware.steam-hardware.enable = true;

  services.xserver.videoDrivers = ["amdgpu"]; # |nvidia

  environment.systemPackages = with pkgs; [
    # exit gamescope session, called by the switch to desktop button in the gamescope overlay
    (pkgs.writeShellScriptBin "steamos-session-select" ''
      ${pkgs.steam}/bin/steam -shutdown
      sleep 2
    '')

    # launch steam with mangohud (Mangohud may break some games thefore create new desktop file)
    (pkgs.makeDesktopItem {
      name = "Steam mango";
      comment = "Steam with MangoHud overlay";
      exec = "env MANGOHUD=1 steam %U";
      icon = "steam";
      terminal = false;
      type = "Application";
      desktopName = "Steam mango";
      categories = [
        "Game"
      ];
    })
    gamescope
    mangohud
    protonup-qt
    #bottles # wine sandbox for windows applications (EA client, ubisoft ...)
    heroic # epic client
    prismlauncher # Minecraft launcher
  ];
}
