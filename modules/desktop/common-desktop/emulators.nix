{
  pkgs,
  pkgs-unstable,
  duckstation,
  ...
}: {
  programs.appimage.enable = true;

  environment.systemPackages =
    (with pkgs; [
      #dolphin-emu
      pcsx2
      eden
      rpcs3

      (writeShellScriptBin "duckstation-qt" ''
        exec ${appimage-run}/bin/appimage-run ${duckstation.outPath} "$@"
      '')
    ])
    ++ (with pkgs-unstable; [
      steam-rom-manager
    ]);
}
